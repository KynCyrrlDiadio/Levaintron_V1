#!/usr/bin/env python3
"""
Levaintron Demo Pipeline Daemon

Long-running process that stays alive and triggers the MLP pipeline
at scheduled times each day. Supports multiple daily runs.

Usage:
    python3 -m tests.pipeline_daemon
    python3 -m tests.pipeline_daemon --schedule 3:00,11:30
    python3 -m tests.pipeline_daemon --run-hour 3 --run-minute 0   # legacy single-time
    python3 -m tests.pipeline_daemon --run-now  # immediate test run then schedule

Environment:
    PIPELINE_SCHEDULE=3:00,11:30      (comma-separated HH:MM times)
    PIPELINE_RUN_HOUR=3               (legacy fallback if PIPELINE_SCHEDULE not set)
    PIPELINE_RUN_MINUTE=0             (legacy fallback)
    PIPELINE_MODE=live                (default: live)
    PIPELINE_PRODUCTS=500107
    PIPELINE_PRODUCT=500107           (legacy fallback, single product)
"""

import sys
import os
import time
import random
import signal
import argparse
import logging
import threading
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, '.')

PIPELINE_MARKER_PATH = os.environ.get('GRID_MONITOR_MARKER', '/tmp/levaintron_demo_pipeline_complete')

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('levaintron-demo-daemon')

shutdown_event = threading.Event()


def signal_handler(signum, frame):
    sig_name = signal.Signals(signum).name
    logger.info(f"Received {sig_name} — shutting down gracefully...")
    shutdown_event.set()


signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)


def run_pipeline(mode='live', products=None, write_marker=True):
    if products is None:
        products = ['500107']

    try:
        from tests.run_pipeline_autonomous import run_autonomous_pipeline
        logger.info(f"{'='*60}")
        logger.info(f"PIPELINE RUN STARTING — mode={mode}, products={products}")
        logger.info(f"{'='*60}")

        try:
            result = run_autonomous_pipeline(mode=mode, products=products)
            if result.get('success'):
                logger.info(f"Pipeline run completed successfully")
                if write_marker:
                    # Signal grid monitor daemon to capture post-pipeline baseline
                    run_id = result.get('run_id', datetime.now().strftime('%Y%m%d-%H%M'))
                    Path(PIPELINE_MARKER_PATH).write_text(run_id)
                    logger.info(f"Pipeline marker written → {PIPELINE_MARKER_PATH}")
                else:
                    logger.info(f"Skipping pipeline marker (baseline not needed for this slot)")
            else:
                logger.error(f"Pipeline run failed: {result.get('error', 'unknown')}")
        except Exception as e:
            logger.error(f"Pipeline run failed: {e}", exc_info=True)

    except Exception as e:
        logger.error(f"Failed to import/run pipeline: {e}", exc_info=True)


def parse_schedule(schedule_str):
    """Parse comma-separated HH:MM times into list of (hour, minute) tuples."""
    slots = []
    for part in schedule_str.split(','):
        part = part.strip()
        if ':' in part:
            h, m = part.split(':', 1)
            slots.append((int(h), int(m)))
        else:
            slots.append((int(part), 0))
    return sorted(slots)


def next_schedule_slot(schedule):
    """Find the next upcoming schedule slot. Returns (seconds_until, target_datetime, slot_index)."""
    now = datetime.now()
    best = None
    for i, (hour, minute) in enumerate(schedule):
        target = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
        if target <= now:
            target += timedelta(days=1)
        secs = (target - now).total_seconds()
        if best is None or secs < best[0]:
            best = (secs, target, i)
    return best


def main():
    parser = argparse.ArgumentParser(description='Levaintron Demo Pipeline Daemon')
    parser.add_argument('--schedule', type=str,
                        default=os.environ.get('PIPELINE_SCHEDULE', ''),
                        help='Comma-separated run times in HH:MM format (e.g., 3:00,11:30)')
    parser.add_argument('--run-hour', type=int,
                        default=int(os.environ.get('PIPELINE_RUN_HOUR', '3')))
    parser.add_argument('--run-minute', type=int,
                        default=int(os.environ.get('PIPELINE_RUN_MINUTE', '0')))
    parser.add_argument('--mode',
                        default=os.environ.get('PIPELINE_MODE', 'live'))
    products_env = os.environ.get('PIPELINE_PRODUCTS', '')
    if not products_env:
        products_env = os.environ.get('PIPELINE_PRODUCT', '500107')
    default_products = [p.strip() for p in products_env.split(',') if p.strip()]

    parser.add_argument('--products', nargs='+',
                        default=default_products,
                        help='Product IDs to process (default: from PIPELINE_PRODUCTS env)')
    parser.add_argument('--run-now', action='store_true',
                        help='Run pipeline immediately on startup, then schedule')
    parser.add_argument('--no-baseline', action='store_true',
                        help='Skip pipeline marker on --run-now (no BaselineBot baseline trigger)')
    parser.add_argument('--jitter', type=int,
                        default=int(os.environ.get('PIPELINE_JITTER_SEC', '600')),
                        help='Max random delay (sec) added after each scheduled slot fires, so '
                             'runs do not hit the hub at the exact same second daily. Kept modest '
                             '(default 600=10min) to stay within the slot hour. 0 disables.')
    args = parser.parse_args()

    # Build schedule: prefer --schedule/PIPELINE_SCHEDULE, fall back to legacy single time
    if args.schedule:
        schedule = parse_schedule(args.schedule)
    else:
        schedule = [(args.run_hour, args.run_minute)]

    schedule_str = ', '.join(f"{h:02d}:{m:02d}" for h, m in schedule)

    logger.info(f"{'='*60}")
    logger.info(f"Levaintron Demo Pipeline Daemon Starting")
    logger.info(f"  Schedule: daily at {schedule_str}")
    logger.info(f"  Mode: {args.mode}")
    logger.info(f"  Products: {args.products}")
    logger.info(f"  PID: {os.getpid()}")
    logger.info(f"{'='*60}")

    if args.run_now:
        write_marker = not args.no_baseline
        logger.info(f"--run-now flag set, executing immediate pipeline run..."
                     f"{' [no baseline]' if not write_marker else ' [baseline]'}")
        run_pipeline(mode=args.mode, products=args.products, write_marker=write_marker)

    # Track which (date, slot_index) combos have already run today
    completed_slots = set()

    while not shutdown_event.is_set():
        now = datetime.now()
        today = now.date()

        # Clear yesterday's completed slots
        completed_slots = {(d, i) for d, i in completed_slots if d == today}

        # Find next slot that hasn't run yet today
        best = None
        for i, (hour, minute) in enumerate(schedule):
            if (today, i) in completed_slots:
                continue
            target = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
            if target <= now:
                # Check if we're within the trigger window (same hour, minute passed)
                if now.hour == hour and now.minute >= minute:
                    # This slot is due NOW
                    secs = 0
                    if best is None or secs < best[0]:
                        best = (secs, target, i)
                    continue
                # Slot already passed today and wasn't caught — skip to tomorrow
                target += timedelta(days=1)
            secs = (target - now).total_seconds()
            if best is None or secs < best[0]:
                best = (secs, target, i)

        if best is None:
            # All slots completed for today, sleep until first slot tomorrow
            wait_secs, next_target, _ = next_schedule_slot(schedule)
            logger.info(f"All runs complete for today. Next: {next_target.strftime('%Y-%m-%d %H:%M:%S')} "
                         f"({wait_secs/3600:.1f}h)")
            if shutdown_event.wait(timeout=min(wait_secs, 60)):
                break
            continue

        wait_secs, target, slot_idx = best
        slot_hour, slot_minute = schedule[slot_idx]

        if wait_secs > 0:
            logger.info(f"Next pipeline run: {target.strftime('%Y-%m-%d %H:%M:%S')} "
                         f"[{slot_hour:02d}:{slot_minute:02d} slot] ({wait_secs/3600:.1f}h from now)")
            if shutdown_event.wait(timeout=min(wait_secs, 60)):
                break
            continue

        # Slot is due. Add human-like timing entropy: a random delay before the
        # run so we don't hammer the hub at the exact same second every day (a cheap
        # behavioural signal). Identity (UA/profile) stays fixed — only timing
        # varies. Interruptible by shutdown. We mark the slot complete right after,
        # so the jitter never causes a slot to be skipped even if it crosses :00.
        if args.jitter > 0:
            jitter = random.randint(0, args.jitter)
            logger.info(f"Jitter: waiting {jitter}s before this run (max {args.jitter}s).")
            if shutdown_event.wait(timeout=jitter):
                break

        # Only the first schedule slot (3AM) triggers BaselineBot baseline capture
        is_baseline_slot = (slot_idx == 0)
        logger.info(f"Scheduled time reached [{slot_hour:02d}:{slot_minute:02d}] — "
                     f"triggering pipeline run ({now.strftime('%A')})"
                     f"{' [baseline]' if is_baseline_slot else ' [no baseline]'}")
        run_pipeline(mode=args.mode, products=args.products, write_marker=is_baseline_slot)
        completed_slots.add((today, slot_idx))

    logger.info("Daemon shutdown complete.")


if __name__ == '__main__':
    main()
