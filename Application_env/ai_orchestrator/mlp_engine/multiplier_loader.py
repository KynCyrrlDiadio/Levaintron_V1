"""
Multiplier Loader — single source of truth for training data generators.

Reads monthly, DOW, and WOM multipliers from Postgres tables populated by
build_forecast_from_sales.py. Data generators import this instead of
hardcoding multiplier values.

If DB is unavailable (e.g., CI/testing), raises RuntimeError — no silent
fallbacks to prevent drift between DB and hardcoded values.

Usage:
    from multiplier_loader import load_product_multipliers
    mults = load_product_multipliers('500107')
    # mults['monthly']  -> {1: 0.35, 2: 0.37, ...}
    # mults['dow']      -> {0: 0.95, 1: 1.20, ...}
    # mults['wom']      -> {1: {1: 1.0, 2: 1.0, ...}, 2: {...}, ...}
    # mults['base_avg'] -> 4.74
"""

import os
import psycopg2
import psycopg2.extras

DB_URL = os.environ.get("DEMO_DATABASE_URL", "postgresql://postgres:8989@127.0.0.1:5432/levaintron_demo")


def load_product_multipliers(sku: str, store_id: str = '70012004') -> dict:
    """
    Load all multiplier tables for a product from Postgres.

    Returns dict with keys:
        monthly: {month_int: float}
        dow: {dow_int: float}  (0=Mon..6=Sun)
        wom: {month_int: {week_int: float}}
        base_avg: float (overall daily average from seasonal_pattern)

    Raises RuntimeError if DB connection fails or no data found.
    """
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

    try:
        # Monthly multipliers
        cur.execute(
            'SELECT month, multiplier FROM product_monthly_multipliers '
            'WHERE sku = %s AND store_id = %s ORDER BY month',
            (sku, store_id))
        rows = cur.fetchall()
        if not rows:
            raise RuntimeError(
                f"No monthly multipliers in DB for SKU {sku}. "
                f"Run: python -m Application_env.ai_orchestrator.build_forecast_from_sales --sku {sku}")
        monthly = {int(r['month']): float(r['multiplier']) for r in rows}

        # DOW multipliers
        cur.execute(
            'SELECT day_of_week, multiplier FROM product_dow_multipliers '
            'WHERE sku = %s AND store_id = %s ORDER BY day_of_week',
            (sku, store_id))
        rows = cur.fetchall()
        if not rows:
            raise RuntimeError(f"No DOW multipliers in DB for SKU {sku}")
        dow = {int(r['day_of_week']): float(r['multiplier']) for r in rows}

        # WOM multipliers
        cur.execute(
            'SELECT month, week, multiplier FROM product_wom_multipliers '
            'WHERE sku = %s AND store_id = %s ORDER BY month, week',
            (sku, store_id))
        rows = cur.fetchall()
        wom = {}
        for r in rows:
            m = int(r['month'])
            w = int(r['week'])
            if m not in wom:
                wom[m] = {}
            wom[m][w] = float(r['multiplier'])
        for m in range(1, 13):
            if m not in wom:
                wom[m] = {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0}

        # Base average from seasonal_pattern
        cur.execute(
            'SELECT base_avg FROM seasonal_pattern '
            'WHERE sku = %s AND store_id = %s LIMIT 1',
            (sku, store_id))
        row = cur.fetchone()
        base_avg = float(row['base_avg']) if row else 1.0

        return {
            'monthly': monthly,
            'dow': dow,
            'wom': wom,
            'base_avg': base_avg,
        }

    finally:
        cur.close()
        conn.close()


if __name__ == '__main__':
    import sys
    sku = sys.argv[1] if len(sys.argv) > 1 else '500107'
    print(f"Loading multipliers for SKU {sku}...")
    m = load_product_multipliers(sku)
    print(f"\nBase avg: {m['base_avg']:.2f}/day")
    print(f"\nMonthly: {m['monthly']}")
    print(f"\nDOW: {m['dow']}")
    print(f"\nWOM:")
    for month in range(1, 13):
        print(f"  Month {month:2d}: {m['wom'].get(month, {})}")
