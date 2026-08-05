#!/usr/bin/env python3
"""
MLP-Powered Ordering v8.5 - Full Autonomous Pipeline

Pipeline flow:
    1. the hub Scraper reads pipeline (locked F.O. values + adjustable dates)
    2. MLP v8.5 makes per-date decisions using 8 features
    3. Each adjustable date gets its own MLP call with projected stock
    4. Selenium writes ADJ values to hub grid
    5. Every decision logged to mlp_order_log in PostgreSQL

Features used (8 inputs):
    [inventory/50, dow/7, expected_sales/10, actual_sales/10,
     monthly_mult, is_holiday, pipeline/60, returns_rate/20]

Usage:
    from mlp_powered_ordering import mlp_auto_order_v85, mlp_pipeline_run

    # Single product full pipeline
    result = mlp_pipeline_run('500107')

    # Single product with override
    result = mlp_auto_order_v85('500107', override_quantity=5)
"""

import json
import math
from datetime import datetime, timedelta
from typing import Dict, Optional, List
from pathlib import Path


def mlp_pipeline_run(product_id: str, store_id: str = '70012004',
                     hub_store_id: str = '70012004',
                     dry_run: bool = False) -> Dict:
    """
    Full v8.5 autonomous pipeline: Read the hub -> Per-date MLP -> Write ADJ -> Log

    Pipeline flow:
    1. Reads the hub pipeline (locked F.O. values, adjustable dates)
    2. Gets product info from DB (shelf life, lead time)
    3. Runs MLP v8.5 for each adjustable date with projected stock
    4. Writes MLP decisions (in pieces) to the hub ADJ cells via Selenium
    5. Logs every decision to PostgreSQL mlp_order_log

    All values are in raw pieces throughout — no tray conversion.
    The MLP outputs ORDER 0/5/10/20 (pieces), and that value is written
    directly to the hub's ADJ cell.

    Args:
        product_id: Product SKU (e.g., '500107')
        store_id: Internal store ID for DB queries (default: '70012004')
        hub_store_id: ordering hub store ID for Selenium (default: '70012004')
        dry_run: If True, compute decisions but don't write to the hub

    Returns:
        dict with full pipeline results for all dates
    """
    from .custom_selenium_order_hub_tools import OrderHubScraper
    from .mlp_inventory_bridge import MLPInventoryBridge
    from .database_crumbs.Autonomous_Inventory.config import get_database

    pipeline_start = datetime.now()
    pipeline_log = {
        'pipeline': 'mlp_pipeline_run_v85',
        'product_id': product_id,
        'store_id': store_id,
        'dry_run': dry_run,
        'started_at': pipeline_start.strftime('%Y-%m-%d %H:%M:%S'),
        'steps': [],
        'decisions': [],
    }

    scraper = None
    try:
        db = get_database()
        db.cursor.execute(
            'SELECT product_name, tray_factor, shelf_life_days, lead_time_days '
            'FROM products WHERE product_id = %s',
            (str(product_id),)
        )
        product_info = db.cursor.fetchone()
        if not product_info:
            db.close()
            return {
                'success': False,
                'error': f'Product {product_id} not found in products table',
                'pipeline_log': pipeline_log
            }

        product_name = product_info['product_name']
        tray_factor = product_info['tray_factor'] or 9
        shelf_life = product_info['shelf_life_days'] or 12
        lead_time = product_info['lead_time_days'] or 3

        db.cursor.execute(
            'SELECT COUNT(*) as cnt FROM product_tokens WHERE product_id = %s AND store_id = %s',
            (str(product_id), str(store_id))
        )
        token_check = db.cursor.fetchone()
        token_count = token_check['cnt'] if token_check else 0
        if token_count == 0:
            print(f"[WARNING] No product_tokens found for product_id={product_id}, store_id={store_id}. "
                  f"Inventory/returns data may be unavailable. Pipeline will proceed with defaults.")

        db.close()

        pipeline_log['steps'].append({
            'step': 'product_lookup',
            'product_name': product_name,
            'tray_factor': tray_factor,
            'shelf_life': shelf_life,
            'lead_time': lead_time
        })

        scraper = OrderHubScraper(headless=True)
        pipeline_data = scraper.read_pipeline(
            product_id=product_id,
            store_id=hub_store_id,
        )

        if not pipeline_data.get('success'):
            return {
                'success': False,
                'error': f"hub pipeline read failed: {pipeline_data.get('error', 'Unknown')}",
                'pipeline_log': pipeline_log
            }

        pipeline_incoming = pipeline_data['pipeline_incoming']
        adjustable_dates = pipeline_data['adjustable_dates']
        locked_dates = pipeline_data['locked_dates']
        tray_factor_hub = pipeline_data.get('tray_factor_detected')

        pipeline_log['steps'].append({
            'step': 'hub_pipeline_read',
            'today': pipeline_data.get('today'),
            'pipeline_incoming': pipeline_incoming,
            'locked_dates_count': len(locked_dates),
            'adjustable_dates_count': len(adjustable_dates),
            'tray_factor_from_hub': tray_factor_hub,
            'four_week_return_pct': pipeline_data.get('four_week_return_pct'),
        })

        bridge = MLPInventoryBridge(
            model_path=None,
            store_id='70012004'
        )

        per_date_decisions = bridge.get_multi_date_decisions(
            product_id=product_id,
            adjustable_dates=adjustable_dates,
            pipeline_incoming=pipeline_incoming
        )

        pipeline_log['steps'].append({
            'step': 'mlp_per_date_decisions',
            'total_decisions': len(per_date_decisions),
            'decisions_summary': [
                {
                    'date': d.get('delivery_date'),
                    'dow': d.get('dow'),
                    'decision_pieces': d.get('final_decision'),
                    'fo_value': d.get('fo_value', 0),
                    'projected_stock': d.get('projected_stock_at_delivery'),
                    'confidence': d.get('confidence'),
                    'method': d.get('method'),
                }
                for d in per_date_decisions
            ]
        })

        orders_placed = 0
        orders_skipped = 0
        orders_failed = 0

        for decision in per_date_decisions:
            pieces = decision['final_decision']
            col_idx = decision.get('column_index')
            delivery_date = decision.get('delivery_date', 'unknown')
            current_fo = decision.get('fo_value', 0)
            current_adj = decision.get('current_adj', 0)

            if pieces == current_adj:
                decision['otto_write_success'] = None
                decision['otto_action'] = 'unchanged'
                orders_skipped += 1
                pipeline_log['decisions'].append({
                    'date': delivery_date,
                    'decision_pieces': pieces,
                    'current_adj': current_adj,
                    'current_fo': current_fo,
                    'action': 'unchanged',
                })
                continue

            if pieces == 0 and current_adj > 0:
                decision['otto_write_success'] = None
                decision['otto_action'] = 'satisfied'
                orders_skipped += 1
                pipeline_log['decisions'].append({
                    'date': delivery_date,
                    'decision_pieces': 0,
                    'current_adj': current_adj,
                    'current_fo': current_fo,
                    'action': 'satisfied',
                })
                continue

            if pieces == 0 and current_fo == 0:
                decision['otto_write_success'] = None
                decision['otto_action'] = 'skipped'
                orders_skipped += 1
                pipeline_log['decisions'].append({
                    'date': delivery_date,
                    'decision_pieces': 0,
                    'current_fo': current_fo,
                    'action': 'skipped',
                })
                continue

            decision['total_units'] = pieces

            if dry_run:
                decision['otto_write_success'] = None
                decision['otto_action'] = 'dry_run'
                orders_placed += 1
                pipeline_log['decisions'].append({
                    'date': delivery_date,
                    'decision_pieces': pieces,
                    'current_adj': current_adj,
                    'current_fo': current_fo,
                    'action': 'dry_run',
                })
                continue

            if col_idx is not None:
                write_result = scraper.write_adj_cell_by_index(
                    product_id=product_id,
                    column_index=col_idx,
                    adj_value=pieces
                )

                if write_result.get('success'):
                    decision['otto_write_success'] = True
                    decision['otto_action'] = 'written'
                    orders_placed += 1
                    pipeline_log['decisions'].append({
                        'date': delivery_date,
                        'decision_pieces': pieces,
                        'current_fo': current_fo,
                        'action': 'written',
                        'column': col_idx
                    })
                else:
                    decision['otto_write_success'] = False
                    decision['hub_error_msg'] = write_result.get('error', 'Unknown')
                    decision['otto_action'] = 'failed'
                    orders_failed += 1
                    pipeline_log['decisions'].append({
                        'date': delivery_date,
                        'decision_pieces': pieces,
                        'action': 'failed',
                        'error': write_result.get('error')
                    })
            else:
                decision['otto_write_success'] = False
                decision['hub_error_msg'] = 'No column index'
                decision['otto_action'] = 'no_column'
                orders_failed += 1

        submitted = False
        verified = False
        verify_details = []

        written_decisions = [d for d in per_date_decisions if d.get('otto_action') == 'written']

        if written_decisions and not dry_run:
            pipeline_log['steps'].append({'step': 'submit_start'})

            submit_result = scraper.click_green_submit_button()
            pipeline_log['steps'].append({
                'step': 'submit_click',
                'success': submit_result.get('success'),
                'popup_appeared': submit_result.get('popup_appeared'),
                'orders_in_popup': len(submit_result.get('orders', [])),
            })

            if submit_result.get('success') and submit_result.get('popup_appeared') and not submit_result.get('no_orders'):
                confirm_result = scraper.confirm_popup_submit()
                pipeline_log['steps'].append({
                    'step': 'submit_confirm',
                    'success': confirm_result.get('success'),
                    'popup_closed': confirm_result.get('popup_closed'),
                })

                if confirm_result.get('success'):
                    submitted = True
                    import time as _time
                    _time.sleep(2)

                    verify_1 = scraper.read_pipeline(product_id=product_id, store_id=hub_store_id)
                    _time.sleep(3)
                    verify_2 = scraper.read_pipeline(product_id=product_id, store_id=hub_store_id)

                    if verify_1.get('success') and verify_2.get('success'):
                        adj_map_1 = {d['date']: d.get('current_adj', 0)
                                     for d in verify_1.get('adjustable_dates', [])}
                        adj_map_2 = {d['date']: d.get('current_adj', 0)
                                     for d in verify_2.get('adjustable_dates', [])}

                        verified = True
                        for wd in written_decisions:
                            date = wd.get('delivery_date', '')
                            expected = wd.get('final_decision', 0)
                            a1 = adj_map_1.get(date)
                            a2 = adj_map_2.get(date)
                            date_ok = (a1 == expected) and (a2 == expected)
                            if not date_ok:
                                verified = False
                            verify_details.append({
                                'date': date, 'expected': expected,
                                'pass_1': a1, 'pass_2': a2, 'ok': date_ok
                            })

                    pipeline_log['steps'].append({
                        'step': 'post_submit_verify',
                        'verified': verified,
                        'details': verify_details,
                    })

                    for d in per_date_decisions:
                        if d.get('otto_action') == 'written':
                            d['otto_action'] = 'submitted'
                            d['verified'] = verified

        for decision in per_date_decisions:
            try:
                bridge.log_decision(decision)
            except Exception:
                pass

        pipeline_end = datetime.now()
        duration = round((pipeline_end - pipeline_start).total_seconds(), 2)

        result = {
            'success': True,
            'product_id': product_id,
            'product_name': product_name,
            'store_id': store_id,
            'dry_run': dry_run,

            'pipeline_incoming': pipeline_incoming,
            'locked_dates': len(locked_dates),
            'adjustable_dates': len(adjustable_dates),
            'tray_factor_hub': tray_factor_hub,

            'orders_placed': orders_placed,
            'orders_skipped': orders_skipped,
            'orders_failed': orders_failed,
            'total_decisions': len(per_date_decisions),

            'submitted': submitted,
            'verified': verified,
            'verify_details': verify_details,

            'duration_seconds': duration,
            'pipeline_log': pipeline_log,

            'message': (
                f"Pipeline complete for {product_name}: "
                f"{orders_placed} orders placed, {orders_skipped} skipped, "
                f"{orders_failed} failed across {len(per_date_decisions)} dates. "
                f"Pipeline incoming: {pipeline_incoming} pieces. "
                f"Submitted: {'YES' if submitted else 'NO'}, "
                f"Verified: {'YES' if verified else 'NO'}. "
                f"{'(DRY RUN)' if dry_run else ''} [{duration}s]"
            )
        }

        return result

    except Exception as e:
        import traceback
        return {
            'success': False,
            'error': f"Pipeline error: {str(e)}",
            'traceback': traceback.format_exc(),
            'product_id': product_id,
            'pipeline_log': pipeline_log
        }
    finally:
        if scraper:
            try:
                scraper.close()
            except:
                pass


def mlp_auto_order_v85(product_id: str, override_quantity: int = None,
                       store_id: str = '70012004',
                       hub_store_id: str = '70012004',
                       dry_run: bool = False) -> Dict:
    """
    Single-product v8.5 ordering with optional override.

    This is the simpler entry point for single orders.
    Uses the full pipeline internally but can override the MLP decision.

    Args:
        product_id: Product SKU (e.g., '500107')
        override_quantity: Override MLP decision with specific loaf count
        store_id: Store ID for the hub
        dry_run: If True, don't write to the hub

    Returns:
        dict with order result
    """
    if override_quantity is not None and override_quantity == 0:
        return {
            'success': True,
            'action': 'no_order',
            'product_id': product_id,
            'message': 'User override: no order placed (quantity=0)'
        }

    result = mlp_pipeline_run(
        product_id=product_id,
        store_id=store_id,
        hub_store_id=hub_store_id,
        dry_run=dry_run
    )

    return result


def mlp_auto_order(product_id: str, override_quantity: int = None,
                   max_date_attempts: int = 14, store_id: str = '70012004') -> Dict:
    """Legacy wrapper - redirects to v8.5 pipeline"""
    return mlp_auto_order_v85(
        product_id=product_id,
        override_quantity=override_quantity,
        store_id=store_id
    )


def mlp_batch_order(product_ids: list = None, store_id: str = '70012004',
                    hub_store_id: str = '70012004',
                    dry_run: bool = False) -> Dict:
    """
    Run v8.5 pipeline for multiple products.

    Args:
        product_ids: List of product IDs (None = all active products)
        store_id: Internal store ID for DB (default: '70012004')
        hub_store_id: ordering hub store ID for Selenium (default: '70012004')
        dry_run: If True, don't write to the hub
    """
    from .database_crumbs.Autonomous_Inventory.config import get_database

    if product_ids is None:
        try:
            db = get_database()
            db.cursor.execute(
                'SELECT product_id FROM products WHERE is_active = true ORDER BY product_id'
            )
            product_ids = [row['product_id'] for row in db.cursor.fetchall()]
            db.close()
        except Exception as e:
            return {'success': False, 'error': f"Failed to get product list: {e}"}

    results = {
        'success': True,
        'total_products': len(product_ids),
        'orders_placed': 0,
        'orders_skipped': 0,
        'orders_failed': 0,
        'products': [],
        'started_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }

    for pid in product_ids:
        result = mlp_pipeline_run(
            product_id=pid,
            store_id=store_id,
            hub_store_id=hub_store_id,
            dry_run=dry_run
        )

        summary = {
            'product_id': pid,
            'product_name': result.get('product_name', 'Unknown'),
            'success': result.get('success', False),
            'orders_placed': result.get('orders_placed', 0),
            'orders_skipped': result.get('orders_skipped', 0),
            'orders_failed': result.get('orders_failed', 0),
            'pipeline_incoming': result.get('pipeline_incoming', 0),
        }
        results['products'].append(summary)

        results['orders_placed'] += result.get('orders_placed', 0)
        results['orders_skipped'] += result.get('orders_skipped', 0)
        results['orders_failed'] += result.get('orders_failed', 0)

    results['completed_at'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    results['message'] = (
        f"Batch complete: {results['orders_placed']} orders placed, "
        f"{results['orders_skipped']} skipped, "
        f"{results['orders_failed']} failed across {len(product_ids)} products"
    )

    return results


def get_mlp_ordering_tools() -> Dict:
    """Returns MLP v8.5 ordering tools for the Qwen agent tool registry."""
    return {
        'mlp_pipeline_run': {
            'description': (
                'Full v8.5 autonomous pipeline: Reads hub pipeline (locked orders + adjustable dates), '
                'runs MLP per-date decisions using 8 features (inventory, forecast, pipeline, returns), '
                'writes adjustments to the hub via Selenium, and logs everything to PostgreSQL. '
                'Set dry_run=True to see decisions without writing to the hub.'
            ),
            'parameters': {
                'product_id': 'str - Product ID (e.g., "500107")',
                'dry_run': 'bool - If True, compute but don\'t write to the hub (default: False)',
            },
            'function': mlp_pipeline_run
        },
        'mlp_auto_order': {
            'description': (
                'Legacy single-product ordering. Uses the full v8.5 pipeline internally. '
                'For multi-date pipeline ordering, use mlp_pipeline_run instead.'
            ),
            'parameters': {
                'product_id': 'str - Product ID',
                'override_quantity': 'int - Override MLP decision (optional)',
            },
            'function': mlp_auto_order
        },
        'mlp_batch_order': {
            'description': (
                'Run v8.5 pipeline for multiple products at once. '
                'Gets all active products from database if no list provided. '
                'Each product gets its own pipeline read + per-date MLP decisions.'
            ),
            'parameters': {
                'product_ids': 'list - Product IDs to process (optional, omit for all)',
                'dry_run': 'bool - If True, compute but don\'t write (default: False)',
            },
            'function': mlp_batch_order
        }
    }


def register_mlp_ordering_tools(orchestrator):
    """Register MLP v8.5 ordering tools into a QwenOrchestrator instance."""
    tools = get_mlp_ordering_tools()
    registered = []
    for tool_name, tool_info in tools.items():
        orchestrator.register_tool(
            tool_name,
            tool_info['description'],
            tool_info['parameters'],
            tool_info['function']
        )
        registered.append(tool_name)
    print(f"[MLP Ordering v8.5] Registered {len(registered)} tools: {', '.join(registered)}")
    return registered


if __name__ == "__main__":
    print("=" * 70)
    print("MLP-POWERED ORDERING v8.5 - Autonomous Pipeline")
    print("=" * 70)
    print("\nPipeline flow:")
    print("  1. the hub Scraper reads pipeline (locked F.O. + adjustable dates)")
    print("  2. MLP v8.5 makes per-date decisions (8 features each)")
    print("  3. Selenium writes ADJ values to hub grid")
    print("  4. PostgreSQL logs every decision with full feature snapshot")
    print("\nv8.5 Features:")
    print("  [inventory/50, dow/7, expected_sales/10, actual_sales/10,")
    print("   monthly_mult, is_holiday, pipeline/60, returns_rate/20]")
    print("\nUsage:")
    print("  from mlp_powered_ordering import mlp_pipeline_run")
    print("  result = mlp_pipeline_run('500107')           # Full autonomous")
    print("  result = mlp_pipeline_run('500107', dry_run=True)  # Preview only")
    print("  result = mlp_batch_order()                    # All products")
    print("=" * 70)
