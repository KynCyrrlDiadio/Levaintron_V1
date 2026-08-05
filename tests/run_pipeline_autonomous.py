#!/usr/bin/env python3
"""
Levaintron Autonomous Pipeline Runner — Demo Build (single product)

Fully non-interactive, headless pipeline execution against the local mock
ordering hub. No manual inputs, no confirmations — runs deterministically.

Usage:
    python -m tests.run_pipeline_autonomous
    python -m tests.run_pipeline_autonomous --mode dry_run
    python -m tests.run_pipeline_autonomous --mode live --product 500107
    python -m tests.run_pipeline_autonomous --all-products

Environment:
    PIPELINE_MODE=live|dry_run   (default: live)
    PIPELINE_PRODUCT=500107      (default: 500107)
"""

import sys
import os
import json
import time
import argparse
import logging
from datetime import datetime, timedelta

sys.path.insert(0, '.')

from Application_env.ai_orchestrator.custom_selenium_order_hub_tools import OrderHubScraper
from Application_env.ai_orchestrator.mlp_inventory_bridge import MLPInventoryBridge
from Application_env.ai_orchestrator.returns_invoice_parser import ReturnsInvoiceParser
from Application_env.ai_orchestrator.pipeline_notifier import send_pipeline_summary, send_email

STORE_ID = '70012004'
HUB_STORE_ID = '70012004'

VALID_DELIVERY_DAYS = {0, 1, 3, 4}  # Mon=0, Tue=1, Thu=3, Fri=4

WEEK_SWITCH_DAYS = {4, 5}  # Fri=4, Sat=5 — days when extended read is needed

PRODUCT_LEAD_TIMES = {
    '500107': 7,
}


def _alert_pipeline_blocked(subject, body):
    """Email an actionable alert when the pipeline aborts before it can order.
    Best-effort: a mail failure must never crash the run. Reuses pipeline_notifier
    SMTP creds (auto-loaded from the repo-root .env, optional in the demo)."""
    try:
        ok = send_email(subject, body)
        logger.info(f"Failure alert email {'sent' if ok else 'NOT sent'}: {subject}")
    except Exception as e:
        logger.warning(f"Failure alert email error: {e}")

DEFAULT_PRODUCTS = ['500107']

ALL_PRODUCTS = {
    '500107': 'Demo_500g_Rye_Bread',
}

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('levaintron-demo-pipeline')

token_parser = ReturnsInvoiceParser(store_id=STORE_ID, enforce_return_days=False)


def run_pre_pipeline_maintenance(product_id):
    logger.info(f"Running token inventory maintenance for {product_id}...")

    expire_result = token_parser.expire_tokens(product_id)
    if expire_result.get('success'):
        matured_count = expire_result.get('tokens_matured_to_sold', 0)
        if matured_count > 0:
            logger.info(f"  {matured_count} tokens reached their shelf life — marked as sold")
    else:
        logger.warning(f"  Token maturity check failed: {expire_result.get('error')}")

    summary = token_parser.get_inventory_summary(product_id)
    if summary.get('success'):
        logger.info(f"  Token Inventory: {summary.get('in_stock', 0)} in_stock, "
                     f"{summary.get('sold', 0)} sold, {summary.get('returned', 0)} returned, "
                     f"{summary.get('expired', 0)} expired")
        logger.info(f"  14-day return rate: {summary.get('return_rate_14d', 0)}%")
        if summary.get('oldest_stock_date'):
            logger.info(f"  Stock age: oldest={summary['oldest_stock_date']}, newest={summary.get('newest_stock_date')}")
    else:
        logger.warning(f"  Could not read token inventory: {summary.get('error')}")
        logger.info("  MLP will use fallback inventory estimates")

    return summary


def sync_delivery_tokens_from_hub(product_id, delivered_dates):
    if not delivered_dates:
        logger.info(f"  No delivered dates from the hub for {product_id} — skipping token sync")
        return 0

    today_str = datetime.now().strftime('%Y-%m-%d')
    tokens_created = 0
    skipped = 0
    for dd in delivered_dates:
        date_str = dd.get('date')
        total = dd.get('total_delivered', 0)
        if total <= 0:
            continue

        if date_str != today_str:
            logger.info(f"  Skipping {date_str} — only syncing today's delivery ({today_str})")
            skipped += 1
            continue

        batch_id = f"OTTO-DELIVERED-{date_str}-{product_id}"

        existing = token_parser.get_tokens_by_batch(product_id, batch_id)
        if existing and len(existing) > 0:
            skipped += 1
            logger.info(f"  Batch {batch_id} already exists ({len(existing)} tokens) — skipping")
            continue

        result = token_parser.add_delivery_tokens(
            product_id=product_id,
            quantity=total,
            arrival_date=date_str,
            batch_id=batch_id,
        )
        if result.get('success'):
            logger.info(f"  Added {total} tokens from {date_str} "
                         f"(batch {batch_id}, expires {result.get('expiration_date')})")
            tokens_created += total
        else:
            logger.warning(f"  Failed to add tokens for {date_str}: {result.get('error')}")

    logger.info(f"  Token sync complete: {tokens_created} new tokens added, "
                 f"{skipped} batches already existed")
    return tokens_created


def create_delivery_tokens_for_verified_orders(decisions):
    today_str = datetime.now().strftime('%Y-%m-%d')
    tokens_created = 0
    for d in decisions:
        if not d.get('verified'):
            continue
        qty = d.get('final_decision', 0)
        if qty <= 0:
            continue

        delivery_date = d.get('delivery_date')
        if not delivery_date:
            continue

        if delivery_date > today_str:
            logger.info(f"  Skipping future token creation for {delivery_date} "
                         f"(qty={qty}) — will sync when delivered")
            continue

        batch_id = f"OTTO-{delivery_date}-{d.get('product_id', '500107')}"
        result = token_parser.add_delivery_tokens(
            product_id=d.get('product_id', '500107'),
            quantity=qty,
            arrival_date=delivery_date,
            batch_id=batch_id,
        )
        if result.get('success'):
            logger.info(f"  Created {qty} delivery tokens for {delivery_date} "
                         f"(batch {batch_id}, expires {result.get('expiration_date')})")
            tokens_created += qty
        else:
            logger.warning(f"  Failed to create tokens for {delivery_date}: {result.get('error')}")

    if tokens_created > 0:
        logger.info(f"  Total delivery tokens created: {tokens_created}")
    return tokens_created


def run_autonomous_pipeline(mode='live', products=None, headless=True, force_extended=False):
    if products is None:
        products = DEFAULT_PRODUCTS

    dry_run = (mode != 'live')
    run_id = f"auto_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

    logger.info(f"{'='*60}")
    logger.info(f"Levaintron Demo Pipeline — Run {run_id}")
    logger.info(f"  Mode:     {'LIVE' if not dry_run else 'DRY RUN'}")
    logger.info(f"  Products: {products}")
    logger.info(f"  Chrome:   {'visible' if not headless else 'headless'}")
    if force_extended:
        logger.info(f"  Extended: FORCED (week switch on any day)")
    logger.info(f"  Store:    {STORE_ID} (internal) / {HUB_STORE_ID} (the hub)")
    logger.info(f"  Time:     {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"{'='*60}")

    logger.info("Initializing MLP bridge (v9.0 multi-product)...")
    try:
        bridge = MLPInventoryBridge(model_path=None, store_id=STORE_ID)
        loaded = list(bridge.models.keys())
        if loaded:
            logger.info(f"MLP models loaded: {loaded} on {bridge.device}")
        else:
            logger.info("No MLP models found — using fallback logic for all products")
    except Exception as e:
        logger.warning(f"Bridge init warning: {e} — continuing with fallback")
        bridge = None

    logger.info(f"Starting {'visible' if not headless else 'headless'} Chrome + the hub navigation...")
    scraper = OrderHubScraper(headless=headless)

    results = {}

    try:
        if not scraper.setup_driver():
            logger.error("FAILED: Could not start Chrome driver")
            _alert_pipeline_blocked(
                "[Levaintron] Pipeline FAILED — Chrome driver did not start",
                "scraper.setup_driver() failed — NO orders went in this run.\n"
                "Check Xvfb/Chrome on the host:\n"
                "  journalctl -u levaintron-demo-pipeline --no-pager | tail -50")
            return {'success': False, 'error': 'Chrome driver failed'}

        if not scraper.navigate_to_ordering_hub():
            logger.error("FAILED: Could not reach ordering hub")
            kind = getattr(scraper, 'last_block_kind', None)
            if kind == 'cloudflare':
                _alert_pipeline_blocked(
                    "[Levaintron] Pipeline BLOCKED — Cloudflare challenge",
                    "the hub is showing the Cloudflare 'Verify you are human' challenge — "
                    "NO orders went in this run.\n\n"
                    "Fix: on the host run\n"
                    "  python -m tests.solve_challenge\n"
                    "then connect to the host display and complete the check once.\n"
                    "(See project_hub_bot_challenge.)")
            else:
                _alert_pipeline_blocked(
                    "[Levaintron] Pipeline FAILED — could not reach the hub (possible UI change)",
                    "navigate_to_ordering_hub() failed and no Cloudflare markers were found — "
                    "likely a hub UI/selector change, not the bot challenge. "
                    "NO orders went in this run.\n\n"
                    "Check:\n  journalctl -u levaintron-demo-pipeline --no-pager | tail -50")
            return {'success': False, 'error': 'the hub navigation failed'}

        logger.info(f"Switching to store {HUB_STORE_ID}...")
        if hasattr(scraper, 'switch_to_store'):
            scraper.switch_to_store(HUB_STORE_ID)
        time.sleep(2)
        logger.info(f"Ready on store {HUB_STORE_ID}")

        all_decisions = {}
        total_written = 0
        write_weeks = set()

        for i, product_id in enumerate(products):
            is_last_product = (i == len(products) - 1)
            product_name = ALL_PRODUCTS.get(product_id, f'Unknown ({product_id})')
            logger.info(f"\n{'─'*60}")
            logger.info(f"Processing: {product_id} — {product_name}")
            logger.info(f"{'─'*60}")

            try:
                result = run_product_autonomous(
                    scraper, bridge, product_id, dry_run=dry_run,
                    force_extended=force_extended,
                    is_last_product=is_last_product,
                    run_id=run_id,
                )
                results[product_id] = result
                if result.get('decisions_data'):
                    all_decisions[product_id] = result['decisions_data']
                total_written += result.get('written', 0)
                if result.get('write_week'):
                    write_weeks.add(result['write_week'])
            except Exception as e:
                logger.error(f"Error processing {product_id}: {e}")
                import traceback
                traceback.print_exc()
                results[product_id] = {'success': False, 'error': str(e)}

        if dry_run or total_written == 0:
            if total_written == 0 and not dry_run:
                logger.info("No writes across any product — skipping submit")
        else:
            logger.info(f"\n{'='*60}")
            logger.info(f"ALL PRODUCTS WRITTEN — {total_written} total ADJ values")
            logger.info(f"Submitting all changes with one click...")
            logger.info(f"{'='*60}")

            if write_weeks:
                submit_week = max(write_weeks)
                current_week, _ = scraper.get_current_week_number()
                if current_week != submit_week:
                    logger.info(f"Navigating to week {submit_week} where changes were written...")
                    scraper.navigate_to_week(submit_week)
                    scraper._wait_for_page_ready(timeout=15)
                    time.sleep(2)
                else:
                    logger.info(f"Already on week {submit_week} — ready to submit")

            logger.info("Clearing product filter before submit...")
            scraper.search_product('')
            time.sleep(2)

            submit_result = scraper.click_green_submit_button()

            if not submit_result.get('success') or not submit_result.get('popup_appeared'):
                logger.error(f"Submit button issue: {submit_result.get('error', submit_result.get('message'))}")
                for pid, decs in all_decisions.items():
                    log_decisions(bridge, decs, submitted=False)
            else:
                orders = submit_result.get('orders', [])
                logger.info(f"Popup shows {len(orders)} changed orders across all products")

                logger.info("Auto-confirming submission (two-step)...")
                confirm_result = scraper.confirm_popup_submit()

                if not confirm_result.get('success'):
                    logger.error(f"Confirm failed: {confirm_result.get('error')}")
                    for pid, decs in all_decisions.items():
                        log_decisions(bridge, decs, submitted=False)
                else:
                    if confirm_result.get('second_dialog'):
                        logger.info("vendor confirmation dialog handled")
                    logger.info(f"Submit confirmed: {confirm_result.get('message')}")
                    time.sleep(3)

                    for pid, decs in all_decisions.items():
                        product_name = ALL_PRODUCTS.get(pid, pid)
                        logger.info(f"\nVerifying {pid} — {product_name}...")

                        verify_pass_1 = scraper.read_pipeline(product_id=pid, store_id=HUB_STORE_ID)
                        time.sleep(2)
                        verify_pass_2 = scraper.read_pipeline(product_id=pid, store_id=HUB_STORE_ID)

                        verified_count = 0
                        for d in decs:
                            if d.get('otto_action') == 'written':
                                d['otto_action'] = 'submitted'
                                expected = d.get('final_decision', 0)
                                date = d.get('delivery_date')
                                p1_val = get_adj_for_date(verify_pass_1, date)
                                p2_val = get_adj_for_date(verify_pass_2, date)
                                if p1_val == expected or p2_val == expected:
                                    d['verified'] = True
                                    verified_count += 1
                                    logger.info(f"  {date}: VERIFIED (ADJ={expected})")
                                else:
                                    d['verified'] = False
                                    logger.warning(f"  {date}: NOT VERIFIED (expected={expected}, got p1={p1_val} p2={p2_val})")

                        log_decisions(bridge, decs, submitted=True)

                        if verified_count > 0:
                            logger.info(f"Creating delivery tokens for {pid} verified orders...")
                            tokens_created = create_delivery_tokens_for_verified_orders(decs)
                            post_summary = token_parser.get_inventory_summary(pid)
                            if post_summary.get('success'):
                                logger.info(f"  Post-submit token inventory: {post_summary.get('in_stock', 0)} in_stock")

                        results[pid]['verified'] = verified_count
                        results[pid]['submitted'] = True

    except Exception as e:
        logger.error(f"Pipeline error: {e}")
        import traceback
        traceback.print_exc()
        try:
            send_pipeline_summary(
                run_id, results, mode=('dry_run' if dry_run else 'live'),
                product_names=ALL_PRODUCTS, error=str(e), dry_run=dry_run,
            )
        except Exception:
            pass
        return {'success': False, 'error': str(e), 'results': results}
    finally:
        logger.info("Closing Chrome...")
        try:
            scraper.close()
        except:
            pass

    success_count = sum(1 for r in results.values() if r.get('success', False))
    total = len(results)
    logger.info(f"\n{'='*60}")
    logger.info(f"PIPELINE COMPLETE — {success_count}/{total} products processed")
    logger.info(f"{'='*60}")

    # Email a detailed decision/write summary for every live run (incl. all-HOLD).
    # Wrapped so a mail failure never affects the pipeline outcome.
    try:
        notify = send_pipeline_summary(
            run_id, results, mode=('dry_run' if dry_run else 'live'),
            product_names=ALL_PRODUCTS, dry_run=dry_run,
        )
        if notify.get('email_sent'):
            logger.info(f"Summary email sent — {notify.get('ordered')} pcs, "
                        f"{notify.get('failures')} write failures")
        elif not dry_run:
            logger.warning(f"Summary email NOT sent: {notify}")
    except Exception as e:
        logger.warning(f"Summary email step failed (non-fatal): {e}")

    return {'success': True, 'run_id': run_id, 'results': results}


def run_product_autonomous(scraper, bridge, product_id, dry_run=False, force_extended=False, is_last_product=False, run_id=None):
    start_time = time.time()

    lead_time = PRODUCT_LEAD_TIMES.get(product_id, 3)
    today_dow = datetime.now().weekday()
    use_extended = force_extended or (today_dow in WEEK_SWITCH_DAYS)

    if use_extended:
        day_name = datetime.now().strftime('%A')
        reason = "FORCED" if force_extended else f"{day_name} in WEEK_SWITCH_DAYS"
        logger.info(f"[WEEK SWITCH] {reason} + lead time {lead_time}d → using extended pipeline read")
        required_days = 999 if force_extended else lead_time + 2
        pipeline_data = scraper.read_pipeline_extended(
            product_id=product_id,
            store_id=HUB_STORE_ID,
            required_future_days=required_days,
        )
    else:
        logger.info(f"Reading hub pipeline for {product_id}...")
        pipeline_data = scraper.read_pipeline(
            product_id=product_id,
            store_id=HUB_STORE_ID,
        )

    if not pipeline_data.get('success'):
        logger.error(f"Pipeline read failed: {pipeline_data.get('error')}")
        return {'success': False, 'error': pipeline_data.get('error')}

    pipeline_incoming = pipeline_data.get('pipeline_incoming', 0)
    locked_dates = pipeline_data.get('locked_dates', {})
    adjustable_dates = pipeline_data.get('adjustable_dates', [])
    delivered_dates = pipeline_data.get('delivered_dates', [])
    delivered_total = pipeline_data.get('delivered_total', 0)
    logger.info(f"Pipeline incoming (future only): {pipeline_incoming} pieces "
                 f"across {len(locked_dates)} locked dates, "
                 f"{len(adjustable_dates)} adjustable dates")
    logger.info(f"Delivered (past+today): {delivered_total} pieces across "
                 f"{len(delivered_dates)} dates")

    logger.info("Syncing delivery tokens from the hub (additive — no reset)...")
    rebuilt_tokens = sync_delivery_tokens_from_hub(product_id, delivered_dates)

    inv_summary = run_pre_pipeline_maintenance(product_id)

    filtered_dates = []
    skipped_days = []
    for d in adjustable_dates:
        date_str = d.get('date', '')
        try:
            dt = datetime.strptime(date_str, '%Y-%m-%d')
            if dt.weekday() in VALID_DELIVERY_DAYS:
                filtered_dates.append(d)
            else:
                day_name = dt.strftime('%A')
                skipped_days.append(f"{date_str} ({day_name})")
        except ValueError:
            filtered_dates.append(d)

    if skipped_days:
        logger.info(f"Skipping non-delivery days: {', '.join(skipped_days)}")
    adjustable_dates = filtered_dates
    logger.info(f"Valid delivery dates: {len(adjustable_dates)} (Mon/Tue/Thu/Fri only)")

    if not adjustable_dates:
        logger.info("No adjustable dates on valid delivery days — nothing to order")
        return {'success': True, 'decisions': [], 'written': 0, 'skipped': 0}

    logger.info(f"Running MLP v8.5 for {len(adjustable_dates)} dates...")
    decisions = bridge.get_multi_date_decisions(
        product_id=product_id,
        adjustable_dates=adjustable_dates,
        pipeline_incoming=pipeline_incoming,
        locked_pipeline_by_date=locked_dates,
    )

    for d in decisions:
        qty = d.get('final_decision', 0)
        date = d.get('delivery_date', '?')
        stock = d.get('projected_stock_at_delivery', d.get('inputs', {}).get('current_stock', '?'))
        conf = d.get('confidence', 0)
        method = d.get('method', '?')
        action = 'HOLD' if qty == 0 else f'ORDER {qty}'
        inputs = d.get('inputs', {})
        wx_str = ''
        if inputs.get('weather_aware') and inputs.get('outdoor_score') is not None:
            wx_str = f' wx={inputs["outdoor_score"]:.3f}'
        logger.info(f"  {date}: {action} qty={qty} (stock={stock}{wx_str}) [{method} {conf:.0%}]")

    def _needs_hub_write(d):
        """MLP owns all cells — every adjustable date gets written."""
        return True

    has_writes = any(_needs_hub_write(d) for d in decisions)

    if not has_writes:
        logger.info("MLP says no adjustments needed — pipeline covers demand")
        if use_extended and pipeline_data.get('week_navigation_used'):
            original_week = pipeline_data.get('original_week')
            if original_week:
                logger.info(f"Returning to week {original_week}...")
                scraper.navigate_to_week(original_week)
                time.sleep(1)
        log_decisions(bridge, decisions, submitted=False)
        return {
            'success': True,
            'decisions': len(decisions),
            'written': 0,
            'skipped': len(decisions),
        }

    if dry_run:
        logger.info("DRY RUN — skipping writes")
        if use_extended and pipeline_data.get('week_navigation_used'):
            original_week = pipeline_data.get('original_week')
            if original_week:
                logger.info(f"Returning to week {original_week}...")
                scraper.navigate_to_week(original_week)
                time.sleep(1)
        log_decisions(bridge, decisions, submitted=False)
        return {
            'success': True,
            'mode': 'dry_run',
            'decisions': len(decisions),
            'written': 0,
            'skipped': len(decisions),
        }

    write_count = sum(1 for d in decisions if _needs_hub_write(d))
    zero_count = sum(1 for d in decisions if d.get('final_decision', 0) == 0 and _needs_hub_write(d))
    if zero_count:
        logger.info(f"LIVE MODE — writing {write_count} ADJ values to the hub ({zero_count} zero overrides)...")
    else:
        logger.info(f"LIVE MODE — writing {write_count} ADJ values to the hub...")

    original_week = pipeline_data.get('original_week')

    write_week = None

    if use_extended and pipeline_data.get('week_navigation_used'):
        write_week = pipeline_data.get('currently_on_week')
        logger.info(f"Extended read — browser on week {write_week}, "
                     f"writing all ADJ values here")

        scraper._wait_for_page_ready(timeout=15)
        if not scraper.search_product(product_id):
            logger.error(f"Failed to filter product {product_id} on extended week")
            return {'success': False, 'error': 'Product filter failed on extended week'}

        time.sleep(2)

        written = 0
        failed = 0
        for d in decisions:
            qty = d.get('final_decision', 0)
            current_so = d.get('current_so', 0)

            col_index = d.get('column_index')
            if col_index is None:
                logger.warning(f"  {d.get('delivery_date')}: No column index — skipping")
                d['otto_action'] = 'skipped'
                failed += 1
                continue

            # ── Zero S.O. if it has a value ──
            if current_so > 0:
                so_result = scraper.write_so_cell_by_index(product_id, col_index, so_value=0)
                if so_result.get('success'):
                    logger.info(f"  {d.get('delivery_date')}: Zeroed S.O. (was {current_so}) col {col_index}")
                else:
                    logger.warning(f"  {d.get('delivery_date')}: S.O. zero FAILED — {so_result.get('error')}")

            # ── Write ADJ = MLP decision ──
            result = scraper.write_adj_cell_by_index(
                product_id=product_id,
                column_index=col_index,
                adj_value=qty
            )

            if result.get('success'):
                action_label = f"ADJ={qty}" if qty > 0 else "ADJ=0 (HOLD)"
                logger.info(f"  {d.get('delivery_date')}: Wrote {action_label} to col {col_index}")
                d['otto_action'] = 'written'
                written += 1
            else:
                logger.error(f"  {d.get('delivery_date')}: Write FAILED — {result.get('error')}")
                d['otto_action'] = 'failed'
                failed += 1

        if original_week and not is_last_product:
            logger.info(f"Returning to week {original_week} for next product...")
            scraper.navigate_to_week(original_week)
            time.sleep(1)
        elif is_last_product:
            logger.info(f"Last product — staying on week {write_week} for submit")
    else:
        current_week, _ = scraper.get_current_week_number()
        write_week = current_week

        written = 0
        failed = 0
        for d in decisions:
            qty = d.get('final_decision', 0)
            current_so = d.get('current_so', 0)

            col_index = d.get('column_index')
            if col_index is None:
                logger.warning(f"  {d.get('delivery_date')}: No column index — skipping")
                d['otto_action'] = 'skipped'
                failed += 1
                continue

            # ── Zero S.O. if it has a value ──
            if current_so > 0:
                so_result = scraper.write_so_cell_by_index(product_id, col_index, so_value=0)
                if so_result.get('success'):
                    logger.info(f"  {d.get('delivery_date')}: Zeroed S.O. (was {current_so}) col {col_index}")
                else:
                    logger.warning(f"  {d.get('delivery_date')}: S.O. zero FAILED — {so_result.get('error')}")

            # ── Write ADJ = MLP decision ──
            result = scraper.write_adj_cell_by_index(
                product_id=product_id,
                column_index=col_index,
                adj_value=qty
            )

            if result.get('success'):
                action_label = f"ADJ={qty}" if qty > 0 else "ADJ=0 (HOLD)"
                logger.info(f"  {d.get('delivery_date')}: Wrote {action_label} to col {col_index}")
                d['otto_action'] = 'written'
                written += 1
            else:
                logger.error(f"  {d.get('delivery_date')}: Write FAILED — {result.get('error')}")
                d['otto_action'] = 'failed'
                failed += 1

    duration = time.time() - start_time
    logger.info(f"Product {product_id} write phase complete: {written} written, {failed} failed, {duration:.1f}s")

    return {
        'success': written > 0 or failed == 0,
        'written': written,
        'failed': failed,
        'decisions_data': decisions,
        'write_week': write_week,
        'duration': round(duration, 1),
    }


def get_adj_for_date(pipeline_data, target_date):
    if not pipeline_data or not pipeline_data.get('success'):
        return None
    for date_info in pipeline_data.get('adjustable_dates', []):
        if date_info.get('date') == target_date:
            return date_info.get('current_adj', date_info.get('adj',
                   date_info.get('fo_value', date_info.get('fo'))))
    return None


def log_decisions(bridge, decisions, submitted=False):
    if bridge is None:
        return
    try:
        from tests.test_full_pipeline_live import log_all_decisions_to_db
        log_all_decisions_to_db(bridge, decisions, submitted=submitted)
    except Exception as e:
        logger.warning(f"DB logging failed: {e}")


def validate_products_against_db(products):
    """Filter the requested SKU list to only those with a row in the products table.

    Any unknown SKU is logged as an ERROR and dropped. This prevents phantom token
    creation when PIPELINE_PRODUCTS contains a typo or stale entry (see incident
    2026-04-13 where SKU '122554' created 549 phantom tokens).
    """
    if not products:
        return list(products), []
    try:
        from Application_env.ai_orchestrator.database_crumbs.Autonomous_Inventory.config import get_database
        db = get_database()
        db.cursor.execute(
            'SELECT product_id FROM products WHERE product_id = ANY(%s)',
            (list(products),)
        )
        known = {row['product_id'] for row in db.cursor.fetchall()}
        db.close()
    except Exception as e:
        logger.warning(f"Could not validate PIPELINE_PRODUCTS against DB ({e}) — proceeding with raw list")
        return list(products), []

    valid = [p for p in products if p in known]
    unknown = [p for p in products if p not in known]
    for sku in unknown:
        logger.error(f"REJECTED unknown SKU '{sku}' — not found in products table. Skipping to prevent phantom tokens.")
    return valid, unknown


def parse_args():
    parser = argparse.ArgumentParser(description='Levaintron Demo Pipeline Runner')
    parser.add_argument('--mode', choices=['live', 'dry_run'], default=None,
                        help='Run mode (default: from PIPELINE_MODE env or live)')
    parser.add_argument('--product', type=str, nargs='+', default=None,
                        help='Product ID(s) — pass one or more (e.g. --product 500107 500107)')
    parser.add_argument('--all-products', action='store_true',
                        help='Run all known products')
    parser.add_argument('--visible', action='store_true',
                        help='Run Chrome in visible (non-headless) mode for debugging')
    parser.add_argument('--force-extended', action='store_true',
                        help='Force extended pipeline read with week switch regardless of day')
    return parser.parse_args()


def main():
    args = parse_args()

    mode = args.mode or os.environ.get('PIPELINE_MODE', 'live')
    if args.all_products:
        products = list(ALL_PRODUCTS.keys())
    elif args.product:
        products = args.product
    else:
        products_env = os.environ.get('PIPELINE_PRODUCTS', '')
        if products_env:
            products = [p.strip() for p in products_env.split(',') if p.strip()]
        else:
            env_product = os.environ.get('PIPELINE_PRODUCT', '')
            products = [env_product] if env_product else DEFAULT_PRODUCTS

    products, dropped = validate_products_against_db(products)
    if dropped:
        logger.error(f"Dropped {len(dropped)} unknown SKU(s) from run: {dropped}")
    if not products:
        logger.error("No valid SKUs to process after validation — aborting")
        sys.exit(2)

    result = run_autonomous_pipeline(
        mode=mode, products=products,
        headless=not args.visible,
        force_extended=args.force_extended,
    )

    result_file = f"/tmp/levaintron_demo_run_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    try:
        with open(result_file, 'w') as f:
            json.dump(result, f, indent=2, default=str)
        logger.info(f"Results saved to {result_file}")
    except Exception as e:
        logger.warning(f"Could not save results: {e}")

    sys.exit(0 if result.get('success') else 1)


if __name__ == '__main__':
    main()
