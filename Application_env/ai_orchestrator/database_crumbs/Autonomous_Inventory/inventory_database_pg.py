#!/usr/bin/env python3
"""
Autonomous Inventory Database System - PostgreSQL Version
Real-time inventory tracking with product tokenization and expiration management
Migrated from SQLite to PostgreSQL for production scalability
"""

import psycopg2
from psycopg2.extras import RealDictCursor
import uuid
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple


class InventoryDatabasePG:
    """Manages autonomous inventory tracking for Demo Store store using PostgreSQL"""
    
    def __init__(self, database_url=None):
        """
        Initialize PostgreSQL connection and create tables if needed
        
        Args:
            database_url: PostgreSQL connection string (defaults to DATABASE_URL env var)
        """
        if database_url is None:
            database_url = os.environ.get('DATABASE_URL')
            if not database_url:
                raise ValueError("DATABASE_URL environment variable not set")
        
        self.database_url = database_url
        self.conn = psycopg2.connect(database_url)
        self.conn.autocommit = False  # Use transactions
        self.cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        self._create_tables()
    
    def _create_tables(self):
        """Create all database tables for inventory tracking"""
        
        # Table 1: Product Tokens (Individual Units with Expiration)
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS product_tokens (
                token_id TEXT PRIMARY KEY,
                product_id TEXT NOT NULL,
                product_name TEXT,
                store_id TEXT NOT NULL,
                
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
        
        # Indexes for fast queries (including FIFO optimization)
        self.cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_product_tokens_status 
            ON product_tokens(product_id, store_id, status)
        ''')
        
        self.cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_product_tokens_expiration 
            ON product_tokens(expiration_date, status)
        ''')
        
        # CRITICAL: FIFO index for ORDER BY arrival_date, token_id queries
        self.cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_product_tokens_fifo 
            ON product_tokens(product_id, store_id, arrival_date, token_id)
        ''')
        
        # Table 2: Inventory Transactions (All movements)
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS inventory_transactions (
                transaction_id TEXT PRIMARY KEY,
                product_id TEXT NOT NULL,
                store_id TEXT NOT NULL,
                
                transaction_type TEXT NOT NULL,
                quantity INTEGER NOT NULL,
                transaction_date DATE NOT NULL,
                
                source TEXT NOT NULL,
                source_reference TEXT,
                
                notes TEXT,
                
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                
                CONSTRAINT check_transaction_type CHECK (transaction_type IN ('delivery', 'sale', 'return', 'expired', 'physical_count', 'adjustment'))
            )
        ''')
        
        self.cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_transactions_date 
            ON inventory_transactions(product_id, store_id, transaction_date)
        ''')
        
        # Table 3: Sales Predictions (Year-over-Year Data)
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS sales_predictions (
                prediction_id TEXT PRIMARY KEY,
                product_id TEXT NOT NULL,
                store_id TEXT NOT NULL,
                
                historical_date DATE NOT NULL,
                predicted_date DATE NOT NULL,
                predicted_quantity INTEGER NOT NULL,
                
                confidence REAL DEFAULT 1.0,
                actual_quantity INTEGER,
                variance INTEGER,
                
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                
                UNIQUE(product_id, store_id, predicted_date)
            )
        ''')
        
        # Table 4: Physical Counts (Snapshot Baselines)
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS physical_counts (
                count_id TEXT PRIMARY KEY,
                product_id TEXT NOT NULL,
                store_id TEXT NOT NULL,
                
                count_date DATE NOT NULL,
                quantity_counted INTEGER NOT NULL,
                
                calculated_quantity INTEGER,
                variance INTEGER,
                
                count_method TEXT,
                photo_path TEXT,
                notes TEXT,
                
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                
                CONSTRAINT check_count_method CHECK (count_method IN ('manual', 'photo_ai', 'photo_manual', 'system'))
            )
        ''')
        
        # Table 5: Product Master Data
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS products (
                product_id TEXT PRIMARY KEY,
                product_name TEXT NOT NULL,
                category TEXT,
                
                shelf_life_days INTEGER DEFAULT 12,
                reorder_point INTEGER,
                reorder_quantity INTEGER,
                
                tray_factor INTEGER,
                
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Table 6: Store Information
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS stores (
                store_id TEXT PRIMARY KEY,
                store_name TEXT NOT NULL,
                store_type TEXT,
                
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        self.conn.commit()
    
    def add_product(self, product_id: str, product_name: str, 
                   shelf_life_days: int = 12, tray_factor: int = 1,
                   reorder_point: int = None, reorder_quantity: int = None,
                   category: str = 'bread') -> bool:
        """Add or update product master data"""
        try:
            self.cursor.execute('''
                INSERT INTO products 
                (product_id, product_name, category, shelf_life_days, tray_factor, 
                 reorder_point, reorder_quantity, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
                ON CONFLICT (product_id) DO UPDATE SET
                    product_name = EXCLUDED.product_name,
                    category = EXCLUDED.category,
                    shelf_life_days = EXCLUDED.shelf_life_days,
                    tray_factor = EXCLUDED.tray_factor,
                    reorder_point = EXCLUDED.reorder_point,
                    reorder_quantity = EXCLUDED.reorder_quantity,
                    updated_at = CURRENT_TIMESTAMP
            ''', (product_id, product_name, category, shelf_life_days, tray_factor,
                  reorder_point, reorder_quantity))
            self.conn.commit()
            return True
        except Exception as e:
            print(f"Error adding product: {e}")
            self.conn.rollback()
            return False
    
    def add_store(self, store_id: str, store_name: str, store_type: str = 'retail') -> bool:
        """Add store information"""
        try:
            self.cursor.execute('''
                INSERT INTO stores (store_id, store_name, store_type)
                VALUES (%s, %s, %s)
                ON CONFLICT (store_id) DO UPDATE SET
                    store_name = EXCLUDED.store_name,
                    store_type = EXCLUDED.store_type
            ''', (store_id, store_name, store_type))
            self.conn.commit()
            return True
        except Exception as e:
            print(f"Error adding store: {e}")
            self.conn.rollback()
            return False

    def insert_physical_count(self, product_id: str, store_id: str,
                              quantity: int, count_date: str = None,
                              count_method: str = 'manual',
                              baseline_id: str = None,
                              photo_path: str = None, notes: str = None) -> str:
        """
        Insert a physical inventory count (baseline snapshot)
        
        Args:
            product_id: Product SKU
            store_id: Store identifier
            quantity: Actual counted quantity
            count_date: Date of count (defaults to today)
            count_method: 'manual', 'photo_ai', 'photo_manual'
            photo_path: Path to photo if photo-based count
            notes: Additional notes
        
        Returns:
            count_id: Unique identifier for this count
        """
        if count_date is None:
            count_date = datetime.now().strftime('%Y-%m-%d')
        
        count_id = f"count_{uuid.uuid4().hex[:12]}"
        
        # Calculate what the system thinks inventory should be
        calculated = self.calculate_current_inventory(product_id, store_id)
        variance = quantity - calculated if calculated is not None else None
        
        try:
            self.cursor.execute('''
                INSERT INTO physical_counts 
                (count_id, product_id, store_id, count_date, quantity_counted,
                 calculated_quantity, variance, count_method, photo_path, notes, baseline_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ''', (count_id, product_id, store_id, count_date, quantity,
                  calculated, variance, count_method, photo_path, notes, baseline_id))
            
            # Also record as transaction
            self._add_transaction(
                product_id, store_id, 'physical_count', quantity, count_date,
                'physical_count', count_id, 
                f"Physical count: {quantity} units (variance: {variance})"
            )
            
            self.conn.commit()
            return count_id
        except Exception as e:
            print(f"Error inserting physical count: {e}")
            self.conn.rollback()
            return None
    
    def _add_transaction(self, product_id: str, store_id: str, 
                        transaction_type: str, quantity: int, 
                        transaction_date: str, source: str,
                        source_reference: str = None, notes: str = None) -> str:
        """Internal method to add inventory transaction"""
        transaction_id = f"txn_{uuid.uuid4().hex[:12]}"
        
        self.cursor.execute('''
            INSERT INTO inventory_transactions
            (transaction_id, product_id, store_id, transaction_type, quantity,
             transaction_date, source, source_reference, notes)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        ''', (transaction_id, product_id, store_id, transaction_type, quantity,
              transaction_date, source, source_reference, notes))
        
        return transaction_id
    
    def record_delivery(self, product_id: str, store_id: str, 
                       quantity: int, delivery_date: str = None,
                       invoice_number: str = None, 
                       expiration_date: str = None) -> Tuple[str, List[str]]:
        """
        Record product delivery and create individual tokens
        
        Args:
            product_id: Product SKU
            store_id: Store identifier
            quantity: Number of units delivered
            delivery_date: Date of delivery (defaults to today)
            invoice_number: Supplier invoice reference
            expiration_date: Override expiration (defaults to shelf_life_days from product)
        
        Returns:
            (transaction_id, list of token_ids)
        """
        if delivery_date is None:
            delivery_date = datetime.now().strftime('%Y-%m-%d')
        
        # Get product shelf life
        self.cursor.execute('SELECT shelf_life_days FROM products WHERE product_id = %s', 
                          (product_id,))
        row = self.cursor.fetchone()
        shelf_life = row['shelf_life_days'] if row else 12
        
        # Calculate expiration if not provided
        if expiration_date is None:
            delivery_dt = datetime.strptime(delivery_date, '%Y-%m-%d')
            exp_dt = delivery_dt + timedelta(days=shelf_life)
            expiration_date = exp_dt.strftime('%Y-%m-%d')
        
        try:
            # Record transaction
            txn_id = self._add_transaction(
                product_id, store_id, 'delivery', quantity, delivery_date,
                'invoice', invoice_number, 
                f"Delivery: {quantity} units, expires {expiration_date}"
            )
            
            # Create individual product tokens
            batch_id = f"batch_{uuid.uuid4().hex[:8]}"
            token_ids = []

            for i in range(quantity):
                token_id = f"{product_id}_{uuid.uuid4().hex[:8]}"
                
                self.cursor.execute('''
                    INSERT INTO product_tokens
                    (token_id, product_id, store_id, arrival_date, expiration_date,
                     status, status_date, batch_id)
                    VALUES (%s, %s, %s, %s, %s, 'in_stock', %s, %s)
                ''', (token_id, product_id, store_id, delivery_date, expiration_date,
                      delivery_date, batch_id))
                
                token_ids.append(token_id)
            
            self.conn.commit()
            return (txn_id, token_ids)
        except Exception as e:
            print(f"Error recording delivery: {e}")
            self.conn.rollback()
            return (None, [])
    
    def record_sales_prediction(self, product_id: str, store_id: str,
                                historical_date: str, predicted_date: str,
                                predicted_quantity: int, 
                                confidence: float = 1.0) -> str:
        """
        Record year-over-year sales prediction
        
        Args:
            product_id: Product SKU
            store_id: Store identifier
            historical_date: Last year's date (e.g., "2024-11-02")
            predicted_date: This year's date (e.g., "2025-11-02")
            predicted_quantity: Expected sales units
            confidence: Prediction confidence (0.0 to 1.0)
        
        Returns:
            prediction_id
        """
        prediction_id = f"pred_{uuid.uuid4().hex[:12]}"
        
        try:
            self.cursor.execute('''
                INSERT INTO sales_predictions
                (prediction_id, product_id, store_id, historical_date, 
                 predicted_date, predicted_quantity, confidence)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (product_id, store_id, predicted_date) DO UPDATE SET
                    prediction_id = EXCLUDED.prediction_id,
                    historical_date = EXCLUDED.historical_date,
                    predicted_quantity = EXCLUDED.predicted_quantity,
                    confidence = EXCLUDED.confidence,
                    updated_at = CURRENT_TIMESTAMP
            ''', (prediction_id, product_id, store_id, historical_date,
                  predicted_date, predicted_quantity, confidence))
            
            self.conn.commit()
            return prediction_id
        except Exception as e:
            print(f"Error recording sales prediction: {e}")
            self.conn.rollback()
            return None
    
    def apply_predicted_sales(self, product_id: str, store_id: str,
                             sale_date: str) -> int:
        """
        Apply predicted sales for a specific date (marks tokens as sold)
        
        Args:
            product_id: Product SKU
            store_id: Store identifier
            sale_date: Date to apply sales for
        
        Returns:
            Number of units marked as sold
        """
        # Get prediction for this date
        self.cursor.execute('''
            SELECT predicted_quantity FROM sales_predictions
            WHERE product_id = %s AND store_id = %s AND predicted_date = %s
        ''', (product_id, store_id, sale_date))
        
        row = self.cursor.fetchone()
        if not row:
            return 0
        
        predicted_qty = row['predicted_quantity']
        
        # Get oldest in-stock tokens (FIFO)
        self.cursor.execute('''
            SELECT token_id FROM product_tokens
            WHERE product_id = %s AND store_id = %s AND status = 'in_stock'
            ORDER BY arrival_date ASC, token_id ASC
            LIMIT %s
        ''', (product_id, store_id, predicted_qty))
        
        tokens = self.cursor.fetchall()
        sold_count = 0
        
        try:
            for token in tokens:
                self.cursor.execute('''
                    UPDATE product_tokens
                    SET status = 'sold', status_date = %s, updated_at = CURRENT_TIMESTAMP
                    WHERE token_id = %s
                ''', (sale_date, token['token_id']))
                sold_count += 1
            
            # Record transaction
            if sold_count > 0:
                self._add_transaction(
                    product_id, store_id, 'sale', sold_count, sale_date,
                    'prediction', None, 
                    f"Predicted sales: {sold_count} units"
                )
            
            self.conn.commit()
            return sold_count
        except Exception as e:
            print(f"Error applying predicted sales: {e}")
            self.conn.rollback()
            return 0
    
    def record_returns(self, product_id: str, store_id: str,
                      quantity: int, return_date: str = None,
                      invoice_number: str = None, reason: str = 'expired') -> str:
        """
        Record product returns/expirations
        
        Args:
            product_id: Product SKU
            store_id: Store identifier
            quantity: Number of units returned
            return_date: Date of return (defaults to today)
            invoice_number: Return invoice reference
            reason: 'expired', 'damaged', 'other'
        
        Returns:
            transaction_id
        """
        if return_date is None:
            return_date = datetime.now().strftime('%Y-%m-%d')
        
        # Mark tokens as expired/returned (oldest first)
        self.cursor.execute('''
            SELECT token_id FROM product_tokens
            WHERE product_id = %s AND store_id = %s AND status = 'in_stock'
            ORDER BY expiration_date ASC, arrival_date ASC
            LIMIT %s
        ''', (product_id, store_id, quantity))
        
        tokens = self.cursor.fetchall()
        
        try:
            for token in tokens:
                status = 'returned'  # All returns marked as 'returned' (FIFO removal)
                self.cursor.execute('''
                    UPDATE product_tokens
                    SET status = %s, status_date = %s, consumed_date = %s, updated_at = CURRENT_TIMESTAMP
                    WHERE token_id = %s
                ''', (status, return_date, return_date, token['token_id']))
            
            # Record transaction
            txn_id = self._add_transaction(
                product_id, store_id, 'return', quantity, return_date,
                'invoice', invoice_number, 
                f"Return: {quantity} units ({reason})"
            )
            
            self.conn.commit()
            return txn_id
        except Exception as e:
            print(f"Error recording returns: {e}")
            self.conn.rollback()
            return None
    
    def calculate_current_inventory(self, product_id: str, store_id: str) -> int:
        """
        Calculate current inventory based on in-stock tokens
        
        Returns:
            Number of units currently in stock
        """
        self.cursor.execute('''
            SELECT COUNT(*) as count FROM product_tokens
            WHERE product_id = %s AND store_id = %s AND status = 'in_stock'
        ''', (product_id, store_id))
        
        row = self.cursor.fetchone()
        return row['count'] if row else 0
    
    def get_expiring_products(self, store_id: str, days_ahead: int = 2) -> List[Dict]:
        """
        Get products expiring within specified days
        
        Args:
            store_id: Store identifier
            days_ahead: Number of days to look ahead
        
        Returns:
            List of products with expiration info
        """
        cutoff_date = (datetime.now() + timedelta(days=days_ahead)).strftime('%Y-%m-%d')
        
        self.cursor.execute('''
            SELECT product_id, expiration_date, COUNT(*) as quantity
            FROM product_tokens
            WHERE store_id = %s AND status = 'in_stock' 
              AND expiration_date <= %s
            GROUP BY product_id, expiration_date
            ORDER BY expiration_date ASC
        ''', (store_id, cutoff_date))
        
        return [dict(row) for row in self.cursor.fetchall()]
    
    def get_inventory_summary(self, store_id: str) -> List[Dict]:
        """Get current inventory summary by product"""
        self.cursor.execute('''
            SELECT 
                pt.product_id,
                p.product_name,
                COUNT(*) as current_stock,
                MIN(pt.expiration_date) as earliest_expiration,
                MAX(pt.expiration_date) as latest_expiration
            FROM product_tokens pt
            LEFT JOIN products p ON pt.product_id = p.product_id
            WHERE pt.store_id = %s AND pt.status = 'in_stock'
            GROUP BY pt.product_id, p.product_name
            ORDER BY p.product_name
        ''', (store_id,))
        
        return [dict(row) for row in self.cursor.fetchall()]
    
    def create_product_token(self, product_id: str, store_id: str,
                            arrival_date: str, shelf_life_days: int = 12,
                            batch_id: str = None) -> str:
        """
        Create a single product token (for token generation system)
        
        Args:
            product_id: Product SKU
            store_id: Store identifier
            arrival_date: Date product arrived/counted
            shelf_life_days: Days until expiration (default 12 = 1.7 weeks)
            batch_id: Batch identifier
        
        Returns:
            token_id
        """
        token_id = f"{product_id}_{uuid.uuid4().hex[:8]}"

        # Calculate expiration date
        arrival_dt = datetime.strptime(arrival_date, '%Y-%m-%d')
        exp_dt = arrival_dt + timedelta(days=shelf_life_days)
        expiration_date = exp_dt.strftime('%Y-%m-%d')
        
        # Get product name
        self.cursor.execute('SELECT product_name FROM products WHERE product_id = %s', 
                          (product_id,))
        row = self.cursor.fetchone()
        product_name = row['product_name'] if row else None
        
        self.cursor.execute('''
            INSERT INTO product_tokens
            (token_id, product_id, product_name, store_id, arrival_date, 
             expiration_date, status, status_date, batch_id)
            VALUES (%s, %s, %s, %s, %s, %s, 'in_stock', %s, %s)
        ''', (token_id, product_id, product_name, store_id, arrival_date,
              expiration_date, arrival_date, batch_id))
        
        return token_id
    
    def process_daily_cleanup(self, store_id: str = None, 
                             as_of_date: str = None) -> Dict[str, int]:
        """
        Daily cleanup: Mark expired unsold tokens as 'sold' (sales tracking)
        
        This is the core of the FIFO sales tracking system.
        Any token that survives to expiration_date without being marked 'returned' = SOLD
        
        Args:
            store_id: Store identifier (None = all stores)
            as_of_date: Date to run cleanup for (defaults to today)
        
        Returns:
            Dict with cleanup statistics
        """
        if as_of_date is None:
            as_of_date = datetime.now().strftime('%Y-%m-%d')
        
        # Find tokens that reached expiration and are still in_stock (never returned) = SOLD
        if store_id:
            self.cursor.execute('''
                                SELECT token_id, product_id, store_id, expiration_date
                                FROM product_tokens
                                WHERE store_id = %s
                                  AND status = 'in_stock'
                                  AND expiration_date <= %s::date + INTERVAL '3 days'
                                ''', (store_id, as_of_date))
        else:
            self.cursor.execute('''
                                SELECT token_id, product_id, store_id, expiration_date
                                FROM product_tokens
                                WHERE status = 'in_stock'
                                  AND expiration_date <= %s::date + INTERVAL '3 days'
                                ''', (as_of_date,))
        
        expired_tokens = self.cursor.fetchall()
        
        stats = {
            'tokens_marked_sold': 0,
            'products_affected': set(),
            'date': as_of_date
        }
        
        try:
            for token in expired_tokens:
                # Mark as sold (it survived to expiration = customer bought it)
                self.cursor.execute('''
                    UPDATE product_tokens
                    SET status = 'sold', 
                        status_date = %s,
                        consumed_date = %s,
                        updated_at = CURRENT_TIMESTAMP,
                        notes = 'Auto-sold: Survived to expiration (FIFO sales tracking)'
                    WHERE token_id = %s
                ''', (as_of_date, token['expiration_date'], token['token_id']))
                
                stats['tokens_marked_sold'] += 1
                stats['products_affected'].add(token['product_id'])
            
            stats['products_affected'] = len(stats['products_affected'])
            
            self.conn.commit()
            return stats
        except Exception as e:
            print(f"Error processing daily cleanup: {e}")
            self.conn.rollback()
            return stats
    
    def get_sales_report(self, product_id: str, store_id: str,
                        start_date: str, end_date: str) -> Dict:
        """
        Get sales report for a product within date range
        
        Args:
            product_id: Product SKU
            store_id: Store identifier
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
        
        Returns:
            Sales statistics dictionary
        """
        self.cursor.execute('''
            SELECT 
                COUNT(*) as units_sold,
                MIN(consumed_date) as first_sale,
                MAX(consumed_date) as last_sale
            FROM product_tokens
            WHERE product_id = %s AND store_id = %s 
              AND status = 'sold'
              AND consumed_date BETWEEN %s AND %s
        ''', (product_id, store_id, start_date, end_date))
        
        row = self.cursor.fetchone()
        return dict(row) if row else {}
    
    def close(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
    
    def __enter__(self):
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()
