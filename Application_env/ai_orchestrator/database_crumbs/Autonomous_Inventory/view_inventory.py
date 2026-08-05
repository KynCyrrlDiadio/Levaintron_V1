#!/usr/bin/env python3
"""
View Current Inventory Status
Real-time inventory dashboard
"""

from datetime import datetime
from timezone_utils import now_mst_str, to_mst
from config import get_database


def view_inventory():
    """Display current inventory status"""

    print("=" * 70)
    print("📦 LEVAINTRON DEMO INVENTORY - CURRENT STATUS")
    print("=" * 70)

    db = get_database()
    store_id = '70012004'  # Fictional Market Demo #4

    # Get inventory summary (from tokens if available, otherwise from physical counts)
    summary = db.get_inventory_summary(store_id)

    # If no tokens, try getting physical counts
    if not summary:
        db.cursor.execute('''
            SELECT pc.product_id, p.product_name, pc.quantity_counted as current_stock,
                   pc.count_date as earliest_expiration, pc.count_date as latest_expiration
            FROM physical_counts pc
            JOIN products p ON pc.product_id = p.product_id
            WHERE pc.store_id = %s AND pc.quantity_counted > 0
            ORDER BY p.product_name
        ''', (store_id,))
        summary = [dict(row) for row in db.cursor.fetchall()]

    if not summary:
        print("\n⚠️  No inventory data found.")
        print("Please run: python3 autonomous_inventory/add_physical_count.py")
        db.close()
        return

    print(f"\nAs of: {now_mst_str()}")
    print("\n" + "=" * 70)
    print("CURRENT STOCK LEVELS")
    print("=" * 70)

    total_units = 0
    for item in summary:
        print(f"\n{item['product_name']} ({item['product_id']})")
        print(f"  Stock: {item['current_stock']} units")
        print(f"  Earliest Expiration: {item['earliest_expiration']}")
        print(f"  Latest Expiration: {item['latest_expiration']}")
        total_units += item['current_stock']

    print("\n" + "=" * 70)
    print(f"TOTAL INVENTORY: {total_units} units across {len(summary)} products")
    print("=" * 70)

    # Get expiring products
    print("\n" + "=" * 70)
    print("⚠️  EXPIRING SOON (Next 2 Days)")
    print("=" * 70)

    expiring = db.get_expiring_products(store_id, days_ahead=2)

    if expiring:
        for item in expiring:
            print(f"\n{item['product_id']}: {item['quantity']} units")
            print(f"  Expires: {item['expiration_date']}")
    else:
        print("\n✅ No products expiring in the next 2 days")

    # Transaction history (last 10)
    print("\n" + "=" * 70)
    print("📝 RECENT TRANSACTIONS (Last 10)")
    print("=" * 70)

    db.cursor.execute('''
        SELECT transaction_type, product_id, quantity, transaction_date, notes
        FROM inventory_transactions
        WHERE store_id = %s
        ORDER BY created_at DESC
        LIMIT 10
    ''', (store_id,))

    transactions = db.cursor.fetchall()

    for txn in transactions:
        print(f"\n{txn['transaction_date']} - {txn['transaction_type'].upper()}")
        print(f"  Product: {txn['product_id']}")
        print(f"  Quantity: {txn['quantity']}")
        if txn['notes']:
            print(f"  Notes: {txn['notes']}")

    print("\n" + "=" * 70)

    db.close()


if __name__ == "__main__":
    view_inventory()
