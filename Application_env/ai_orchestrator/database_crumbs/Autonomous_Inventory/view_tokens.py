#!/usr/bin/env python3
"""
Token Explorer - View and track individual product tokens
Interactive CLI tool for familiarizing with the FIFO token system
"""

from config import get_database
from datetime import datetime
import sys


def print_header(title):
    """Print a formatted header"""
    print("\n" + "=" * 70)
    print(title)
    print("=" * 70)


def view_all_tokens(db, limit=50):
    """View all tokens with basic info"""
    
    db.cursor.execute(f'''
        SELECT 
            t.token_id,
            t.product_id,
            p.product_name,
            t.arrival_date,
            t.expiration_date,
            t.status,
            t.consumed_date
        FROM product_tokens t
        LEFT JOIN products p ON t.product_id = p.product_id
        ORDER BY t.expiration_date, t.arrival_date
        LIMIT {limit}
    ''')
    
    tokens = db.cursor.fetchall()
    
    print_header(f"ALL TOKENS (showing first {limit})")
    print(f"\nToken ID                  Product      Arrival     Expiry      Status      Consumed")
    print("-" * 90)
    
    for token in tokens:
        product_name = (token['product_name'][:12] + '...') if token['product_name'] and len(token['product_name']) > 15 else (token['product_name'] or 'Unknown')
        consumed = token['consumed_date'] if token['consumed_date'] else '-'
        
        print(f"{token['token_id'][:25]:<25} {product_name[:15]:<15} {token['arrival_date']} {token['expiration_date']} {token['status']:<11} {consumed}")
    
    print(f"\nShowing {len(tokens)} of {get_total_tokens(db)} total tokens")


def view_tokens_by_product(db, product_id):
    """View all tokens for a specific product"""
    
    # Get product name
    db.cursor.execute('SELECT product_name FROM products WHERE product_id = %s', (product_id,))
    product = db.cursor.fetchone()
    
    if not product:
        print(f"\n❌ Product {product_id} not found in database")
        return
    
    db.cursor.execute('''
        SELECT 
            token_id,
            arrival_date,
            expiration_date,
            status,
            consumed_date,
            batch_id
        FROM product_tokens
        WHERE product_id = %s
        ORDER BY expiration_date, arrival_date
    ''', (product_id,))
    
    tokens = db.cursor.fetchall()
    
    print_header(f"TOKENS FOR: {product['product_name']} ({product_id})")
    
    if not tokens:
        print("\n❌ No tokens found for this product")
        return
    
    # Summary
    db.cursor.execute('''
        SELECT status, COUNT(*) as count
        FROM product_tokens
        WHERE product_id = %s
        GROUP BY status
    ''', (product_id,))
    
    status_counts = db.cursor.fetchall()
    
    print("\nStatus Summary:")
    for row in status_counts:
        print(f"  {row['status']}: {row['count']} tokens")
    
    # Token list
    print(f"\nToken Details:")
    print(f"\nToken ID                  Arrival     Expiry      Status      Consumed    Batch")
    print("-" * 95)
    
    for token in tokens:
        consumed = token['consumed_date'] if token['consumed_date'] else '-'
        batch = (token['batch_id'][:15] + '...') if token['batch_id'] and len(token['batch_id']) > 18 else (token['batch_id'] or '-')
        
        print(f"{token['token_id'][:25]:<25} {token['arrival_date']} {token['expiration_date']} {token['status']:<11} {consumed:<11} {batch}")
    
    print(f"\nTotal: {len(tokens)} tokens")


def view_tokens_by_expiry(db, expiry_date):
    """View all tokens expiring on a specific date"""
    
    db.cursor.execute('''
        SELECT 
            t.token_id,
            t.product_id,
            p.product_name,
            t.arrival_date,
            t.status,
            t.consumed_date
        FROM product_tokens t
        LEFT JOIN products p ON t.product_id = p.product_id
        WHERE t.expiration_date = %s
        ORDER BY t.product_id, t.arrival_date
    ''', (expiry_date,))
    
    tokens = db.cursor.fetchall()
    
    print_header(f"TOKENS EXPIRING ON: {expiry_date}")
    
    if not tokens:
        print(f"\n❌ No tokens found expiring on {expiry_date}")
        return
    
    # Summary by status
    db.cursor.execute('''
        SELECT status, COUNT(*) as count
        FROM product_tokens
        WHERE expiration_date = %s
        GROUP BY status
    ''', (expiry_date,))
    
    status_counts = db.cursor.fetchall()
    
    print("\nStatus Summary:")
    for row in status_counts:
        print(f"  {row['status']}: {row['count']} tokens")
    
    # Token list
    print(f"\nToken Details:")
    print(f"\nProduct      Product Name                Arrival     Status      Consumed")
    print("-" * 80)
    
    for token in tokens:
        product_name = (token['product_name'][:25] + '...') if token['product_name'] and len(token['product_name']) > 28 else (token['product_name'] or 'Unknown')
        consumed = token['consumed_date'] if token['consumed_date'] else '-'
        
        print(f"{token['product_id']:<12} {product_name:<28} {token['arrival_date']} {token['status']:<11} {consumed}")
    
    print(f"\nTotal: {len(tokens)} tokens")


def view_tokens_by_status(db, status):
    """View all tokens with a specific status"""
    
    db.cursor.execute('''
        SELECT 
            t.token_id,
            t.product_id,
            p.product_name,
            t.arrival_date,
            t.expiration_date,
            t.consumed_date
        FROM product_tokens t
        LEFT JOIN products p ON t.product_id = p.product_id
        WHERE t.status = %s
        ORDER BY t.expiration_date, t.arrival_date
    ''', (status,))
    
    tokens = db.cursor.fetchall()
    
    print_header(f"TOKENS WITH STATUS: {status.upper()}")
    
    if not tokens:
        print(f"\n❌ No tokens found with status '{status}'")
        return
    
    print(f"\nProduct      Product Name                Arrival     Expiry      Consumed")
    print("-" * 85)
    
    for token in tokens:
        product_name = (token['product_name'][:25] + '...') if token['product_name'] and len(token['product_name']) > 28 else (token['product_name'] or 'Unknown')
        consumed = token['consumed_date'] if token['consumed_date'] else '-'
        
        print(f"{token['product_id']:<12} {product_name:<28} {token['arrival_date']} {token['expiration_date']} {consumed}")
    
    print(f"\nTotal: {len(tokens)} tokens")


def view_oldest_vs_newest(db, limit=20):
    """Compare oldest vs newest tokens"""
    
    # Oldest tokens
    db.cursor.execute('''
        SELECT 
            t.token_id,
            t.product_id,
            p.product_name,
            t.arrival_date,
            t.expiration_date,
            t.status
        FROM product_tokens t
        LEFT JOIN products p ON t.product_id = p.product_id
        WHERE t.status = 'in_stock'
        ORDER BY t.arrival_date, t.expiration_date
        LIMIT %s
    ''', (limit,))
    
    oldest = db.cursor.fetchall()
    
    # Newest tokens
    db.cursor.execute('''
        SELECT 
            t.token_id,
            t.product_id,
            p.product_name,
            t.arrival_date,
            t.expiration_date,
            t.status
        FROM product_tokens t
        LEFT JOIN products p ON t.product_id = p.product_id
        WHERE t.status = 'in_stock'
        ORDER BY t.arrival_date DESC, t.expiration_date DESC
        LIMIT %s
    ''', (limit,))
    
    newest = db.cursor.fetchall()
    
    print_header(f"OLDEST vs NEWEST TOKENS (In-Stock Only)")
    
    print(f"\n🕰️  OLDEST {limit} TOKENS (First to Expire - FIFO Priority)")
    print("=" * 70)
    print(f"Product      Product Name                Arrival     Expiry")
    print("-" * 70)
    
    for token in oldest:
        product_name = (token['product_name'][:25] + '...') if token['product_name'] and len(token['product_name']) > 28 else (token['product_name'] or 'Unknown')
        print(f"{token['product_id']:<12} {product_name:<28} {token['arrival_date']} {token['expiration_date']}")
    
    print(f"\n🆕 NEWEST {limit} TOKENS (Last to Expire)")
    print("=" * 70)
    print(f"Product      Product Name                Arrival     Expiry")
    print("-" * 70)
    
    for token in newest:
        product_name = (token['product_name'][:25] + '...') if token['product_name'] and len(token['product_name']) > 28 else (token['product_name'] or 'Unknown')
        print(f"{token['product_id']:<12} {product_name:<28} {token['arrival_date']} {token['expiration_date']}")


def view_expiry_summary(db):
    """View summary of tokens by expiration date"""
    
    db.cursor.execute('''
        SELECT 
            expiration_date,
            status,
            COUNT(*) as count
        FROM product_tokens
        GROUP BY expiration_date, status
        ORDER BY expiration_date, status
    ''')
    
    results = db.cursor.fetchall()
    
    print_header("EXPIRATION DATE SUMMARY")
    
    print(f"\nExpiry Date  In-Stock  Returned  Sold  Expired  Total")
    print("-" * 60)
    
    # Group by date
    dates = {}
    for row in results:
        date = row['expiration_date']
        if date not in dates:
            dates[date] = {'in_stock': 0, 'returned': 0, 'sold': 0, 'expired': 0}
        
        dates[date][row['status']] = row['count']
    
    grand_total = 0
    for date in sorted(dates.keys()):
        counts = dates[date]
        total = sum(counts.values())
        grand_total += total
        
        print(f"{date}  {counts['in_stock']:>8}  {counts['returned']:>8}  {counts['sold']:>4}  {counts['expired']:>7}  {total:>5}")
    
    print("-" * 60)
    print(f"{'TOTAL':>12}  {sum(d['in_stock'] for d in dates.values()):>8}  {sum(d['returned'] for d in dates.values()):>8}  {sum(d['sold'] for d in dates.values()):>4}  {sum(d['expired'] for d in dates.values()):>7}  {grand_total:>5}")


def get_total_tokens(db):
    """Get total number of tokens"""
    db.cursor.execute('SELECT COUNT(*) as count FROM product_tokens')
    return db.cursor.fetchone()['count']


def show_menu():
    """Display interactive menu"""
    print("\n" + "=" * 70)
    print("🔍 TOKEN EXPLORER - FIFO Inventory System")
    print("=" * 70)
    print("\nWhat would you like to view?")
    print("\n  [1] All tokens (first 50)")
    print("  [2] Tokens for specific product (by product ID)")
    print("  [3] Tokens expiring on specific date")
    print("  [4] Tokens by status (in_stock, returned, sold, expired)")
    print("  [5] Oldest vs Newest tokens (FIFO comparison)")
    print("  [6] Expiration date summary")
    print("  [q] Quit")
    print("=" * 70)


def main():
    """Main interactive loop"""
    
    db = get_database()
    
    while True:
        show_menu()
        choice = input("\nEnter your choice: ").strip().lower()
        
        if choice == 'q':
            print("\n👋 Exiting Token Explorer\n")
            db.close()
            break
        
        elif choice == '1':
            limit = input("How many tokens to show? [default: 50]: ").strip()
            limit = int(limit) if limit.isdigit() else 50
            view_all_tokens(db, limit)
        
        elif choice == '2':
            product_id = input("Enter product ID: ").strip()
            if product_id:
                view_tokens_by_product(db, product_id)
        
        elif choice == '3':
            expiry = input("Enter expiry date (YYYY-MM-DD): ").strip()
            if expiry:
                view_tokens_by_expiry(db, expiry)
        
        elif choice == '4':
            print("\nAvailable statuses: in_stock, returned, sold, expired")
            status = input("Enter status: ").strip().lower()
            if status:
                view_tokens_by_status(db, status)
        
        elif choice == '5':
            limit = input("How many tokens per group? [default: 20]: ").strip()
            limit = int(limit) if limit.isdigit() else 20
            view_oldest_vs_newest(db, limit)
        
        elif choice == '6':
            view_expiry_summary(db)
        
        else:
            print("\n❌ Invalid choice. Please try again.")
        
        input("\nPress Enter to continue...")


if __name__ == '__main__':
    main()
