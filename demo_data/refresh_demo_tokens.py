#!/usr/bin/env python3
"""Re-date the demo token batches so the FIFO burn-rate scaler has something
to chew on.

The imported batches carry their original (months-old) arrival dates, so the
runtime FIFO estimator burns all of them to zero and the MLP always sees
stock=0. This script respreads the 5 batches across the last 5 days and marks
them in_stock, giving a live partial-burn state:

    est. sold ≈ 4-5 days of demand, est. remaining ≈ 25-35 pieces

Demo DB only. Re-run anytime; restore the pristine import with
setup_demo_db.sh.
"""
import os
from datetime import date, timedelta

import psycopg2

DB = os.environ.get('DEMO_DATABASE_URL',
                    'postgresql://postgres:8989@127.0.0.1:5432/levaintron_demo')
SHELF_LIFE_DAYS = 12   # matches products.shelf_life_days for 500107

conn = psycopg2.connect(DB)
cur = conn.cursor()

cur.execute("""
    SELECT DISTINCT arrival_date FROM product_tokens
    WHERE product_id = '500107' ORDER BY arrival_date""")
batches = [r[0] for r in cur.fetchall()]

DELIVERY_DOWS = {0, 1, 3, 4}   # Mon, Tue, Thu, Fri — the only days trucks land


def snap_to_delivery_day(d):
    """Walk backward to the nearest valid delivery day (no Sat/Sun/Wed arrivals)."""
    while d.weekday() not in DELIVERY_DOWS:
        d -= timedelta(days=1)
    return d


today = date.today()
for i, old_arrival in enumerate(batches):
    # oldest batch lands (n-1) days ago, newest lands today — then snapped
    # onto the delivery calendar. Batches that snap onto the same day simply
    # merge into one bigger delivery, which is realistic.
    new_arrival = snap_to_delivery_day(today - timedelta(days=len(batches) - 1 - i))
    batch_id = f'OTTO-DELIVERED-{new_arrival}-500107'
    cur.execute("""
        UPDATE product_tokens
        SET arrival_date = %s,
            expiration_date = %s,
            batch_id = %s,
            status = 'in_stock',
            consumed_date = NULL
        WHERE product_id = '500107' AND arrival_date = %s""",
        (new_arrival, new_arrival + timedelta(days=SHELF_LIFE_DAYS),
         batch_id, old_arrival))
    print(f'batch {old_arrival} -> {new_arrival} ({new_arrival:%a}) '
          f'({cur.rowcount} tokens, expires {new_arrival + timedelta(days=SHELF_LIFE_DAYS)})')

conn.commit()
cur.execute("""
    SELECT status, COUNT(*) FROM product_tokens
    WHERE product_id = '500107' GROUP BY status""")
print('token status now:', dict(cur.fetchall()))
conn.close()
