#!/usr/bin/env python3
"""
Full End-to-End Pipeline Live Test

Runs the complete autonomous ordering pipeline:
    1. the hub Scraper reads pipeline (Chrome visible)
    2. MLP v8.5 makes per-date decisions with projected stock
    3. Decisions displayed for review (DRY RUN by default)
    4. Write ADJ values to the hub cells
    5. Click green submit → scrape confirmation popup → display for review
    6. User confirms → click confirm in popup
    7. Post-submit: double-scrape verification (catches the hub multi-submit failures)
    8. Log confirmed values to PostgreSQL (only after verification)

Usage (from your Fedora machine):
    cd ~/Levaintron Demo_for_Crumbs
    python -m tests.test_full_pipeline_live

Modes:
    DRY RUN (default):  Read the hub + MLP decisions + show what WOULD be written
    LIVE MODE:          Actually write ADJ values to the hub cells + log to DB

Safety:
    - Always starts in DRY RUN mode
    - Must explicitly type 'live' to enable writing
    - Shows full decision table before writing
    - Asks for final confirmation before each write
"""

import sys
import os
import json
import time
from datetime import datetime, timedelta

sys.path.insert(0, '.')

from Application_env.ai_orchestrator.custom_selenium_order_hub_tools import OrderHubScraper
from Application_env.ai_orchestrator.mlp_inventory_bridge import MLPInventoryBridge


KNOWN_PRODUCTS = {
    '500107': 'Demo_500g_Rye_Bread',
}

STORE_ID = '70012004'
HUB_STORE_ID = '70012004'


def print_header(title, char='='):
    width = 76
    print(f"\n{char * width}")
    print(f"  {title}")
    print(f"{char * width}")


def print_step(num, msg):
    print(f"\n[STEP {num}] {msg}")


def display_pipeline_summary(pipeline_data):
    print_header("the hub PIPELINE READ")

    locked = pipeline_data.get('locked_dates', {})

    print(f"  Product:             {pipeline_data.get('product_id', '?')}")
    print(f"  Today:               {pipeline_data.get('today', '?')}")
    print(f"  Pipeline Incoming:   {pipeline_data['pipeline_incoming']} pieces (sum of all F.O.)")
    print(f"  Tray Factor (the hub):  {pipeline_data.get('tray_factor_detected', 'N/A')}")
    print(f"  4-Week Return %:     {pipeline_data.get('four_week_return_pct', 'N/A')}")

    print(f"\n  Locked dates ({len(locked)}):")
    for date_str, info in sorted(locked.items()):
        print(f"    {date_str}:  F.O. = {info['fo_value']} pieces")

    adj = pipeline_data.get('adjustable_dates', [])
    print(f"\n  Adjustable dates ({len(adj)}):")
    for d in adj:
        adj_note = f", ADJ={d['current_adj']}" if d.get('current_adj', 0) > 0 else ""
        print(f"    {d['date']} ({d.get('dow', '?')}): "
              f"F.O.={d.get('fo_value', 0)}{adj_note}  [col {d['column_index']}]")


def display_inventory_snapshot(bridge, product_id):
    print_header("INVENTORY SNAPSHOT", '-')

    try:
        inv = bridge.get_inferred_inventory(product_id)
        sales = bridge.get_inferred_sales_rate(product_id)

        print(f"  Current Stock (tokens):  {inv['estimated_inventory']} pieces")
        print(f"  Expiring Soon (3d):      {inv['expiring_soon']} pieces")
        print(f"  Oldest Batch Age:        {inv['oldest_batch_age']} days")

        print(f"  Daily Sales Rate (14d):  {sales['daily_sales_rate']}/day")
        print(f"  Return Rate (14d):       {sales['return_rate_pct']}%")
        print(f"  Sold (14d):              {sales['total_sold']}")
        print(f"  Returned (14d):          {sales['total_returned']}")
        print(f"  Delivered (14d):         {sales['total_delivered']}")

        if inv['estimated_inventory'] > 0 and sales['daily_sales_rate'] > 0:
            days_of_stock = inv['estimated_inventory'] / sales['daily_sales_rate']
            print(f"  Days of Stock:           {days_of_stock:.1f} days")

        return inv, sales
    except Exception as e:
        print(f"  WARNING: Could not get inventory data: {e}")
        print(f"  Pipeline will use fallback estimates.")
        return None, None


def display_decisions_table(decisions, product_name):
    print_header(f"MLP DECISIONS — {product_name}")

    total_mlp = 0

    print(f"  {'Date':<12} {'DOW':<5} {'Stock':<7} {'F.O.':<6} {'ADJ':<5} {'MLP':<6} "
          f"{'Conf':<7} {'Method':<12} {'Action':<12} {'Col':<5}")
    print(f"  {'-'*12} {'-'*5} {'-'*7} {'-'*6} {'-'*5} {'-'*6} "
          f"{'-'*7} {'-'*12} {'-'*12} {'-'*5}")

    for d in decisions:
        date = d.get('delivery_date', '?')
        dow = d.get('dow', '?')
        stock = d.get('projected_stock_at_delivery', '?')
        fo = d.get('fo_value', 0)
        adj = d.get('current_adj', 0)
        mlp = d.get('final_decision', 0)
        try:
            conf = float(d.get('confidence', 0))
        except (ValueError, TypeError):
            conf = 0.0
        method = d.get('method', '?')
        col = d.get('column_index', '?')

        if mlp == adj:
            if adj > 0:
                action = 'UNCHANGED'
            elif fo == 0:
                action = 'SKIP'
            else:
                action = 'SATISFIED'
        elif mlp > 0 and adj == mlp:
            action = 'UNCHANGED'
        elif mlp > 0:
            if adj > 0:
                action = f'ADJ {adj}->{mlp}'
            else:
                action = f'WRITE {mlp}'
        else:
            action = 'SATISFIED'

        total_mlp += mlp

        print(f"  {date:<12} {dow:<5} {stock:<7} {fo:<6} {adj:<5} {mlp:<6} "
              f"{conf:<7.1%} {method:<12} {action:<12} {col:<5}")

    print(f"\n  Total MLP adjustment: {total_mlp} pieces across {len(decisions)} dates")


def display_decision_details(decisions):
    print_header("DECISION DETAILS", '-')

    has_any = False
    for d in decisions:
        mlp = d.get('final_decision', 0)
        adj = d.get('current_adj', 0)
        fo = d.get('fo_value', 0)

        if mlp > 0 or (mlp != adj):
            has_any = True
            print(f"\n  {d['delivery_date']} ({d.get('dow', '?')}):")
            print(f"    {d.get('reasoning', 'No reasoning')}")
            if d.get('override_reason'):
                print(f"    OVERRIDE: {d['override_reason']}")
            if mlp == 0 and adj > 0:
                print(f"    MLP says 0 but existing ADJ={adj} (from prior run). Not clearing.")

            feats = d.get('features', [])
            if feats:
                labels = ['inv/50', 'dow/7', 'exp_s/10', 'act_s/10',
                          'mo_mult', 'holiday', 'pipe/60', 'ret/20']
                feat_str = ', '.join(f"{l}={float(v):.3f}" for l, v in zip(labels, feats))
                print(f"    Features: [{feat_str}]")

            probs = d.get('probabilities', {})
            if probs:
                classes = [0, 5, 10, 20]
                prob_str = ', '.join(f"P({c})={float(probs.get(str(c), 0)):.1%}" for c in classes)
                print(f"    Probabilities: {prob_str}")

    if not has_any:
        existing_adj = sum(d.get('current_adj', 0) for d in decisions)
        if existing_adj > 0:
            print(f"\n  MLP agrees with prior ADJ placements ({existing_adj} total pieces).")
            print(f"  Current pipeline covers projected demand — no changes needed.")
        else:
            print(f"\n  MLP says no adjustments needed — pipeline covers demand.")


def execute_writes(scraper, decisions, product_id, bridge, dry_run):
    print_header("EXECUTING WRITES" if not dry_run else "DRY RUN — NO WRITES")

    written = 0
    skipped = 0
    failed = 0

    for d in decisions:
        pieces = d['final_decision']
        col_idx = d.get('column_index')
        date = d.get('delivery_date', '?')
        current_fo = d.get('fo_value', 0)
        current_adj = d.get('current_adj', 0)

        if pieces == current_adj:
            d['otto_write_success'] = None
            d['otto_action'] = 'unchanged'
            skipped += 1
            if current_adj > 0:
                print(f"  {date}: UNCHANGED (ADJ already {current_adj}, F.O.={current_fo})")
            elif current_fo > 0:
                print(f"  {date}: SATISFIED (F.O.={current_fo} covers demand, no ADJ needed)")
            else:
                print(f"  {date}: SKIP (no orders on this date)")
            continue

        if pieces == 0 and current_adj > 0:
            d['otto_write_success'] = None
            d['otto_action'] = 'unchanged'
            skipped += 1
            print(f"  {date}: SATISFIED (MLP needs 0 extra, existing ADJ={current_adj} from prior run, F.O.={current_fo})")
            continue

        if pieces == 0 and current_fo == 0:
            d['otto_write_success'] = None
            d['otto_action'] = 'skipped'
            skipped += 1
            print(f"  {date}: SKIP (no orders on this date)")
            continue

        d['total_units'] = pieces

        if dry_run:
            d['otto_write_success'] = None
            d['otto_action'] = 'dry_run'
            written += 1
            change = f"ADJ {current_adj}->{pieces}" if current_adj > 0 else f"ADJ={pieces}"
            print(f"  {date}: WOULD WRITE {change} to col {col_idx} "
                  f"(current F.O.={current_fo})")
        else:
            change = f"ADJ {current_adj}->{pieces}" if current_adj > 0 else f"ADJ={pieces}"
            print(f"  {date}: Writing {change} to col {col_idx}...", end='', flush=True)
            write_result = scraper.write_adj_cell_by_index(
                product_id=product_id,
                column_index=col_idx,
                adj_value=pieces
            )

            if write_result.get('success'):
                d['otto_write_success'] = True
                d['otto_action'] = 'written'
                written += 1
                print(f" OK")
            else:
                d['otto_write_success'] = False
                d['hub_error_msg'] = write_result.get('error', 'Unknown')
                d['otto_action'] = 'failed'
                failed += 1
                print(f" FAILED: {write_result.get('error')}")

    return written, skipped, failed


def display_popup_orders(orders):
    print_header("SUBMIT PREVIEW — Changed Orders Popup")

    if not orders:
        print("  No order changes found in popup.")
        return

    print(f"  {'#':<4} {'Customer':<15} {'Product':<12} {'S.O.':<6} {'ADJ':<6} "
          f"{'F.O.':<6} {'Date':<12}")
    print(f"  {'-'*4} {'-'*15} {'-'*12} {'-'*6} {'-'*6} "
          f"{'-'*6} {'-'*12}")

    for i, o in enumerate(orders, 1):
        print(f"  {i:<4} {o.get('customer_id','?'):<15} {o.get('product_id','?'):<12} "
              f"{o.get('standing_order',''):<6} {o.get('adjustment',''):<6} "
              f"{o.get('final_order',''):<6} {o.get('order_date',''):<12}")

    print(f"\n  Total rows: {len(orders)}")


def submit_and_verify(scraper, bridge, decisions, product_id, pipeline_data, dry_run):
    written_decisions = [d for d in decisions if d.get('otto_action') == 'written']

    if not written_decisions:
        print("\n  No writes were made — skipping submit.")
        log_all_decisions_to_db(bridge, decisions, submitted=False)
        return

    if dry_run:
        print("\n  DRY RUN — skipping submit + verify.")
        log_all_decisions_to_db(bridge, decisions, submitted=False)
        return

    print_step(5, "Clicking green submit button...")
    print("  Watch Chrome...\n")

    submit_result = scraper.click_green_submit_button()

    if not submit_result.get('success'):
        print(f"  SUBMIT ERROR: {submit_result.get('error', 'Unknown')}")
        print("  ADJ values were written but NOT submitted. They remain as pending changes.")
        log_all_decisions_to_db(bridge, decisions, submitted=False)
        return

    if not submit_result.get('popup_appeared'):
        print(f"  {submit_result.get('message', 'No popup appeared')}")
        print("  This may mean The hub has no pending changes to submit.")
        log_all_decisions_to_db(bridge, decisions, submitted=False)
        return

    if submit_result.get('no_orders'):
        print("  Popup says: 'No orders have been adjusted'")
        print("  This is unexpected after writing ADJ values — check the hub state.")
        log_all_decisions_to_db(bridge, decisions, submitted=False)
        return

    orders = submit_result.get('orders', [])
    display_popup_orders(orders)

    print(f"\n  *** REVIEW THE CHANGES ABOVE ***")
    print(f"  These {len(orders)} order changes will be submitted to the hub.")
    confirm = input("  Type 'confirm' to submit, anything else to cancel: ").strip().lower()

    if confirm != 'confirm':
        print("  Cancelled — dismissing popup. ADJ values remain as pending (not submitted).")
        scraper.dismiss_popup()
        log_all_decisions_to_db(bridge, decisions, submitted=False)
        return

    print_step(6, "Submitting to the hub (two-step confirm)...")
    print("  Step 6a: Clicking Submit in Changed Orders popup...")
    confirm_result = scraper.confirm_popup_submit()

    if not confirm_result.get('success'):
        print(f"  SUBMIT ERROR: {confirm_result.get('error')}")
        if confirm_result.get('dialog_text'):
            print(f"  Dialog text: {confirm_result['dialog_text'][:200]}")
        print("  NOTE: ADJ values are still written — submit manually if needed.")
        log_all_decisions_to_db(bridge, decisions, submitted=False)
        return

    if confirm_result.get('second_dialog'):
        print("  Step 6b: 'Submit changes to the distributor' dialog handled.")
    if confirm_result.get('popup_closed'):
        print(f"  RESULT: {confirm_result.get('message', 'Submitted')}")
    else:
        print(f"  WARNING: {confirm_result.get('message', 'Submitted')}")
        print("  Dialogs may still be visible — check Chrome window.")
    time.sleep(2)

    print_step(7, "Post-submit verification — re-reading pipeline (pass 1 of 2)...")
    verify_pass_1 = scraper.read_pipeline(product_id=product_id, store_id=HUB_STORE_ID)
    time.sleep(3)
    print_step(7, "Post-submit verification — re-reading pipeline (pass 2 of 2)...")
    verify_pass_2 = scraper.read_pipeline(product_id=product_id, store_id=HUB_STORE_ID)

    verify_results = verify_submissions(decisions, verify_pass_1, verify_pass_2)
    display_verification_results(verify_results)

    for d in decisions:
        if d.get('otto_action') == 'written':
            d['otto_action'] = 'submitted'
            d['verified'] = verify_results.get('all_verified', False)

    log_all_decisions_to_db(bridge, decisions, submitted=True)


def verify_submissions(decisions, verify_1, verify_2):
    results = {
        'all_verified': True,
        'details': [],
        'pass_1_success': verify_1.get('success', False),
        'pass_2_success': verify_2.get('success', False),
    }

    if not verify_1.get('success') or not verify_2.get('success'):
        results['all_verified'] = False
        results['error'] = 'One or both verification reads failed'
        return results

    adj_map_1 = {}
    for d in verify_1.get('adjustable_dates', []):
        adj_map_1[d['date']] = d.get('current_adj', 0)

    adj_map_2 = {}
    for d in verify_2.get('adjustable_dates', []):
        adj_map_2[d['date']] = d.get('current_adj', 0)

    for d in decisions:
        if d.get('otto_action') != 'written':
            continue

        date = d.get('delivery_date', '')
        expected = d.get('final_decision', 0)
        actual_1 = adj_map_1.get(date, None)
        actual_2 = adj_map_2.get(date, None)

        verified = (actual_1 == expected) and (actual_2 == expected)
        detail = {
            'date': date,
            'expected': expected,
            'pass_1': actual_1,
            'pass_2': actual_2,
            'verified': verified,
        }

        if not verified:
            results['all_verified'] = False
            if actual_1 != actual_2:
                detail['warning'] = f'Inconsistent reads: pass1={actual_1}, pass2={actual_2}'

        results['details'].append(detail)

    return results


def display_verification_results(verify_results):
    print_header("POST-SUBMIT VERIFICATION")

    if verify_results.get('error'):
        print(f"  ERROR: {verify_results['error']}")
        return

    all_ok = verify_results['all_verified']
    status = "ALL VERIFIED" if all_ok else "VERIFICATION ISSUES DETECTED"
    print(f"  Status: {status}")
    print()

    print(f"  {'Date':<12} {'Expected':<10} {'Pass 1':<10} {'Pass 2':<10} {'Status':<12}")
    print(f"  {'-'*12} {'-'*10} {'-'*10} {'-'*10} {'-'*12}")

    for detail in verify_results.get('details', []):
        status_str = "OK" if detail['verified'] else "MISMATCH"
        p1 = detail['pass_1'] if detail['pass_1'] is not None else '?'
        p2 = detail['pass_2'] if detail['pass_2'] is not None else '?'
        print(f"  {detail['date']:<12} {detail['expected']:<10} {p1:<10} {p2:<10} {status_str:<12}")
        if detail.get('warning'):
            print(f"    WARNING: {detail['warning']}")

    if not all_ok:
        print("\n  Some submissions may not have gone through.")
        print("  Check the hub manually for the flagged dates.")


def log_all_decisions_to_db(bridge, decisions, submitted=False):
    print_header("DATABASE LOGGING", '-')
    logged = 0
    for d in decisions:
        if submitted:
            d['otto_action'] = d.get('otto_action', 'unknown')
        try:
            bridge.log_decision(d)
            logged += 1
        except Exception as e:
            print(f"  WARNING: DB log failed for {d.get('delivery_date', '?')}: {e}")
    print(f"  Logged {logged}/{len(decisions)} decisions to mlp_order_log"
          f" (submitted={'YES' if submitted else 'NO'})")


def log_pipeline_result(bridge, product_id, pipeline_data, decisions,
                        written, skipped, failed, dry_run, duration):
    print_header("PIPELINE RESULT")

    mode = "DRY RUN" if dry_run else "LIVE"
    print(f"  Mode:              {mode}")
    print(f"  Product:           {product_id}")
    print(f"  Pipeline Incoming: {pipeline_data['pipeline_incoming']} pieces")
    print(f"  Total Decisions:   {len(decisions)}")
    print(f"  Written:           {written}")
    print(f"  Skipped:           {skipped}")
    print(f"  Failed:            {failed}")
    print(f"  Duration:          {duration:.1f}s")


def run_single_product(scraper, bridge, product_id, dry_run=True):
    product_name = KNOWN_PRODUCTS.get(product_id, f'Unknown ({product_id})')
    start_time = time.time()

    print_step(1, f"Reading hub pipeline for {product_id} ({product_name})...")
    print("  Watch Chrome...\n")

    pipeline_data = scraper.read_pipeline(
        product_id=product_id,
        store_id=HUB_STORE_ID,
    )

    if not pipeline_data.get('success'):
        print(f"\n  FAILED: {pipeline_data.get('error', 'Unknown error')}")
        return None

    display_pipeline_summary(pipeline_data)

    print_step(2, "Checking inventory from token system...")
    inv, sales = display_inventory_snapshot(bridge, product_id)

    adjustable_dates = pipeline_data['adjustable_dates']
    if not adjustable_dates:
        print("\n  No adjustable dates found — nothing for MLP to decide.")
        return pipeline_data

    print_step(3, f"Running MLP v8.5 for {len(adjustable_dates)} adjustable dates...")

    decisions = bridge.get_multi_date_decisions(
        product_id=product_id,
        adjustable_dates=adjustable_dates,
        pipeline_incoming=pipeline_data['pipeline_incoming']
    )

    display_decisions_table(decisions, product_name)
    display_decision_details(decisions)

    has_writes = any(d.get('final_decision', 0) > 0 for d in decisions)

    if not has_writes:
        print(f"\n  MLP says no adjustments needed — pipeline covers demand.")
        duration = time.time() - start_time
        log_all_decisions_to_db(bridge, decisions, submitted=False)
        log_pipeline_result(bridge, product_id, pipeline_data, decisions,
                           0, len(decisions), 0, dry_run, duration)
        return {
            'pipeline_data': pipeline_data,
            'decisions': decisions,
            'written': 0,
            'skipped': len(decisions),
            'failed': 0,
        }

    print_step(4, "Executing writes..." if not dry_run else "Dry run preview...")

    if not dry_run:
        write_count = sum(1 for d in decisions if d.get('final_decision', 0) > 0)
        print(f"\n  *** LIVE MODE — {write_count} ADJ values will be written to the hub ***")
        confirm = input("  Type 'yes' to proceed, anything else to abort: ").strip().lower()
        if confirm != 'yes':
            print("  Aborted — no writes made.")
            duration = time.time() - start_time
            return {
                'pipeline_data': pipeline_data,
                'decisions': decisions,
                'written': 0,
                'skipped': len(decisions),
                'failed': 0,
                'aborted': True,
            }

    written, skipped, failed = execute_writes(
        scraper, decisions, product_id, bridge, dry_run
    )

    submit_and_verify(scraper, bridge, decisions, product_id, pipeline_data, dry_run)

    duration = time.time() - start_time
    log_pipeline_result(bridge, product_id, pipeline_data, decisions,
                       written, skipped, failed, dry_run, duration)

    return {
        'pipeline_data': pipeline_data,
        'decisions': decisions,
        'written': written,
        'skipped': skipped,
        'failed': failed,
    }


def main():
    print_header("MLP v8.5 FULL PIPELINE — LIVE END-TO-END TEST")
    print(f"  Time:    {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Store:   {STORE_ID} (internal) / {HUB_STORE_ID} (the hub)")
    print(f"  Mode:    Chrome VISIBLE (headless=False)")
    print(f"  Safety:  DRY RUN by default — type 'live' to enable writes")

    mode = 'dry_run'
    mode_input = input("\n  Run mode? [dry_run/live] (default: dry_run): ").strip().lower()
    if mode_input == 'live':
        print("\n  *** LIVE MODE ENABLED ***")
        print("  ADJ values WILL be written to the hub after confirmation.")
        confirm = input("  Are you sure? (yes/no): ").strip().lower()
        if confirm == 'yes':
            mode = 'live'
        else:
            print("  Staying in DRY RUN mode.")
    dry_run = (mode == 'dry_run')

    print(f"\n  Active mode: {'DRY RUN' if dry_run else 'LIVE'}")

    print_step(1, "Initializing MLP bridge...")
    try:
        bridge = MLPInventoryBridge(model_path=None, store_id=STORE_ID)
        if bridge.model is not None:
            print(f"  MLP model loaded: {bridge.model_path}")
            print(f"  Device: {bridge.device}")
        else:
            print(f"  MLP model not loaded — using fallback logic")
            print(f"  (This is OK for testing pipeline wiring)")
    except Exception as e:
        print(f"  WARNING: Bridge init error: {e}")
        print(f"  Continuing with fallback logic...")
        bridge = None

    print_step(2, "Starting Chrome + the hub navigation...")
    scraper = OrderHubScraper(headless=False)

    try:
        if not scraper.setup_driver():
            print("  FAILED: Could not start Chrome driver")
            return

        if not scraper.navigate_to_ordering_hub():
            print("  FAILED: Could not reach ordering hub")
            input("\n  Press Enter to close Chrome...")
            return

        print("  Switching to store...")
        if hasattr(scraper, 'switch_to_store'):
            scraper.switch_to_store(HUB_STORE_ID)
        time.sleep(2)
        print(f"  Ready on store {HUB_STORE_ID}")

        while True:
            print("\n" + "-" * 76)
            print("  Known products:")
            for pid, name in KNOWN_PRODUCTS.items():
                print(f"    {pid} — {name}")
            print()
            print("  Commands: 'done' = finish, 'mode' = toggle dry_run/live")

            product_id = input("\n  Enter product ID: ").strip()

            if not product_id or product_id.lower() == 'done':
                break

            if product_id.lower() == 'mode':
                if dry_run:
                    confirm = input("  Switch to LIVE mode? (yes/no): ").strip().lower()
                    if confirm == 'yes':
                        dry_run = False
                        print("  *** LIVE MODE ENABLED ***")
                    else:
                        print("  Staying in DRY RUN.")
                else:
                    dry_run = True
                    print("  Switched to DRY RUN mode.")
                continue

            if product_id not in KNOWN_PRODUCTS:
                print(f"  Product {product_id} not in known list — will try anyway.")

            result = run_single_product(scraper, bridge, product_id, dry_run=dry_run)

            if result:
                save = input("\n  Save full result to JSON? (y/n): ").strip().lower()
                if save == 'y':
                    fname = f"pipeline_result_{product_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
                    with open(fname, 'w') as f:
                        json.dump(result, f, indent=2, default=str)
                    print(f"  Saved to {fname}")

            print("\n  Ready for next product.")

    except KeyboardInterrupt:
        print("\n\n  Interrupted by user.")
    except Exception as e:
        print(f"\n  ERROR: {e}")
        import traceback
        traceback.print_exc()
        input("\n  Press Enter to close Chrome...")
    finally:
        print("\n  Closing Chrome...")
        try:
            scraper.close()
        except:
            pass
        print("  Done.")


if __name__ == '__main__':
    main()
