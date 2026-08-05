#!/usr/bin/env python3
"""Rebuild product_tokens for 500107 to exactly mirror the mock hub's
delivered F.O. history at store 70012004 — what the pipeline's daily token
sync would have accumulated had it been running on every delivery day.

Deliveries older than the shelf life are skipped entirely (those pieces are
already off the shelf; creating them would also drag the FIFO burn window
back and zero the estimate).

Demo DB only. Re-run anytime.
"""
import os
from datetime import date, timedelta
from uuid import uuid4

import psycopg2

DB = os.environ.get('DEMO_DATABASE_URL',
                    'postgresql://postgres:8989@127.0.0.1:5432/levaintron_demo')
PRODUCT = '500107'
STORE = '70012004'
SHELF_LIFE_DAYS = 12

# Delivered F.O. per date, read off the hub grid (weeks 28-31, store 70012004).
HUB_DELIVERED = {
    '2026-07-07': 6, '2026-07-09': 5, '2026-07-11': 9,
    '2026-07-13': 8, '2026-07-17': 3, '2026-07-18': 7,
    '2026-07-20': 2, '2026-07-24': 3,
    '2026-07-28': 13, '2026-07-30': 5, '2026-07-31': 1, '2026-08-01': 8,
}

conn = psycopg2.connect(DB)
cur = conn.cursor()

cur.execute("DELETE FROM product_tokens WHERE product_id = %s", (PRODUCT,))
print(f'cleared {cur.rowcount} existing tokens for {PRODUCT}')

today = date.today()
created = skipped = 0
for date_str in sorted(HUB_DELIVERED):
    qty = HUB_DELIVERED[date_str]
    arrival = date.fromisoformat(date_str)
    expiration = arrival + timedelta(days=SHELF_LIFE_DAYS)
    if expiration < today:
        print(f'  {date_str} ({arrival:%a}) x{qty:>2}  — expired {expiration}, skipped')
        skipped += qty
        continue
    batch_id = f'OTTO-DELIVERED-{date_str}-{PRODUCT}'
    for _ in range(qty):
        cur.execute("""
            INSERT INTO product_tokens
                (token_id, product_id, product_name, store_id, arrival_date,
                 expiration_date, status, status_date, batch_id)
            VALUES (%s, %s, 'Demo_500g_Rye_Bread', %s, %s, %s, 'in_stock', %s, %s)""",
            (str(uuid4()), PRODUCT, STORE, arrival, expiration, arrival, batch_id))
    print(f'  {date_str} ({arrival:%a}) x{qty:>2}  -> in_stock, expires {expiration}')
    created += qty

conn.commit()
print(f'done: {created} tokens created, {skipped} pieces skipped as already-expired')
conn.close()
