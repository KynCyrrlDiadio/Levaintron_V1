#!/usr/bin/env python3
"""
Token Generator Tool - Manually populate token tables

Opposite of nuclear_reset.py — creates records in:
  - product_tokens      (FIFO inventory tokens, one row per unit)
  - returns_invoices    (return invoice header records)
  - token_sales_log     (sales / shelf-life expiry log entries)
  - token_returns_log   (return transaction log entries)

mlp_order_log is intentionally excluded — the MLP populates that.

Usage:
  python3 token_generator_tool.py
"""

import sys
import os
import uuid
from datetime import datetime, timedelta, date

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from config import get_database, STORE_ID, STORE_NAME, USE_POSTGRESQL


# ──────────────────────────────────────────────
# Known products (quick-select shortcuts)
# ──────────────────────────────────────────────
KNOWN_PRODUCTS = {
    '1': ('500107', 'Demo_500g_Rye_Bread', 12),
}

STORE = '70012004'
DEFAULT_SHELF_LIFE = 12


# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────
def W(n=70): return '=' * n
def w(n=70): return '-' * n


def get_count(db, table: str) -> int:
    try:
        db.cursor.execute(f'SELECT COUNT(*) AS c FROM {table}')
        row = db.cursor.fetchone()
        return row['c'] if row else 0
    except Exception:
        db.conn.rollback()
        return 0


def ask(prompt: str, default: str = '') -> str:
    """Prompt with optional default. Returns stripped string."""
    suffix = f' [{default}]' if default else ''
    raw = input(f'  {prompt}{suffix}: ').strip()
    return raw if raw else default


def ask_int(prompt: str, default: int) -> int:
    while True:
        raw = ask(prompt, str(default))
        try:
            val = int(raw)
            if val > 0:
                return val
            print('  ⚠️  Must be a positive integer.')
        except ValueError:
            print('  ⚠️  Numbers only.')


def ask_date(prompt: str, default: str = '') -> str:
    """Ask for a YYYY-MM-DD date. Returns validated string."""
    default = default or datetime.now().strftime('%Y-%m-%d')
    while True:
        raw = ask(prompt, default)
        try:
            datetime.strptime(raw, '%Y-%m-%d')
            return raw
        except ValueError:
            print('  ⚠️  Use format YYYY-MM-DD')


def pick_product() -> tuple[str, str, int]:
    """Returns (product_id, product_name, shelf_life_days)."""
    print()
    print('  Select product:')
    for k, (pid, name, shelf) in KNOWN_PRODUCTS.items():
        print(f'    [{k}]  {pid}  {name}  (shelf {shelf}d)')
    print('    [C]  Custom product ID')
    while True:
        choice = input('  Enter choice: ').strip().upper()
        if choice in KNOWN_PRODUCTS:
            return KNOWN_PRODUCTS[choice]
        if choice == 'C':
            pid   = ask('Product ID')
            pname = ask('Product name', 'Unknown')
            shelf = ask_int('Shelf life (days)', DEFAULT_SHELF_LIFE)
            return pid, pname, shelf
        print('  ⚠️  Invalid choice.')


def print_header():
    print()
    print(W())
    print('🌾  CRUMBS TOKEN GENERATOR TOOL')
    print(f'    Store : {STORE_NAME} (ID {STORE_ID})')
    print(f'    DB    : {"PostgreSQL" if USE_POSTGRESQL else "SQLite"}')
    print(f'    Time  : {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    print(W())


def show_counts(db):
    tables = ['product_tokens', 'returns_invoices', 'token_sales_log', 'token_returns_log']
    print()
    print('📊 CURRENT COUNTS:')
    print(w())
    for t in tables:
        print(f'  {t:<30}  {get_count(db, t):>6} records')
    print(w())


# ──────────────────────────────────────────────
# Option 1 — Add product tokens (delivery)
# ──────────────────────────────────────────────
def add_product_tokens(db):
    print()
    print(W())
    print('  [1] ADD PRODUCT TOKENS  (one token = one unit on shelf)')
    print(W())

    product_id, product_name, shelf_life = pick_product()

    arrival_str  = ask_date('Arrival date (YYYY-MM-DD)')
    quantity     = ask_int('Quantity (number of units)', 1)

    expiry_date  = (datetime.strptime(arrival_str, '%Y-%m-%d') + timedelta(days=shelf_life)).strftime('%Y-%m-%d')
    default_batch = f'OTTO-DELIVERED-{product_id}-{arrival_str}'
    batch_id     = ask('Batch ID', default_batch)
    notes        = ask('Notes (optional)', '')
    today_str    = datetime.now().strftime('%Y-%m-%d')

    print()
    print(w())
    print(f'  About to INSERT {quantity} token(s):')
    print(f'    Product   : {product_id}  {product_name}')
    print(f'    Arrival   : {arrival_str}')
    print(f'    Expiry    : {expiry_date}  ({shelf_life}d shelf life)')
    print(f'    Batch     : {batch_id}')
    print(f'    Status    : in_stock')
    print(w())

    confirm = input("  Type 'YES' to insert (anything else cancels): ").strip().upper()
    if confirm != 'YES':
        print('  ❌ Cancelled.')
        return

    db.conn.rollback()
    inserted = 0
    for _ in range(quantity):
        token_id = str(uuid.uuid4())
        db.cursor.execute('''
            INSERT INTO product_tokens
            (token_id, product_id, product_name, store_id,
             arrival_date, expiration_date, status, status_date,
             consumed_date, batch_id, notes)
            VALUES (%s, %s, %s, %s, %s, %s, 'in_stock', %s, NULL, %s, %s)
        ''', (token_id, product_id, product_name, STORE,
              arrival_str, expiry_date, today_str, batch_id, notes or None))
        inserted += 1

    db.conn.commit()
    print(f'\n  ✅ Inserted {inserted} token(s) → product_tokens')
    print(f'  Total {product_id} tokens now: {get_count(db, "product_tokens")} (all products)')


# ──────────────────────────────────────────────
# Option 2 — Add return invoice
# ──────────────────────────────────────────────
def add_return_invoice(db):
    print()
    print(W())
    print('  [2] ADD RETURN INVOICE')
    print(W())

    product_id, product_name, _ = pick_product()

    today_str    = datetime.now().strftime('%Y-%m-%d')
    invoice_date = ask_date('Invoice date', today_str)
    invoice_id   = ask('Invoice ID', f'INV-{product_id}-{invoice_date}')
    units        = ask_int('Units returned', 1)
    reason       = ask('Reason (optional)', '')

    # Check duplicate
    try:
        db.cursor.execute('SELECT id FROM returns_invoices WHERE invoice_id = %s', (invoice_id,))
        if db.cursor.fetchone():
            print(f'\n  ⚠️  Invoice {invoice_id} already exists. Choose a different invoice ID.')
            return
    except Exception:
        db.conn.rollback()

    print()
    print(w())
    print(f'  About to INSERT return invoice:')
    print(f'    Invoice   : {invoice_id}')
    print(f'    Product   : {product_id}  {product_name}')
    print(f'    Date      : {invoice_date}')
    print(f'    Units     : {units}')
    print(f'    Reason    : {reason or "(none)"}')
    print(w())

    confirm = input("  Type 'YES' to insert (anything else cancels): ").strip().upper()
    if confirm != 'YES':
        print('  ❌ Cancelled.')
        return

    db.conn.rollback()
    db.cursor.execute('''
        INSERT INTO returns_invoices
        (invoice_id, store_id, invoice_date, product_id, units_returned, reason, tokens_updated)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    ''', (invoice_id, STORE, invoice_date, product_id, units, reason or None, 0))
    db.conn.commit()
    print(f'\n  ✅ Inserted 1 row → returns_invoices')


# ──────────────────────────────────────────────
# Option 3 — Add sales log entry
# ──────────────────────────────────────────────
def add_sales_log(db):
    print()
    print(W())
    print('  [3] ADD TOKEN SALES LOG ENTRY')
    print(W())

    product_id, _, _ = pick_product()
    today_str  = datetime.now().strftime('%Y-%m-%d')
    sale_date  = ask_date('Sale date', today_str)
    units      = ask_int('Units sold', 1)
    batch_id   = ask('Batch ID (optional)', '')
    arrival    = ask_date('Arrival date (optional, Enter to skip)', '') if ask('Include arrival/expiry dates? [y/N]', 'N').upper() == 'Y' else ''
    expiry     = ''
    dos        = None
    if arrival:
        expiry = ask_date('Expiry date', '')
        try:
            dos = (datetime.strptime(sale_date, '%Y-%m-%d') - datetime.strptime(arrival, '%Y-%m-%d')).days
        except Exception:
            dos = None
    source = ask('Source', 'manual')

    print()
    print(w())
    print(f'  About to INSERT sales log:')
    print(f'    Product   : {product_id}')
    print(f'    Sale date : {sale_date}')
    print(f'    Units     : {units}')
    print(f'    Batch     : {batch_id or "(none)"}')
    print(f'    Source    : {source}')
    print(w())

    confirm = input("  Type 'YES' to insert: ").strip().upper()
    if confirm != 'YES':
        print('  ❌ Cancelled.')
        return

    db.conn.rollback()
    db.cursor.execute('''
        INSERT INTO token_sales_log
        (product_id, store_id, sale_date, units_sold, batch_id,
         arrival_date, expiration_date, days_on_shelf, source)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    ''', (product_id, STORE, sale_date, units,
          batch_id or None,
          arrival or None, expiry or None, dos, source))
    db.conn.commit()
    print(f'\n  ✅ Inserted 1 row → token_sales_log')


# ──────────────────────────────────────────────
# Option 4 — Add return transaction log
# ──────────────────────────────────────────────
def add_return_log(db):
    print()
    print(W())
    print('  [4] ADD TOKEN RETURNS LOG ENTRY')
    print(W())

    product_id, _, _ = pick_product()
    today_str   = datetime.now().strftime('%Y-%m-%d')
    return_date = ask_date('Return date', today_str)
    units       = ask_int('Units returned', 1)
    invoice_id  = ask('Invoice ID (optional)', '')
    batch_id    = ask('Batch ID (optional)', '')
    arrival     = ''
    expiry      = ''
    dos         = None
    if ask('Include arrival/expiry dates? [y/N]', 'N').upper() == 'Y':
        arrival = ask_date('Arrival date', '')
        expiry  = ask_date('Expiry date', '')
        try:
            dos = (datetime.strptime(return_date, '%Y-%m-%d') - datetime.strptime(arrival, '%Y-%m-%d')).days
        except Exception:
            dos = None
    reason = ask('Reason (optional)', '')

    print()
    print(w())
    print(f'  About to INSERT return log:')
    print(f'    Product     : {product_id}')
    print(f'    Return date : {return_date}')
    print(f'    Units       : {units}')
    print(f'    Invoice     : {invoice_id or "(none)"}')
    print(f'    Batch       : {batch_id or "(none)"}')
    print(w())

    confirm = input("  Type 'YES' to insert: ").strip().upper()
    if confirm != 'YES':
        print('  ❌ Cancelled.')
        return

    db.conn.rollback()
    db.cursor.execute('''
        INSERT INTO token_returns_log
        (product_id, store_id, return_date, units_returned, invoice_id,
         batch_id, arrival_date, expiration_date, days_on_shelf, reason)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    ''', (product_id, STORE, return_date, units,
          invoice_id or None, batch_id or None,
          arrival or None, expiry or None, dos, reason or None))
    db.conn.commit()
    print(f'\n  ✅ Inserted 1 row → token_returns_log')


# ──────────────────────────────────────────────
# Main menu
# ──────────────────────────────────────────────
def main_menu(db):
    while True:
        show_counts(db)
        print()
        print(W())
        print('  TOKEN GENERATOR — SELECT ACTION')
        print(w())
        print('  [1]  Add product tokens      (delivery units → product_tokens)')
        print('  [2]  Add return invoice       (invoice header → returns_invoices)')
        print('  [3]  Add sales log entry      (manual sale → token_sales_log)')
        print('  [4]  Add return log entry     (manual return → token_returns_log)')
        print('  [R]  Refresh counts')
        print('  [Q]  Quit')
        print(W())

        choice = input('  Enter choice [1-4 / R / Q]: ').strip().upper()

        if choice == '1':
            add_product_tokens(db)
        elif choice == '2':
            add_return_invoice(db)
        elif choice == '3':
            add_sales_log(db)
        elif choice == '4':
            add_return_log(db)
        elif choice == 'R':
            pass
        elif choice == 'Q':
            print('\n👋 Exiting token generator. Nothing else was changed.')
            break
        else:
            print('  ⚠️  Unrecognized input.')


def main():
    db = get_database()
    print_header()
    main_menu(db)
    db.close()


if __name__ == '__main__':
    main()
