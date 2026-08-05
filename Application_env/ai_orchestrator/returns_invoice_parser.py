#!/usr/bin/env python3
"""
Returns Invoice Parser - Tue/Fri Returns Processing for FIFO Token System

Parses returns invoices (uploaded on Tuesday and Friday) and updates the
product_tokens table using FIFO logic: oldest in_stock tokens get marked
as 'returned' first.

Also calculates rolling 14-day return rate for use as MLP v8.5 input feature.

Usage:
    parser = ReturnsInvoiceParser()
    result = parser.process_returns(product_id='500107', units_returned=3, invoice_id='INV-2026-0221')
    rate = parser.get_return_rate(product_id='500107')
"""

import os
import sys
import csv
import json
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any

sys.path.insert(0, str(Path(__file__).parent))

from database_crumbs.Autonomous_Inventory.config import get_database

VALID_RETURN_DAYS = [1, 4]  # Tuesday=1, Friday=4


class ReturnsInvoiceParser:

    def __init__(self, store_id: str = '70012004', enforce_return_days: bool = True):
        self.store_id = store_id
        self.enforce_return_days = enforce_return_days

    def _is_valid_return_day(self) -> bool:
        return datetime.now().weekday() in VALID_RETURN_DAYS

    def _ensure_tables(self, db):
        db.cursor.execute('''
            CREATE TABLE IF NOT EXISTS product_tokens (
                token_id TEXT PRIMARY KEY,
                product_id TEXT NOT NULL,
                product_name TEXT,
                store_id TEXT NOT NULL DEFAULT '70012004',
                arrival_date DATE NOT NULL,
                expiration_date DATE NOT NULL,
                status TEXT NOT NULL DEFAULT 'in_stock',
                status_date DATE NOT NULL,
                consumed_date DATE,
                batch_id TEXT,
                notes TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT check_status CHECK (status IN ('in_stock', 'sold', 'expired', 'returned'))
            )
        ''')
        db.cursor.execute('''
            CREATE TABLE IF NOT EXISTS returns_invoices (
                id SERIAL PRIMARY KEY,
                invoice_id VARCHAR(50) NOT NULL UNIQUE,
                store_id VARCHAR(20) NOT NULL DEFAULT '70012004',
                invoice_date DATE NOT NULL,
                product_id VARCHAR(20) NOT NULL,
                units_returned INTEGER NOT NULL,
                reason TEXT,
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                tokens_updated INTEGER DEFAULT 0
            )
        ''')
        db.cursor.execute('''
            CREATE TABLE IF NOT EXISTS token_sales_log (
                id SERIAL PRIMARY KEY,
                product_id VARCHAR(20) NOT NULL,
                store_id VARCHAR(20) NOT NULL DEFAULT '70012004',
                sale_date DATE NOT NULL,
                units_sold INTEGER NOT NULL,
                batch_id VARCHAR(50),
                arrival_date DATE,
                expiration_date DATE,
                days_on_shelf INTEGER,
                source VARCHAR(20) NOT NULL DEFAULT 'shelf_life',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        db.cursor.execute('''
            CREATE TABLE IF NOT EXISTS token_returns_log (
                id SERIAL PRIMARY KEY,
                product_id VARCHAR(20) NOT NULL,
                store_id VARCHAR(20) NOT NULL DEFAULT '70012004',
                return_date DATE NOT NULL,
                units_returned INTEGER NOT NULL,
                invoice_id VARCHAR(50),
                batch_id VARCHAR(50),
                arrival_date DATE,
                expiration_date DATE,
                days_on_shelf INTEGER,
                reason TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        db.conn.commit()

    def process_returns(self, product_id: str, units_returned: int,
                       invoice_id: str, reason: str = None,
                       invoice_date: str = None,
                       force_day: bool = False) -> Dict:
        if self.enforce_return_days and not force_day and not self._is_valid_return_day():
            day_name = datetime.now().strftime('%A')
            return {
                'success': False,
                'error': f'Returns only processed on Tuesday and Friday. Today is {day_name}.',
                'product_id': product_id
            }

        if units_returned <= 0:
            return {
                'success': False,
                'error': 'units_returned must be positive',
                'product_id': product_id
            }

        try:
            db = get_database()
            self._ensure_tables(db)

            db.cursor.execute(
                'SELECT id FROM returns_invoices WHERE invoice_id = %s',
                (invoice_id,)
            )
            if db.cursor.fetchone():
                db.close()
                return {
                    'success': False,
                    'error': f'Invoice {invoice_id} already processed',
                    'product_id': product_id
                }

            inv_date = invoice_date or datetime.now().strftime('%Y-%m-%d')

            db.cursor.execute('''
                SELECT token_id, batch_id, arrival_date, expiration_date
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s AND status = 'in_stock'
                ORDER BY arrival_date ASC
                LIMIT %s
            ''', (product_id, self.store_id, units_returned))

            oldest_tokens = db.cursor.fetchall()
            tokens_found = len(oldest_tokens)

            if tokens_found == 0:
                db.close()
                return {
                    'success': False,
                    'error': f'No in_stock tokens found for product {product_id}',
                    'product_id': product_id,
                    'units_requested': units_returned
                }

            now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            tokens_updated = 0
            for token in oldest_tokens:
                db.cursor.execute('''
                    UPDATE product_tokens
                    SET status = 'returned',
                        consumed_date = %s,
                        status_date = %s,
                        updated_at = %s,
                        notes = %s
                    WHERE token_id = %s AND status = 'in_stock'
                ''', (inv_date, inv_date, now, f'Return invoice: {invoice_id}', token['token_id']))
                tokens_updated += db.cursor.rowcount

            return_batches = {}
            for token in oldest_tokens:
                key = (token['batch_id'], str(token['arrival_date']), str(token['expiration_date']))
                if key not in return_batches:
                    return_batches[key] = {
                        'batch_id': token['batch_id'],
                        'arrival_date': token['arrival_date'],
                        'expiration_date': token['expiration_date'],
                        'count': 0
                    }
                return_batches[key]['count'] += 1

            for batch in return_batches.values():
                days_on_shelf = (datetime.strptime(inv_date, '%Y-%m-%d').date() - batch['arrival_date']).days if batch['arrival_date'] else None
                db.cursor.execute('''
                    INSERT INTO token_returns_log
                    (product_id, store_id, return_date, units_returned, invoice_id,
                     batch_id, arrival_date, expiration_date, days_on_shelf, reason)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ''', (product_id, self.store_id, inv_date, batch['count'],
                      invoice_id, batch['batch_id'],
                      batch['arrival_date'], batch['expiration_date'],
                      days_on_shelf, reason))

            db.cursor.execute('''
                INSERT INTO returns_invoices
                (invoice_id, store_id, invoice_date, product_id, units_returned, reason, tokens_updated)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            ''', (invoice_id, self.store_id, inv_date, product_id, units_returned, reason, tokens_updated))

            db.conn.commit()

            return_rate = self._calculate_return_rate(product_id, db)

            db.close()
            return {
                'success': True,
                'product_id': product_id,
                'invoice_id': invoice_id,
                'units_requested': units_returned,
                'tokens_updated': tokens_updated,
                'tokens_available': tokens_found,
                'shortfall': max(0, units_returned - tokens_found),
                'return_rate_14d': round(return_rate, 2),
                'message': f'Processed {tokens_updated} returns for product {product_id} (FIFO oldest-first)'
            }

        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'product_id': product_id
            }

    def _calculate_return_rate(self, product_id: str, db) -> float:
        fourteen_days_ago = (datetime.now() - timedelta(days=14)).strftime('%Y-%m-%d')

        db.cursor.execute('''
            SELECT COALESCE(SUM(units_returned), 0) as total_returned
            FROM returns_invoices
            WHERE product_id = %s AND store_id = %s AND invoice_date >= %s
        ''', (product_id, self.store_id, fourteen_days_ago))
        result = db.cursor.fetchone()
        total_returned = result['total_returned'] if result else 0

        db.cursor.execute('''
            SELECT COUNT(*) as total_delivered
            FROM product_tokens
            WHERE product_id = %s AND store_id = %s AND arrival_date >= %s
        ''', (product_id, self.store_id, fourteen_days_ago))
        result = db.cursor.fetchone()
        total_delivered = result['total_delivered'] if result else 0

        if total_delivered == 0:
            return 0.0

        return (total_returned / total_delivered) * 100.0

    def get_return_rate(self, product_id: str) -> float:
        try:
            db = get_database()
            rate = self._calculate_return_rate(product_id, db)
            db.close()
            return rate
        except Exception:
            return 0.0

    def get_stock_count(self, product_id: str) -> int:
        try:
            db = get_database()
            db.cursor.execute('''
                SELECT COUNT(*) as count
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s AND status = 'in_stock'
            ''', (product_id, self.store_id))
            result = db.cursor.fetchone()
            db.close()
            return result['count'] if result else 0
        except Exception:
            return 0

    def _get_product_name(self, product_id: str, db) -> str:
        try:
            db.cursor.execute(
                'SELECT product_name FROM products WHERE product_id = %s LIMIT 1',
                (product_id,)
            )
            row = db.cursor.fetchone()
            return row['product_name'] if row else None
        except:
            return None

    def get_tokens_by_batch(self, product_id: str, batch_id: str) -> list:
        try:
            db = get_database()
            self._ensure_tables(db)
            db.cursor.execute('''
                SELECT token_id, status, arrival_date, expiration_date
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s AND batch_id = %s
            ''', (product_id, self.store_id, batch_id))
            rows = db.cursor.fetchall()
            db.close()
            return rows
        except Exception as e:
            logger.error(f"get_tokens_by_batch failed: {e}")
            return []

    def get_tokens_by_arrival_date(self, product_id: str, arrival_date: str) -> list:
        """
        Return all tokens for a product that arrived on a specific date,
        regardless of batch_id. Used to prevent duplicates when different
        batch naming conventions are used across pipeline functions.
        """
        try:
            db = get_database()
            self._ensure_tables(db)
            db.cursor.execute('''
                SELECT token_id, status, arrival_date, expiration_date, batch_id
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s
                  AND arrival_date::date = %s::date
            ''', (product_id, self.store_id, arrival_date))
            rows = db.cursor.fetchall()
            db.close()
            return rows
        except Exception as e:
            logger.error(f"get_tokens_by_arrival_date failed: {e}")
            return []

    def reset_all_tokens(self, product_id: str) -> Dict:
        try:
            db = get_database()
            self._ensure_tables(db)

            db.cursor.execute('''
                SELECT COUNT(*) as count FROM product_tokens
                WHERE product_id = %s AND store_id = %s
            ''', (product_id, self.store_id))
            total = db.cursor.fetchone()['count']

            db.cursor.execute('''
                SELECT status, COUNT(*) as count FROM product_tokens
                WHERE product_id = %s AND store_id = %s
                GROUP BY status
            ''', (product_id, self.store_id))
            breakdown = {row['status']: row['count'] for row in db.cursor.fetchall()}

            db.cursor.execute('''
                DELETE FROM product_tokens
                WHERE product_id = %s AND store_id = %s
            ''', (product_id, self.store_id))
            deleted = db.cursor.rowcount

            db.conn.commit()
            db.close()

            return {
                'success': True,
                'product_id': product_id,
                'tokens_deleted': deleted,
                'breakdown': breakdown,
                'message': f'Reset {deleted} tokens for {product_id} (was: {breakdown})'
            }
        except Exception as e:
            return {'success': False, 'error': str(e), 'product_id': product_id}

    def add_delivery_tokens(self, product_id: str, quantity: int,
                           arrival_date: str = None, batch_id: str = None,
                           shelf_life_days: int = None) -> Dict:
        try:
            db = get_database()
            self._ensure_tables(db)

            if shelf_life_days is None:
                db.cursor.execute(
                    'SELECT shelf_life_days FROM products WHERE product_id = %s',
                    (product_id,)
                )
                row = db.cursor.fetchone()
                shelf_life_days = row['shelf_life_days'] if row else 16

            arr_date = arrival_date or datetime.now().strftime('%Y-%m-%d')
            arr_dt = datetime.strptime(arr_date, '%Y-%m-%d')
            exp_date = (arr_dt + timedelta(days=shelf_life_days)).strftime('%Y-%m-%d')
            b_id = batch_id or f"BATCH-{arr_date}-{product_id}"
            product_name = self._get_product_name(product_id, db)
            today = datetime.now().strftime('%Y-%m-%d')

            for _ in range(quantity):
                token_id = str(uuid.uuid4())
                db.cursor.execute('''
                    INSERT INTO product_tokens
                    (token_id, product_id, product_name, store_id, batch_id,
                     arrival_date, expiration_date, status, status_date)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, 'in_stock', %s)
                ''', (token_id, product_id, product_name, self.store_id,
                      b_id, arr_date, exp_date, today))

            db.conn.commit()

            db.cursor.execute('''
                SELECT COUNT(*) as count
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s AND status = 'in_stock'
            ''', (product_id, self.store_id))
            result = db.cursor.fetchone()
            new_stock = result['count'] if result else quantity

            db.close()
            return {
                'success': True,
                'product_id': product_id,
                'tokens_created': quantity,
                'batch_id': b_id,
                'arrival_date': arr_date,
                'expiration_date': exp_date,
                'new_stock_level': new_stock,
                'message': f'Added {quantity} tokens for {product_id} (batch {b_id}, expires {exp_date})'
            }
        except Exception as e:
            return {'success': False, 'error': str(e), 'product_id': product_id}

    def sell_tokens(self, product_id: str, quantity: int) -> Dict:
        try:
            db = get_database()
            today = datetime.now().strftime('%Y-%m-%d')
            now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

            db.cursor.execute('''
                SELECT token_id FROM product_tokens
                WHERE product_id = %s AND store_id = %s AND status = 'in_stock'
                ORDER BY arrival_date ASC
                LIMIT %s
            ''', (product_id, self.store_id, quantity))

            tokens = db.cursor.fetchall()
            sold = 0
            for token in tokens:
                db.cursor.execute('''
                    UPDATE product_tokens
                    SET status = 'sold', consumed_date = %s,
                        status_date = %s, updated_at = %s
                    WHERE token_id = %s AND status = 'in_stock'
                ''', (today, today, now, token['token_id']))
                sold += db.cursor.rowcount

            db.conn.commit()
            db.close()
            return {
                'success': True,
                'product_id': product_id,
                'units_sold': sold,
                'units_requested': quantity,
                'message': f'Sold {sold} units of {product_id} (FIFO oldest-first)'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def expire_tokens(self, product_id: str = None) -> Dict:
        try:
            db = get_database()
            self._ensure_tables(db)
            today = datetime.now().strftime('%Y-%m-%d')

            if product_id:
                db.cursor.execute('''
                    SELECT product_id, store_id, batch_id, arrival_date, expiration_date
                    FROM product_tokens
                    WHERE status = 'in_stock' AND expiration_date <= %s AND product_id = %s
                ''', (today, product_id))
            else:
                db.cursor.execute('''
                    SELECT product_id, store_id, batch_id, arrival_date, expiration_date
                    FROM product_tokens
                    WHERE status = 'in_stock' AND expiration_date <= %s
                ''', (today,))

            matured_tokens = db.cursor.fetchall()

            if matured_tokens:
                batches = {}
                for token in matured_tokens:
                    key = (token['product_id'], token['store_id'], token['batch_id'],
                           str(token['arrival_date']), str(token['expiration_date']))
                    if key not in batches:
                        batches[key] = {
                            'product_id': token['product_id'],
                            'store_id': token['store_id'],
                            'batch_id': token['batch_id'],
                            'arrival_date': token['arrival_date'],
                            'expiration_date': token['expiration_date'],
                            'count': 0
                        }
                    batches[key]['count'] += 1

                for batch in batches.values():
                    days_on_shelf = (batch['expiration_date'] - batch['arrival_date']).days if batch['arrival_date'] and batch['expiration_date'] else None
                    db.cursor.execute('''
                        INSERT INTO token_sales_log
                        (product_id, store_id, sale_date, units_sold, batch_id,
                         arrival_date, expiration_date, days_on_shelf, source)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'shelf_life')
                    ''', (batch['product_id'], batch['store_id'], today,
                          batch['count'], batch['batch_id'],
                          batch['arrival_date'], batch['expiration_date'],
                          days_on_shelf))

            now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

            if product_id:
                db.cursor.execute('''
                    UPDATE product_tokens
                    SET status = 'sold', consumed_date = %s,
                        status_date = %s, updated_at = %s
                    WHERE status = 'in_stock' AND expiration_date <= %s AND product_id = %s
                ''', (today, today, now, today, product_id))
            else:
                db.cursor.execute('''
                    UPDATE product_tokens
                    SET status = 'sold', consumed_date = %s,
                        status_date = %s, updated_at = %s
                    WHERE status = 'in_stock' AND expiration_date <= %s
                ''', (today, today, now, today))

            matured = db.cursor.rowcount
            db.conn.commit()
            db.close()
            return {
                'success': True,
                'tokens_matured_to_sold': matured,
                'message': f'{matured} tokens reached 12-day shelf life — marked as sold'
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def parse_csv_invoice(self, csv_path: str) -> List[Dict]:
        results = []
        try:
            with open(csv_path, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    product_id = row.get('product_id', row.get('sku', '')).strip()
                    units = int(row.get('units_returned', row.get('quantity', 0)))
                    invoice_id = row.get('invoice_id', row.get('invoice_number', f'CSV-{Path(csv_path).stem}'))
                    reason = row.get('reason', row.get('return_reason', ''))
                    invoice_date = row.get('invoice_date', row.get('date', None))

                    if product_id and units > 0:
                        result = self.process_returns(
                            product_id=product_id,
                            units_returned=units,
                            invoice_id=f"{invoice_id}-{product_id}",
                            reason=reason,
                            invoice_date=invoice_date,
                            force_day=True
                        )
                        results.append(result)
        except Exception as e:
            results.append({'success': False, 'error': f'CSV parse error: {e}'})
        return results

    def get_inventory_summary(self, product_id: str) -> Dict:
        try:
            db = get_database()

            db.cursor.execute('''
                SELECT status, COUNT(*) as count
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s
                GROUP BY status
            ''', (product_id, self.store_id))

            summary = {}
            for row in db.cursor.fetchall():
                summary[row['status']] = row['count']

            return_rate = self._calculate_return_rate(product_id, db)

            db.cursor.execute('''
                SELECT MIN(arrival_date) as oldest, MAX(arrival_date) as newest
                FROM product_tokens
                WHERE product_id = %s AND store_id = %s AND status = 'in_stock'
            ''', (product_id, self.store_id))
            dates = db.cursor.fetchone()

            db.close()
            return {
                'success': True,
                'product_id': product_id,
                'store_id': self.store_id,
                'in_stock': summary.get('in_stock', 0),
                'sold': summary.get('sold', 0),
                'returned': summary.get('returned', 0),
                'expired': summary.get('expired', 0),
                'return_rate_14d': round(return_rate, 2),
                'oldest_stock_date': str(dates['oldest']) if dates and dates['oldest'] else None,
                'newest_stock_date': str(dates['newest']) if dates and dates['newest'] else None,
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}


def get_returns_tools_for_agent() -> Dict:
    parser = ReturnsInvoiceParser()
    return {
        'process_returns': {
            'description': (
                'Process a returns invoice for a product. Updates FIFO inventory tokens '
                '(oldest in_stock tokens marked as returned first). Returns are only '
                'accepted on Tuesday and Friday to match the real invoice schedule.'
            ),
            'parameters': {
                'product_id': 'str - Product ID (e.g., "500107")',
                'units_returned': 'int - Number of units being returned',
                'invoice_id': 'str - Unique invoice identifier',
                'reason': 'str - Optional reason for return',
            },
            'function': lambda product_id, units_returned, invoice_id, reason=None: 
                parser.process_returns(product_id, int(units_returned), invoice_id, reason)
        },
        'get_return_rate': {
            'description': 'Get rolling 14-day return rate percentage for a product.',
            'parameters': {
                'product_id': 'str - Product ID (e.g., "500107")'
            },
            'function': lambda product_id: {
                'return_rate_14d': parser.get_return_rate(product_id),
                'product_id': product_id
            }
        },
        'add_delivery': {
            'description': 'Record a delivery of product tokens into FIFO inventory.',
            'parameters': {
                'product_id': 'str - Product ID',
                'quantity': 'int - Number of units delivered',
                'arrival_date': 'str - Date of arrival (YYYY-MM-DD)',
            },
            'function': lambda product_id, quantity, arrival_date=None:
                parser.add_delivery_tokens(product_id, int(quantity), arrival_date)
        },
        'sell_units': {
            'description': 'Record units sold from FIFO inventory (oldest first).',
            'parameters': {
                'product_id': 'str - Product ID',
                'quantity': 'int - Number of units sold',
            },
            'function': lambda product_id, quantity:
                parser.sell_tokens(product_id, int(quantity))
        },
        'get_inventory_summary': {
            'description': 'Get full inventory summary with token counts by status and return rate.',
            'parameters': {
                'product_id': 'str - Product ID',
            },
            'function': parser.get_inventory_summary
        },
        'expire_old_stock': {
            'description': 'Mark all expired tokens (past shelf life) as expired.',
            'parameters': {
                'product_id': 'str - Optional product ID (omit for all products)',
            },
            'function': lambda product_id=None: parser.expire_tokens(product_id)
        },
    }


if __name__ == '__main__':
    print("Returns Invoice Parser - Test Mode\n")
    parser = ReturnsInvoiceParser(enforce_return_days=False)

    print("1. Adding 10 delivery tokens...")
    result = parser.add_delivery_tokens('500107', 10, '2026-02-15')
    print(f"   {result['message']}")

    print("2. Selling 3 units (FIFO)...")
    result = parser.sell_tokens('500107', 3)
    print(f"   {result['message']}")

    print("3. Processing 2 returns...")
    result = parser.process_returns('500107', 2, 'TEST-INV-001', 'Test return', force_day=True)
    print(f"   {result['message']}")
    print(f"   Return rate: {result['return_rate_14d']}%")

    print("4. Inventory summary:")
    summary = parser.get_inventory_summary('500107')
    print(f"   In stock: {summary['in_stock']}")
    print(f"   Sold: {summary['sold']}")
    print(f"   Returned: {summary['returned']}")
    print(f"   14-day return rate: {summary['return_rate_14d']}%")
