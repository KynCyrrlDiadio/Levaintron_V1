#!/usr/bin/env python3
"""
MLP Inventory Bridge v9.0 — Demo Build (single product)
Connects the MLP Decision Engine to the Token-based Inventory System

Demo product:
  - SKU 500107 (Demo_500g_Rye_Bread): 5 classes [0, 9, 18, 27, 36], lead 7 days

The production build carries one PRODUCT_CONFIGS entry per SKU; this demo
keeps the identical multi-product machinery with a single entry. Each entry
carries its own:
  - Trained PyTorch model (.pt file)
  - ORDER_CLASSES
  - Normalization constants (inventory, sales, pipeline divisors)
  - Lead time
  - Safety override thresholds

v9.0 Features (8 inputs standard, 9 inputs for weather-aware products):
    [inventory/INV_MAX, dow/6, expected_sales/SALES_MAX, actual_sales/SALES_MAX,
     monthly_mult, is_holiday, pipeline/PIPE_MAX, returns_rate/20]
    + [outdoor_score] when a config sets 'weather_aware': True (none in the demo)
"""

import os
import sys
import math
import logging
from datetime import datetime, timedelta
from typing import Dict, Optional, Tuple, List

logger = logging.getLogger('levaintron-demo-pipeline')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import torch
    import torch.nn as nn
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False
    print("Warning: PyTorch not available, using fallback logic")

from database_crumbs.Autonomous_Inventory.config import get_database
from weather_forecast import WeatherFetcher


MODELS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'models')

# ── Hormuz Multiplier (macro-economic dampener) ────────────────────────
# Scales down burn-rate estimates when consumer demand drops due to
# price hikes, recession, or other macro factors.
# 1.0 = no adjustment, 0.85 = expect 15% fewer sales than seasonal models predict.
# Values are read from the hormuz_config DB table (managed by React dashboard).
# Fallback constants used if the table doesn't exist or is empty.
_HORMUZ_FALLBACK_GLOBAL = 0.85
_HORMUZ_FALLBACK_PER_PRODUCT = {
    '500107': 1.0,   # Demo_500g_Rye_Bread — exempt, demand holding steady
}

# Cache to avoid hitting DB every call (refreshed once per bridge run)
_hormuz_cache = None

def _load_hormuz_from_db() -> dict:
    """Load Hormuz config from hormuz_config table. Returns {'global': float, 'products': dict}."""
    global _hormuz_cache
    if _hormuz_cache is not None:
        return _hormuz_cache
    try:
        db = get_database()
        cursor = db.conn.cursor()
        cursor.execute("SELECT product_id, multiplier FROM hormuz_config")
        rows = cursor.fetchall()
        cursor.close()
        if not rows:
            raise ValueError("Empty hormuz_config table")
        global_val = _HORMUZ_FALLBACK_GLOBAL
        products = {}
        for product_id, multiplier in rows:
            if product_id == '__global__':
                global_val = float(multiplier)
            else:
                products[product_id] = float(multiplier)
        _hormuz_cache = {'global': global_val, 'products': products}
        logger.info(f"Hormuz config loaded from DB: global={global_val}, overrides={products}")
        return _hormuz_cache
    except Exception as e:
        import traceback
        logger.error(f"╔══ HORMUZ DB QUERY FAILED ══╗")
        logger.error(f"║ {type(e).__name__}: {e}")
        logger.error(f"║ Falling back to hardcoded: global={_HORMUZ_FALLBACK_GLOBAL}, products={_HORMUZ_FALLBACK_PER_PRODUCT}")
        logger.error(f"╚═══════════════════════════╝")
        logger.debug(f"Hormuz traceback:\n{traceback.format_exc()}")
        _hormuz_cache = {'global': _HORMUZ_FALLBACK_GLOBAL, 'products': _HORMUZ_FALLBACK_PER_PRODUCT}
        return _hormuz_cache

def get_hormuz_multiplier(product_id: str) -> float:
    """Return the effective Hormuz multiplier for a product."""
    config = _load_hormuz_from_db()
    return config['products'].get(product_id, config['global'])

PRODUCT_CONFIGS = {
    '500107': {
        'name': 'Demo_500g_Rye_Bread',
        'tray_factor': 9,
        'order_classes': [0, 9, 18, 27, 36],
        'lead_time_days': 7,
        'model_file': 'Demo_500g_Rye_Bread.pt',
        'norm': {
            'inventory_max': 80.0,
            'sales_max': 25.0,
            'pipeline_max': 150.0,
            'returns_max': 20.0,
            'dow_max': 6.0,
        },
        'safety': {
            'cancel_effective_stock': 90,
            'trim_effective_stock': 70,
            'emergency_stock': 10,
            'critical_stock': 5,
            'high_return_rate': 15.0,
            'expiring_trim_threshold': 15,
        },
        'fallback': {
            'base_sales': 12.5,
            'burn_damper': 78.0,
        },
    },
}


class BreadMLPv85(nn.Module):
    """MLP architecture: 8 inputs, N output classes"""

    def __init__(self, input_size=8, hidden_sizes=None, num_classes=4, dropout=0.2):
        super().__init__()
        if hidden_sizes is None:
            hidden_sizes = [128, 64, 32]
        layers = []
        prev_size = input_size
        for i, hidden_size in enumerate(hidden_sizes):
            layers.append(nn.Linear(prev_size, hidden_size))
            layers.append(nn.ReLU())
            if i < len(hidden_sizes) - 1:
                layers.append(nn.Dropout(dropout))
            prev_size = hidden_size
        self.hidden = nn.Sequential(*layers)
        self.output = nn.Linear(prev_size, num_classes)

    def forward(self, x):
        x = self.hidden(x)
        return self.output(x)


class MLPInventoryBridge:
    """
    Multi-product bridge between Token Inventory System and MLP Decision Engine.

    Loads per-product models and configs from PRODUCT_CONFIGS.
    All methods accept product_id to select the right model/normalization.
    """

    SHELF_LIFE_DAYS = 16
    DELIVERY_DAYS = {0, 1, 3, 4}

    def __init__(self, db_connection=None, model_path: str = None,
                 device: str = None, store_id: str = '70012004',
                 lite_mode: bool = False):
        # Reset Hormuz cache so each pipeline run reads fresh DB values
        global _hormuz_cache
        _hormuz_cache = None
        self.db = db_connection
        self.store_id = store_id
        self.device = device or ('cuda:1' if TORCH_AVAILABLE and torch.cuda.is_available() else 'cpu')
        self.models = {}
        self._legacy_model_path = model_path
        # Multiplier caches — loaded from DB at init, fallback to hardcoded
        self._monthly_cache = {}   # (sku, month) -> float
        self._dow_cache = {}       # (sku, dow) -> float
        self._wom_cache = {}       # (sku, month, week) -> float
        self._multipliers_loaded = False
        self._load_multiplier_cache()
        # lite_mode skips MLP model + weather init for FIFO-only projection use
        # (e.g. dashboard preview). Pipeline must always run with lite_mode=False.
        self._weather = None
        if not lite_mode:
            self._load_all_models()
            self._init_weather()

    def _load_multiplier_cache(self):
        """Load all multiplier values from DB into memory at startup."""
        db, should_close = self._get_db()
        try:
            # Monthly multipliers
            db.cursor.execute(
                'SELECT sku, month, multiplier FROM product_monthly_multipliers WHERE store_id = %s',
                (self.store_id,))
            for row in db.cursor.fetchall():
                self._monthly_cache[(row['sku'], row['month'])] = float(row['multiplier'])
            n_monthly = len(self._monthly_cache)

            # DOW multipliers
            db.cursor.execute(
                'SELECT sku, day_of_week, multiplier FROM product_dow_multipliers WHERE store_id = %s',
                (self.store_id,))
            for row in db.cursor.fetchall():
                self._dow_cache[(row['sku'], row['day_of_week'])] = float(row['multiplier'])
            n_dow = len(self._dow_cache)

            # Week-of-month multipliers
            db.cursor.execute(
                'SELECT sku, month, week, multiplier FROM product_wom_multipliers WHERE store_id = %s',
                (self.store_id,))
            for row in db.cursor.fetchall():
                self._wom_cache[(row['sku'], row['month'], row['week'])] = float(row['multiplier'])
            n_wom = len(self._wom_cache)

            self._multipliers_loaded = True
            logger.info(f"Multiplier cache loaded from DB: {n_monthly} monthly, {n_dow} DOW, {n_wom} WOM entries")
        except Exception as e:
            logger.warning(f"⚠ MULTIPLIER DB LOAD FAILED: {e} — all lookups will use hardcoded fallbacks")
            self._multipliers_loaded = False
        finally:
            if should_close:
                db.close()

    def _load_all_models(self):
        if not TORCH_AVAILABLE:
            print("MLPInventoryBridge: PyTorch not available, using fallback for all products")
            return

        for product_id, config in PRODUCT_CONFIGS.items():
            model_file = config['model_file']
            model_path = os.path.join(MODELS_DIR, model_file)

            if product_id == '500107' and self._legacy_model_path:
                model_path = self._legacy_model_path

            if not os.path.exists(model_path):
                print(f"MLPInventoryBridge [{product_id}]: Model not found at {model_path}, using fallback")
                continue

            try:
                checkpoint = torch.load(model_path, map_location=self.device, weights_only=False)

                input_size = checkpoint.get('input_size', 8) if isinstance(checkpoint, dict) else 8
                num_classes = len(config['order_classes'])

                if isinstance(checkpoint, dict) and 'model_state_dict' in checkpoint:
                    state_dict = checkpoint['model_state_dict']
                elif isinstance(checkpoint, dict) and 'state_dict' in checkpoint:
                    state_dict = checkpoint['state_dict']
                else:
                    state_dict = checkpoint

                last_layer_key = None
                for k in state_dict:
                    if 'weight' in k:
                        last_layer_key = k
                if last_layer_key:
                    detected_classes = state_dict[last_layer_key].shape[0]
                    if detected_classes != num_classes:
                        print(f"MLPInventoryBridge [{product_id}]: Model has {detected_classes} classes, config expects {num_classes}")
                        num_classes = detected_classes

                model = BreadMLPv85(input_size=input_size, num_classes=num_classes)
                model.load_state_dict(state_dict)
                model.to(self.device)
                model.eval()

                params = sum(p.numel() for p in model.parameters())
                print(f"MLPInventoryBridge [{product_id}]: Loaded {config['name']} "
                      f"({params:,} params, {num_classes} classes {config['order_classes']}) on {self.device}")

                self.models[product_id] = {
                    'model': model,
                    'input_size': input_size,
                    'num_classes': num_classes,
                }

            except Exception as e:
                print(f"MLPInventoryBridge [{product_id}]: Failed to load model: {e}")

    def _init_weather(self):
        try:
            self._weather = WeatherFetcher()
            forecast = self._weather.get_forecast()
            days = forecast.get('days', [])
            if days and not forecast.get('error'):
                logger.info(f"Weather forecast loaded: {len(days)} days from Open-Meteo")
                for d in days[:7]:
                    logger.info(f"  {d['date']}: {d['temp_max']:.0f}/{d['temp_min']:.0f}C "
                                f"precip={d['precip_probability']}% score={d['outdoor_score']:.3f}")
            else:
                logger.warning(f"Weather API returned no data: {forecast.get('error', 'empty')}")
        except Exception as e:
            logger.warning(f"Weather init failed: {e} — BBQ products will use fallback score 0.5")
            self._weather = None

    def get_outdoor_score(self, target_date: datetime) -> float:
        if self._weather is None:
            return 0.5
        days_ahead = max(0, (target_date - datetime.now()).days)
        return self._weather.get_outdoor_score(days_ahead)

    def _get_config(self, product_id: str) -> Dict:
        if product_id in PRODUCT_CONFIGS:
            return PRODUCT_CONFIGS[product_id]
        raise ValueError(f"Unknown product_id: {product_id}")

    def _get_model(self, product_id: str):
        return self.models.get(product_id, {}).get('model')

    @property
    def ORDER_CLASSES(self):
        return PRODUCT_CONFIGS.get('500107', {}).get('order_classes', [0, 9, 18, 27, 36])

    @property
    def ORDER_LEAD_TIME_DAYS(self):
        return PRODUCT_CONFIGS.get('500107', {}).get('lead_time_days', 7)

    def _get_db(self):
        if self.db:
            return self.db, False
        return get_database(), True

    def _estimate_fifo_depletion(self, product_id: str, batches: list) -> Dict:
        """
        Pure runtime FIFO depletion — ignores DB token statuses entirely.

        Every batch starts at its full total_count regardless of what the DB
        says about sold/expired/in_stock. The simulation walks day-by-day from
        the oldest batch's arrival date to now, depleting oldest-first (FIFO)
        using seasonal × DOW × week-of-month multipliers.

        DB token statuses (sold, expired, returned) are logged for comparison
        but do NOT influence the inventory estimate. This avoids the auto-sell
        problem where tokens get marked 'sold' before the bread actually
        leaves the shelf (shelf life now 16 days, was 12).

        Args:
            product_id: SKU string
            batches: list of dicts with keys:
                arrival_date, total_count, in_stock, db_sold, db_expired, db_returned

        Returns dict with FIFO estimate and per-batch breakdown for logging.
        """
        config = self._get_config(product_id)
        base_sales = config['fallback']['base_sales']
        hormuz = get_hormuz_multiplier(product_id)
        if hormuz != 1.0:
            logger.info(f"[{product_id}] Hormuz multiplier active: {hormuz} "
                        f"(burn rates scaled to {hormuz*100:.0f}%)")

        if not batches:
            return {'total_burn': 0, 'estimated_remaining': 0, 'batch_breakdown': [],
                    'daily_log': [], 'method': 'fifo_no_batches'}

        now = datetime.now()
        today = now.date()

        # All batches enter simulation at full total_count — no splitting,
        # no dependency on DB sold/expired/in_stock status
        fifo_batches = []
        total_tokens = 0
        for b in batches:
            total_tokens += b['total_count']
            fifo_batches.append({
                'date': b['arrival_date'],
                'initial': b['total_count'],
                'remaining': float(b['total_count']),
                'db_sold': b['db_sold'],
                'db_expired': b['db_expired'],
                'db_returned': b['db_returned'],
                'db_in_stock': b['in_stock'],
            })

        oldest_date = fifo_batches[0]['date']
        daily_log = []
        current_date = oldest_date

        while current_date <= today:
            month = current_date.month
            dow = current_date.weekday()
            monthly_mult = self._default_seasonal_multiplier(month, product_id)
            dow_mult = self._default_dow_multiplier(dow, product_id)
            week_mult = self._get_week_of_month_multiplier(current_date.day, month, product_id)
            hormuz = get_hormuz_multiplier(product_id)
            daily_rate = base_sales * monthly_mult * dow_mult * week_mult * hormuz

            # Partial day handling for today
            if current_date == today:
                hours_since_open = (now - datetime.combine(today, datetime.min.time().replace(hour=6))).total_seconds() / 3600.0
                selling_hours = max(0, min(hours_since_open, 15.0))
                daily_rate *= (selling_hours / 15.0)

            remaining_to_sell = daily_rate
            day_sales = []

            # FIFO: deplete oldest batches first
            for batch in fifo_batches:
                if batch['date'] > current_date:
                    break  # not arrived yet
                if batch['remaining'] <= 0:
                    continue
                sold = min(batch['remaining'], remaining_to_sell)
                batch['remaining'] -= sold
                remaining_to_sell -= sold
                if sold > 0:
                    day_sales.append({'batch': batch['date'].isoformat(), 'sold': round(sold, 1)})
                if remaining_to_sell <= 0:
                    break

            daily_log.append({
                'date': current_date.isoformat(),
                'rate': round(daily_rate, 1),
                'sold': round(daily_rate - remaining_to_sell, 1),
                'unfulfilled': round(remaining_to_sell, 1) if remaining_to_sell > 0.5 else 0,
                'sales': day_sales
            })
            current_date += timedelta(days=1)

        # Per-batch breakdown — FIFO is sole source of truth for remaining
        batch_breakdown = []
        total_remaining = 0.0
        total_depleted = 0.0

        for batch in fifo_batches:
            fifo_remaining = max(0, batch['remaining'])
            total_remaining += fifo_remaining
            total_depleted += batch['initial'] - fifo_remaining

            batch_breakdown.append({
                'arrival': batch['date'].isoformat(),
                'initial': batch['initial'],
                'fifo_remaining': round(fifo_remaining, 1),
                'db_in_stock': batch['db_in_stock'],
                'remaining': round(fifo_remaining, 1),
                'depleted': round(batch['initial'] - fifo_remaining, 1),
            })

        estimated_remaining = round(total_remaining)
        days_span = (today - oldest_date).days

        hormuz = get_hormuz_multiplier(product_id)
        return {
            'total_burn': round(total_depleted),
            'estimated_remaining': estimated_remaining,
            'total_tokens': total_tokens,
            'fifo_adjustment': total_tokens - estimated_remaining,
            'days_span': days_span,
            'oldest_batch': oldest_date.isoformat(),
            'num_batches': len(fifo_batches),
            'batch_breakdown': batch_breakdown,
            'daily_log': daily_log[-7:],  # last 7 days for logging brevity
            'hormuz_multiplier': hormuz,
            'method': 'fifo_runtime'
        }

    # --- Legacy burn decay method (replaced by FIFO depletion) ---
    # Backup preserved in mlp_inventory_bridge_with_burn_decay_function.py
    def _estimate_burn_since_sync_legacy(self, product_id: str, burn_start_date, newest_arrival=None) -> Dict:
        """LEGACY: Single-window burn decay with hyperbolic damper. Replaced by FIFO."""
        config = self._get_config(product_id)
        base_sales = config['fallback']['base_sales']
        burn_damper = config['fallback'].get('burn_damper', 140.0)

        if burn_start_date is None:
            return {'total_burn': 0, 'days_since_sync': 0, 'daily_rates': [],
                    'method': 'no_sync_data'}

        if newest_arrival is None:
            newest_arrival = burn_start_date

        now = datetime.now()
        today = now.date()

        sync_datetime = datetime.combine(burn_start_date, datetime.min.time().replace(hour=3))
        if now < sync_datetime:
            return {'total_burn': 0, 'days_since_sync': 0, 'daily_rates': [],
                    'method': 'sync_today_pending'}

        hours_since_sync = (now - sync_datetime).total_seconds() / 3600.0
        if hours_since_sync < 1.0:
            return {'total_burn': 0, 'days_since_sync': 0, 'daily_rates': [],
                    'method': 'recent_sync'}

        total_burn = 0.0
        total_burn_undamped = 0.0
        daily_rates = []
        current_date = burn_start_date

        while current_date <= today:
            month = current_date.month
            dow = current_date.weekday()
            monthly_mult = self._default_seasonal_multiplier(month, product_id)
            dow_mult = self._default_dow_multiplier(dow, product_id)
            hormuz = get_hormuz_multiplier(product_id)
            daily_rate = base_sales * monthly_mult * dow_mult * hormuz

            if current_date == burn_start_date:
                if current_date == today:
                    hours_since_open = (now - datetime.combine(today, datetime.min.time().replace(hour=6))).total_seconds() / 3600.0
                    selling_hours = max(0, min(hours_since_open, 15.0))
                else:
                    selling_hours = 15.0
                fraction = selling_hours / 15.0
                day_burn_raw = daily_rate * fraction
            elif current_date == today:
                hours_today = (now - datetime.combine(today, datetime.min.time().replace(hour=6))).total_seconds() / 3600.0
                hours_today = max(0, min(hours_today, 15.0))
                fraction = hours_today / 15.0
                day_burn_raw = daily_rate * fraction
            else:
                day_burn_raw = daily_rate

            day_offset = (current_date - burn_start_date).days
            hours_at_midpoint = (day_offset * 24.0) + 12.0
            confidence = 1.0 / (1.0 + (hours_at_midpoint / burn_damper))

            day_burn = day_burn_raw * confidence
            total_burn_undamped += day_burn_raw
            total_burn += day_burn

            daily_rates.append({
                'date': current_date.isoformat(),
                'dow': dow,
                'rate': round(daily_rate, 1),
                'burn_raw': round(day_burn_raw, 1),
                'confidence': round(confidence, 2),
                'burn': round(day_burn, 1)
            })
            current_date += timedelta(days=1)

        return {
            'total_burn': round(total_burn),
            'total_burn_raw': round(total_burn, 1),
            'total_burn_undamped': round(total_burn_undamped, 1),
            'damper_savings': round(total_burn_undamped - total_burn, 1),
            'days_since_sync': (today - burn_start_date).days,
            'hours_since_sync': round(hours_since_sync, 1),
            'burn_start': burn_start_date.isoformat(),
            'newest_arrival': newest_arrival.isoformat() if newest_arrival else None,
            'burn_window': f"{burn_start_date} → {today}",
            'daily_rates': daily_rates,
            'method': 'seasonal_burn_decay_damped'
        }

    def get_inferred_inventory(self, product_id: str) -> Dict:
        db, should_close = self._get_db()
        try:
            today = datetime.now().date()
            three_days = today + timedelta(days=3)

            db.cursor.execute('''
                SELECT
                    COUNT(*) as active_tokens,
                    MIN(arrival_date) as oldest_arrival,
                    MAX(arrival_date) as newest_arrival
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s AND status = 'in_stock'
            ''', (product_id, self.store_id))

            result = db.cursor.fetchone()
            active_tokens = result['active_tokens'] or 0
            newest_arrival = result['newest_arrival']

            oldest_age = 0
            newest_age = 0
            if result['oldest_arrival']:
                oldest_age = (today - result['oldest_arrival']).days
            if newest_arrival:
                newest_age = (today - newest_arrival).days

            # FIFO depletion: get ALL batches with per-status counts
            # Need total_count (original batch size) to simulate depletion from day 1,
            # and db_sold/db_expired to know how many the DB already accounted for.
            # FIFO only estimates the ADDITIONAL sold beyond what DB has marked.
            db.cursor.execute('''
                SELECT arrival_date,
                       COUNT(*) as total_count,
                       COUNT(*) FILTER (WHERE status = 'in_stock') as in_stock,
                       COUNT(*) FILTER (WHERE status = 'sold') as sold,
                       COUNT(*) FILTER (WHERE status = 'expired') as expired,
                       COUNT(*) FILTER (WHERE status = 'returned') as returned
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s
                GROUP BY arrival_date
                ORDER BY arrival_date ASC
            ''', (product_id, self.store_id))

            batch_rows = db.cursor.fetchall()
            batches = [{
                'arrival_date': r['arrival_date'],
                'total_count': r['total_count'],
                'in_stock': r['in_stock'],
                'db_sold': r['sold'],
                'db_expired': r['expired'],
                'db_returned': r['returned']
            } for r in batch_rows]

            db.cursor.execute('''
                SELECT COUNT(*) as expiring_soon
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s
                  AND status = 'in_stock' AND expiration_date <= %s
            ''', (product_id, self.store_id, three_days))

            expiring = db.cursor.fetchone()['expiring_soon'] or 0

            # --- FIFO depletion: per-batch simulation replaces single-window burn ---
            fifo_info = self._estimate_fifo_depletion(product_id, batches)
            estimated_burn = fifo_info['total_burn']
            estimated_inventory = fifo_info['estimated_remaining']

            if estimated_burn > 0:
                batch_summary = ', '.join(
                    f"{b['arrival']}:{b['initial']}→{b['remaining']:.0f}"
                    for b in fifo_info['batch_breakdown']
                )
                print(f"  [FIFO RUNTIME] {product_id}: total_tokens={fifo_info['total_tokens']}, "
                      f"est. sold={estimated_burn}, "
                      f"est. remaining={estimated_inventory}, "
                      f"batches={fifo_info['num_batches']} "
                      f"({fifo_info['days_span']}d span)")
                print(f"    Batch detail: {batch_summary}")

            return {
                'active_tokens': active_tokens,
                'expiring_soon': expiring,
                'oldest_batch_age': oldest_age,
                'newest_batch_age': newest_age,
                'estimated_inventory': estimated_inventory,
                'db_raw_count': active_tokens,
                'burn_decay_applied': estimated_burn,
                'burn_info': fifo_info,
                'data_source': 'database+fifo_depletion' if estimated_burn > 0 else 'database'
            }
        except Exception as e:
            print(f"\n{'='*60}")
            print(f"  CRITICAL: Inventory DB query FAILED for product {product_id}")
            print(f"    Error: {e}")
            print(f"    MLP will NOT proceed with estimated data.")
            print(f"{'='*60}\n")
            raise RuntimeError(f"Inventory query failed for {product_id}: {e}. Pipeline cannot proceed with estimated data.")
        finally:
            if should_close:
                db.close()

    def get_inferred_sales_rate(self, product_id: str, days_back: int = 14) -> Dict:
        db, should_close = self._get_db()
        try:
            end_date = datetime.now().date()
            start_date = end_date - timedelta(days=days_back)

            db.cursor.execute('''
                SELECT COUNT(*) as sold_count
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s
                  AND status = 'sold' AND consumed_date BETWEEN %s AND %s
            ''', (product_id, self.store_id, start_date, end_date))
            sold = db.cursor.fetchone()['sold_count'] or 0

            db.cursor.execute('''
                SELECT COUNT(*) as returned_count
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s
                  AND status = 'returned' AND consumed_date BETWEEN %s AND %s
            ''', (product_id, self.store_id, start_date, end_date))
            returned = db.cursor.fetchone()['returned_count'] or 0

            db.cursor.execute('''
                SELECT COUNT(*) as delivered_count
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s
                  AND arrival_date BETWEEN %s AND %s
            ''', (product_id, self.store_id, start_date, end_date))
            delivered = db.cursor.fetchone()['delivered_count'] or 0

            daily_sales = sold / max(1, days_back)
            return_rate = (returned / max(1, delivered)) * 100 if delivered > 0 else 0

            return {
                'total_sold': sold,
                'total_returned': returned,
                'total_delivered': delivered,
                'daily_sales_rate': round(daily_sales, 2),
                'return_rate_pct': round(return_rate, 1),
                'period_days': days_back,
                'data_source': 'database'
            }
        except Exception as e:
            print(f"\n{'='*60}")
            print(f"  CRITICAL: Sales/returns DB query FAILED for product {product_id}")
            print(f"    Error: {e}")
            print(f"    MLP will NOT proceed with estimated data.")
            print(f"{'='*60}\n")
            raise RuntimeError(f"Sales rate query failed for {product_id}: {e}. Pipeline cannot proceed with estimated data.")
        finally:
            if should_close:
                db.close()

    def get_forecast_for_date(self, product_id: str, target_date: datetime) -> Dict:
        db, should_close = self._get_db()
        try:
            dow_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
            target_dow = dow_names[target_date.weekday()]
            target_month = target_date.month

            db.cursor.execute('''
                SELECT expected_sales, monthly_multiplier, dow_multiplier, confidence
                FROM daily_forecast
                WHERE sku = %s AND store_id = %s
                  AND day_of_week = %s AND month = %s
                LIMIT 1
            ''', (product_id, self.store_id, target_dow, target_month))

            result = db.cursor.fetchone()
            if result:
                return {
                    'expected_sales': float(result['expected_sales']),
                    'monthly_multiplier': float(result['monthly_multiplier']),
                    'dow_multiplier': float(result['dow_multiplier']),
                    'confidence': result['confidence'],
                    'source': 'daily_forecast'
                }

            config = self._get_config(product_id)
            seasonal_mult = self._default_seasonal_multiplier(target_month, product_id)
            dow_mult = self._default_dow_multiplier(target_date.weekday(), product_id)
            week_mult = self._get_week_of_month_multiplier(target_date.day, target_month, product_id)
            base_sales = config['fallback']['base_sales']
            hormuz = get_hormuz_multiplier(product_id)
            expected = base_sales * seasonal_mult * dow_mult * week_mult * hormuz

            return {
                'expected_sales': round(expected, 2),
                'monthly_multiplier': seasonal_mult,
                'dow_multiplier': dow_mult,
                'week_multiplier': week_mult,
                'hormuz_multiplier': hormuz,
                'confidence': 'estimated',
                'source': 'fallback'
            }
        finally:
            if should_close:
                db.close()

    def _default_seasonal_multiplier(self, month: int, product_id: str = '500107') -> float:
        # Check DB cache first
        cached = self._monthly_cache.get((product_id, month))
        if cached is not None:
            return cached

        logger.warning(f"⚠ MONTHLY FALLBACK: {product_id} month={month} not in DB cache — using hardcoded")
        if product_id == '500107':
            mults = {
                1: 1.50, 2: 1.15, 3: 0.72, 4: 0.91,
                5: 1.10, 6: 0.79, 7: 0.99, 8: 1.03,
                9: 1.12, 10: 0.94, 11: 1.04, 12: 0.91
            }
        else:
            mults = {
                1: 1.10, 2: 1.05, 3: 0.95, 4: 0.85, 5: 0.80, 6: 0.70,
                7: 0.75, 8: 0.80, 9: 0.90, 10: 1.00, 11: 1.10, 12: 1.15
            }
        return mults.get(month, 1.0)

    def _get_week_of_month_multiplier(self, day: int, month: int, product_id: str) -> float:
        """
        Within-month week multiplier — adjusts the flat monthly rate for
        intra-month demand variance (e.g., Feb promo cliff, Mar slow start).

        Week boundaries: days 1-7 = week 1, 8-14 = week 2, 15-21 = week 3, 22+ = week 4.
        Returns 1.0 for products/months without enough data.
        """
        if day <= 7:
            week = 1
        elif day <= 14:
            week = 2
        elif day <= 21:
            week = 3
        else:
            week = 4

        # Check DB cache first
        cached = self._wom_cache.get((product_id, month, week))
        if cached is not None:
            return cached

        if self._multipliers_loaded:
            # DB loaded but no WOM entry for this combo — return 1.0 (no adjustment)
            return 1.0

        logger.warning(f"⚠ WOM FALLBACK: {product_id} month={month} week={week} — using hardcoded")
        # Full 12-month WOM fallbacks — match data generators and DB exactly.
        # Jan/May/Dec = FLAT(1.0), Apr = interpolated(Feb+Mar avg), rest from POS data.
        week_mults_by_product = {
            '500107': {  # Demo_500g_Rye_Bread
                1:  {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00},
                2:  {1: 1.30, 2: 1.10, 3: 0.64, 4: 0.55},
                3:  {1: 1.00, 2: 0.74, 3: 0.97, 4: 1.25},
                4:  {1: 1.15, 2: 0.92, 3: 0.80, 4: 0.90},
                5:  {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00},
                6:  {1: 0.99, 2: 0.87, 3: 0.97, 4: 1.16},
                7:  {1: 0.94, 2: 1.34, 3: 0.87, 4: 0.91},
                8:  {1: 1.31, 2: 0.73, 3: 0.96, 4: 0.99},
                9:  {1: 0.87, 2: 1.00, 3: 1.13, 4: 1.01},
                10: {1: 0.96, 2: 0.97, 3: 1.00, 4: 1.12},
                11: {1: 0.97, 2: 0.93, 3: 1.31, 4: 1.00},
                12: {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00},
            },
        }

        product_weeks = week_mults_by_product.get(product_id)
        if product_weeks:
            month_weeks = product_weeks.get(month)
            if month_weeks:
                return month_weeks.get(week, 1.0)

        return 1.0

    def _default_dow_multiplier(self, dow: int, product_id: str = '500107') -> float:
        # Check DB cache first
        cached = self._dow_cache.get((product_id, dow))
        if cached is not None:
            return cached

        logger.warning(f"⚠ DOW FALLBACK: {product_id} dow={dow} not in DB cache — using hardcoded")
        if product_id == '500107':
            mults = {0: 0.98, 1: 1.14, 2: 0.89, 3: 0.92, 4: 1.06, 5: 0.96, 6: 1.05}
        else:
            mults = {0: 1.0, 1: 0.9, 2: 0.8, 3: 1.0, 4: 1.2, 5: 1.3, 6: 0.7}
        return mults.get(dow, 1.0)

    def build_features(self, product_id: str, target_date: datetime,
                       pipeline_incoming: int = 0,
                       current_stock: int = None) -> Tuple[list, Dict]:
        """
        Build normalized input features using product-specific normalization.
        8 inputs for standard products, 9 inputs for weather-aware BBQ products.
        """
        config = self._get_config(product_id)
        norm = config['norm']

        if current_stock is None:
            inv = self.get_inferred_inventory(product_id)
            current_stock = inv['estimated_inventory']

        sales = self.get_inferred_sales_rate(product_id)
        forecast = self.get_forecast_for_date(product_id, target_date)

        actual_sales_rate = sales['daily_sales_rate']
        expected_sales = forecast['expected_sales']
        monthly_mult = forecast['monthly_multiplier']
        return_rate = sales['return_rate_pct']
        dow = target_date.weekday()

        is_holiday = 0.0

        features = [
            min(current_stock / norm['inventory_max'], 2.0),
            dow / norm['dow_max'],
            min(expected_sales / norm['sales_max'], 2.0),
            min(actual_sales_rate / norm['sales_max'], 2.0),
            monthly_mult,
            is_holiday,
            min(pipeline_incoming / norm['pipeline_max'], 2.0),
            min(return_rate / norm['returns_max'], 2.0),
        ]

        outdoor_score = None
        if config.get('weather_aware'):
            outdoor_score = self.get_outdoor_score(target_date)
            features.append(outdoor_score)

        metadata = {
            'current_stock': current_stock,
            'actual_sales_rate': actual_sales_rate,
            'expected_sales': expected_sales,
            'monthly_multiplier': monthly_mult,
            'return_rate_pct': return_rate,
            'pipeline_incoming': pipeline_incoming,
            'day_of_week': dow,
            'is_holiday': bool(is_holiday),
            'target_date': target_date.strftime('%Y-%m-%d'),
            'forecast_source': forecast['source'],
            'sales_data_source': sales.get('data_source', 'unknown'),
            'normalization': {k: v for k, v in norm.items()},
            'outdoor_score': outdoor_score,
            'weather_aware': config.get('weather_aware', False),
        }

        return features, metadata

    def build_features_v85(self, product_id: str, target_date: datetime,
                           pipeline_incoming: int = 0,
                           current_stock: int = None) -> Tuple[list, Dict]:
        """Legacy alias for build_features."""
        return self.build_features(product_id, target_date, pipeline_incoming, current_stock)

    def predict(self, features: list, product_id: str = '500107') -> Dict:
        model = self._get_model(product_id)
        if model is not None and TORCH_AVAILABLE:
            return self._predict_mlp(features, product_id)
        return self._predict_fallback(features, product_id)

    def _predict_mlp(self, features: list, product_id: str = '500107') -> Dict:
        model = self._get_model(product_id)
        config = self._get_config(product_id)
        order_classes = config['order_classes']

        with torch.no_grad():
            x = torch.tensor([features], dtype=torch.float32).to(self.device)
            logits = model(x)
            probs = torch.softmax(logits, dim=1)
            predicted_class = torch.argmax(probs, dim=1).item()
            confidence = probs[0][predicted_class].item()

            if predicted_class < len(order_classes):
                decision = order_classes[predicted_class]
            else:
                decision = order_classes[-1]

            return {
                'decision': decision,
                'confidence': round(confidence, 4),
                'probabilities': {
                    str(c): round(probs[0][i].item(), 4)
                    for i, c in enumerate(order_classes) if i < probs.shape[1]
                },
                'method': f'mlp_v9_{product_id}'
            }

    def _predict_fallback(self, features: list, product_id: str = '500107') -> Dict:
        config = self._get_config(product_id)
        norm = config['norm']
        order_classes = config['order_classes']

        stock = features[0] * norm['inventory_max']
        expected = features[2] * norm['sales_max']
        actual = features[3] * norm['sales_max']
        pipeline = features[6] * norm['pipeline_max']
        returns_rate = features[7] * norm['returns_max']

        sales = max(expected, actual, 1.0)
        effective_stock = stock + pipeline
        days_eff = effective_stock / sales

        if product_id == '500107':
            if returns_rate > 12 and days_eff > 5:
                decision, confidence = 0, 0.85
            elif effective_stock > 80 or days_eff > 7:
                decision, confidence = 0, 0.80
            elif stock == 0 and pipeline < 18:
                decision, confidence = order_classes[-1], 0.90
            elif stock < 5 and pipeline < 9:
                decision, confidence = order_classes[-1], 0.85
            elif days_eff < 2 and pipeline < 27:
                decision, confidence = order_classes[2], 0.80
            elif stock < 10 and pipeline < 18:
                decision, confidence = order_classes[2], 0.80
            else:
                decision, confidence = order_classes[1], 0.65
        else:
            if returns_rate > 8 and days_eff > 3:
                decision, confidence = 0, 0.85
            elif returns_rate > 5 and days_eff > 4:
                decision, confidence = order_classes[1], 0.75
            elif days_eff > 6:
                decision, confidence = order_classes[1] if sales < 6 else 0, 0.80
            elif days_eff < 2:
                decision, confidence = order_classes[-1], 0.90
            elif days_eff < 4:
                decision, confidence = order_classes[2], 0.85
            else:
                decision, confidence = order_classes[1], 0.70

        return {
            'decision': decision,
            'confidence': confidence,
            'probabilities': {str(c): 0.0 for c in order_classes},
            'days_effective': round(days_eff, 1),
            'method': f'fallback_v9_{product_id}'
        }

    def _apply_safety_overrides(self, decision: int, current_stock: int,
                                 days_eff: float, expiring_soon: int,
                                 return_rate: float,
                                 pipeline_incoming: int = 0,
                                 product_id: str = '500107') -> Tuple[int, Optional[str]]:
        config = self._get_config(product_id)
        safety = config['safety']
        order_classes = config['order_classes']
        effective_stock = current_stock + pipeline_incoming

        min_order = order_classes[1] if len(order_classes) > 1 else 0
        mid_order = order_classes[2] if len(order_classes) > 2 else min_order
        max_order = order_classes[-1]

        # Priority 0: Stockout protection — empty shelf overrules everything.
        # If there's nothing on the shelf, order regardless of returns or overstock.
        # High returns with zero stock is a deadlock: returns stay high because
        # there's no fresh product, and no product arrives because returns are high.
        if current_stock < safety['critical_stock']:
            if decision == 0:
                return max_order, f"Critical stock {current_stock} - emergency max order"
            return max(decision, max_order), f"Critical stock {current_stock} - forcing max order"

        if current_stock < safety['emergency_stock'] and decision == 0:
            return mid_order, f"Emergency stock {current_stock} < {safety['emergency_stock']} - ordering {mid_order}"

        # Priority 1: days_eff coverage protection
        if days_eff < 2.0 and decision == 0:
            return max_order, f"Critical: {days_eff:.1f} days coverage - emergency max order"

        if days_eff < 2.0:
            return max(decision, mid_order), f"Low coverage {days_eff:.1f} days - floor at ORDER {mid_order}"

        # Priority 2: High returns — two-tier response
        # Only suppress orders when there's enough stock on shelf to survive.
        if return_rate > 25.0 and decision > 0:
            return 0, f"Severe return rate ({return_rate:.1f}%) - cancelling orders"

        if return_rate > safety['high_return_rate'] and decision > min_order:
            return min_order, f"High return rate ({return_rate:.1f}%) - trimming to ORDER {min_order}"

        # Priority 3: Overstock cancel
        if effective_stock > safety['cancel_effective_stock'] and decision > 0:
            return 0, f"Effective stock {effective_stock} exceeds {safety['cancel_effective_stock']} - stopping orders"

        # Priority 4: Overstock trim
        if effective_stock > safety['trim_effective_stock'] and decision > min_order:
            return min_order, f"Effective stock {effective_stock} > {safety['trim_effective_stock']} - trimming to ORDER {min_order}"

        return decision, None

    def get_mlp_decision(self, product_id: str,
                         target_date: datetime = None,
                         pipeline_incoming: int = 0,
                         current_stock: int = None) -> Dict:
        """
        Get MLP ordering decision for a specific product and delivery date.
        Uses product-specific model, normalization, and safety overrides.
        """
        config = self._get_config(product_id)
        lead_time = config['lead_time_days']

        now = datetime.now()
        if target_date is None:
            target_date = now + timedelta(days=lead_time)

        if current_stock is None:
            inv = self.get_inferred_inventory(product_id)
            current_stock = inv['estimated_inventory']
            expiring_soon = inv['expiring_soon']
        else:
            expiring_soon = 0

        features, metadata = self.build_features(
            product_id, target_date,
            pipeline_incoming=pipeline_incoming,
            current_stock=current_stock
        )

        prediction = self.predict(features, product_id=product_id)

        sales_data = self.get_inferred_sales_rate(product_id)
        sales = max(metadata['expected_sales'], metadata['actual_sales_rate'], 1.0)
        effective_stock = current_stock + pipeline_incoming
        days_eff = effective_stock / sales

        final_decision, override_reason = self._apply_safety_overrides(
            prediction['decision'], current_stock, days_eff,
            expiring_soon, sales_data['return_rate_pct'],
            pipeline_incoming, product_id
        )

        db, should_close = self._get_db()
        try:
            db.cursor.execute('''
                SELECT product_name, tray_factor FROM products
                WHERE product_id = %s LIMIT 1
            ''', (product_id,))
            row = db.cursor.fetchone()
            product_name = row['product_name'] if row else config['name']
            tray_factor = row['tray_factor'] if row else config['tray_factor']
        except:
            product_name = config['name']
            tray_factor = config['tray_factor']
        finally:
            if should_close:
                db.close()

        trays_needed = final_decision / tray_factor if tray_factor > 0 else final_decision

        return {
            'product_id': product_id,
            'product_name': product_name,
            'store_id': self.store_id,
            'timestamp': now.isoformat(),
            'delivery_date': target_date.strftime('%Y-%m-%d'),

            'inputs': metadata,
            'features': features,

            'mlp_raw_decision': prediction['decision'],
            'final_decision': final_decision,
            'confidence': prediction['confidence'],
            'probabilities': prediction['probabilities'],
            'method': prediction['method'],
            'override_reason': override_reason,

            'tray_factor': tray_factor,
            'trays_needed': round(trays_needed, 2),
            'total_units': final_decision,
            'order_classes': config['order_classes'],

            'days_effective_inventory': round(days_eff, 1),
            'order_arrives': target_date.strftime('%Y-%m-%d'),

            'reasoning': self._generate_reasoning(
                current_stock, sales, days_eff,
                final_decision, prediction['confidence'],
                pipeline_incoming, sales_data['return_rate_pct'],
                product_id
            ),
        }

    def get_multi_date_decisions(self, product_id: str,
                                  adjustable_dates: List[Dict],
                                  pipeline_incoming: int = 0,
                                  locked_pipeline_by_date: Dict = None) -> List[Dict]:
        """
        Make per-date MLP decisions for all adjustable hub dates.
        Projects stock forward for each date accounting for prior decisions
        AND per-date arrival of locked pipeline cells.

        Reads F.O. values only. Writes ADJ cells only.
        All values are in raw pieces (no tray conversion).

        locked_pipeline_by_date: {date_str: {'fo_value': int, ...}} from scraper.
        Used to credit pipeline arrivals to projected_stock by their delivery
        date and to subtract already-arrived pipeline from the per-target
        pipeline_incoming feature so days_eff doesn't double-count.
        """
        inv = self.get_inferred_inventory(product_id)
        current_stock = inv['estimated_inventory']

        if locked_pipeline_by_date is None:
            locked_pipeline_by_date = {}

        # Normalize locked dates to (date_obj, qty) for arithmetic
        locked_arrivals = []
        for d_str, info in locked_pipeline_by_date.items():
            try:
                d = datetime.strptime(d_str, '%Y-%m-%d')
                qty = int(info.get('fo_value', 0)) if isinstance(info, dict) else int(info)
                if qty > 0:
                    locked_arrivals.append((d, qty))
            except (ValueError, TypeError):
                continue

        decisions = []
        cumulative_ordered = 0

        for date_info in sorted(adjustable_dates, key=lambda d: d.get('date', '')):
            date_str = date_info.get('date', '')
            try:
                target_date = datetime.strptime(date_str, '%Y-%m-%d')
            except:
                continue

            fo_value = date_info.get('fo_value', 0)
            current_adj = date_info.get('current_adj', 0)

            days_until = (target_date - datetime.now()).days
            forecast = self.get_forecast_for_date(product_id, target_date)
            consumed_by_then = forecast['expected_sales'] * max(0, days_until)

            # Pipeline split by arrival vs target_date:
            #   pipeline_arrived_by_target → already on shelf, add to projected_stock
            #   pipeline_remaining_after_target → still incoming, feeds days_eff coverage
            pipeline_arrived_by_target = sum(qty for d, qty in locked_arrivals if d <= target_date)
            pipeline_remaining_after_target = sum(qty for d, qty in locked_arrivals if d > target_date)

            projected_stock = max(0, current_stock + pipeline_arrived_by_target +
                                  cumulative_ordered - consumed_by_then)

            decision = self.get_mlp_decision(
                product_id=product_id,
                target_date=target_date,
                pipeline_incoming=pipeline_remaining_after_target,
                current_stock=int(projected_stock)
            )

            decision['column_index'] = date_info.get('column_index')
            decision['offset_from_today'] = date_info.get('offset_from_today')
            decision['dow'] = date_info.get('dow')
            decision['fo_value'] = fo_value
            decision['current_adj'] = current_adj
            decision['current_so'] = date_info.get('current_so', 0)
            decision['projected_stock_at_delivery'] = round(projected_stock, 1)

            if date_info.get('from_week'):
                decision['from_week'] = date_info['from_week']
            if date_info.get('next_week_column_index') is not None:
                decision['next_week_column_index'] = date_info['next_week_column_index']

            decisions.append(decision)

            cumulative_ordered += decision['final_decision']

        return decisions

    def _generate_reasoning(self, stock, sales, days_eff, decision, confidence,
                           pipeline=0, return_rate=0.0, product_id='500107'):
        config = self._get_config(product_id)
        order_classes = config['order_classes']

        parts = []
        parts.append(f"Stock: {stock} units")
        if pipeline > 0:
            parts.append(f"+ {pipeline} in pipeline")
        parts.append(f"({days_eff:.1f} days effective)")
        parts.append(f"Sales: {sales:.1f}/day")
        if return_rate > 0:
            parts.append(f"Returns: {return_rate:.1f}%")

        if decision == 0:
            parts.append("-> No order needed")
        else:
            parts.append(f"-> ORDER {decision} ({decision} loaves)")

        parts.append(f"[{confidence:.0%} confidence]")
        return " | ".join(parts)

    def _ensure_mlp_order_log_table(self, db):
        db.cursor.execute('''
            CREATE TABLE IF NOT EXISTS mlp_order_log (
                id SERIAL PRIMARY KEY,
                created_at TIMESTAMP DEFAULT NOW(),
                product_id VARCHAR(50),
                store_id VARCHAR(50),
                delivery_date VARCHAR(20),
                current_stock INTEGER,
                projected_stock REAL,
                expected_sales REAL,
                actual_sales_rate REAL,
                monthly_multiplier REAL,
                pipeline_incoming INTEGER,
                returns_rate REAL,
                day_of_week INTEGER,
                is_holiday BOOLEAN DEFAULT FALSE,
                mlp_decision INTEGER,
                mlp_confidence REAL,
                mlp_method VARCHAR(50),
                standing_order INTEGER DEFAULT 0,
                adj_value INTEGER DEFAULT 0,
                total_units INTEGER DEFAULT 0,
                tray_factor INTEGER,
                features TEXT,
                was_overridden BOOLEAN DEFAULT FALSE,
                override_reason TEXT,
                otto_action VARCHAR(20),
                otto_write_success BOOLEAN,
                verified BOOLEAN,
                dow VARCHAR(5),
                column_index INTEGER,
                reasoning TEXT
            )
        ''')
        db.conn.commit()

        expected_columns = {
            'store_id': 'VARCHAR(50)',
            'delivery_date': 'VARCHAR(20)',
            'current_stock': 'INTEGER',
            'projected_stock': 'REAL',
            'expected_sales': 'REAL',
            'actual_sales_rate': 'REAL',
            'monthly_multiplier': 'REAL',
            'pipeline_incoming': 'INTEGER',
            'returns_rate': 'REAL',
            'day_of_week': 'INTEGER',
            'is_holiday': 'BOOLEAN DEFAULT FALSE',
            'mlp_decision': 'INTEGER',
            'mlp_confidence': 'REAL',
            'mlp_method': 'VARCHAR(50)',
            'standing_order': 'INTEGER DEFAULT 0',
            'adj_value': 'INTEGER DEFAULT 0',
            'total_units': 'INTEGER DEFAULT 0',
            'tray_factor': 'INTEGER',
            'features': 'TEXT',
            'was_overridden': 'BOOLEAN DEFAULT FALSE',
            'override_reason': 'TEXT',
            'otto_action': 'VARCHAR(20)',
            'otto_write_success': 'BOOLEAN',
            'verified': 'BOOLEAN',
            'dow': 'VARCHAR(5)',
            'column_index': 'INTEGER',
            'reasoning': 'TEXT',
        }

        db.cursor.execute('''
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'mlp_order_log'
        ''')
        existing = {row['column_name'] for row in db.cursor.fetchall()}

        for col, col_type in expected_columns.items():
            if col not in existing:
                try:
                    db.cursor.execute(f'ALTER TABLE mlp_order_log ADD COLUMN {col} {col_type}')
                    db.conn.commit()
                    print(f"  [DB] Added missing column: mlp_order_log.{col}")
                except Exception as e:
                    db.conn.rollback()

    def log_decision(self, decision_data: Dict):
        db, should_close = self._get_db()
        try:
            self._ensure_mlp_order_log_table(db)

            inputs = decision_data.get('inputs', {})
            confidence_val = decision_data.get('confidence')
            try:
                confidence_val = float(confidence_val)
            except (ValueError, TypeError):
                confidence_val = None

            db.cursor.execute('''
                INSERT INTO mlp_order_log
                (product_id, store_id, delivery_date, current_stock, projected_stock,
                 expected_sales, actual_sales_rate, monthly_multiplier,
                 pipeline_incoming, returns_rate, day_of_week, is_holiday,
                 mlp_decision, mlp_confidence, mlp_method,
                 adj_value, total_units,
                 tray_factor, features,
                 was_overridden, override_reason,
                 otto_action, otto_write_success, verified,
                 dow, column_index, reasoning)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s)
            ''', (
                decision_data.get('product_id'),
                decision_data.get('store_id', self.store_id),
                decision_data.get('delivery_date'),
                inputs.get('current_stock'),
                decision_data.get('projected_stock_at_delivery'),
                inputs.get('expected_sales'),
                inputs.get('actual_sales_rate'),
                inputs.get('monthly_multiplier'),
                inputs.get('pipeline_incoming'),
                inputs.get('return_rate_pct'),
                inputs.get('day_of_week'),
                inputs.get('is_holiday', False),
                decision_data.get('mlp_raw_decision', decision_data.get('final_decision')),
                confidence_val,
                decision_data.get('method'),
                decision_data.get('final_decision', 0),
                decision_data.get('total_units', 0),
                decision_data.get('tray_factor'),
                str(decision_data.get('features', [])),
                decision_data.get('override_reason') is not None,
                decision_data.get('override_reason'),
                decision_data.get('otto_action'),
                decision_data.get('otto_write_success'),
                decision_data.get('verified'),
                decision_data.get('dow'),
                decision_data.get('column_index'),
                decision_data.get('reasoning'),
            ))
            db.conn.commit()
        except Exception as e:
            print(f"Warning: failed to log decision: {e}")
            try:
                db.conn.rollback()
            except:
                pass
        finally:
            if should_close:
                db.close()


if __name__ == "__main__":
    print("=" * 60)
    print("MLP INVENTORY BRIDGE v9.0 — Multi-Product Pipeline")
    print("=" * 60)
    print("\nSupported Products:")
    for pid, cfg in PRODUCT_CONFIGS.items():
        print(f"  SKU {pid}: {cfg['name']}")
        print(f"    Classes:    {cfg['order_classes']}")
        print(f"    Lead Time:  {cfg['lead_time_days']} days")
        print(f"    Model:      {cfg['model_file']}")
        print(f"    Norm:       inv/{cfg['norm']['inventory_max']}, "
              f"sales/{cfg['norm']['sales_max']}, "
              f"pipe/{cfg['norm']['pipeline_max']}")
    print("\nFeatures (8 inputs per product, product-specific normalization):")
    print("  [inventory/INV_MAX, dow/6, expected_sales/SALES_MAX,")
    print("   actual_sales/SALES_MAX, monthly_mult, is_holiday,")
    print("   pipeline/PIPE_MAX, returns_rate/20]")
    print("=" * 60)
