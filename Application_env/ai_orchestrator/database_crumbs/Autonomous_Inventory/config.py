#!/usr/bin/env python3
"""
Shared Configuration for Demo Store Autonomous Inventory System
"""

import os
import pytz
from datetime import datetime

# Store Configuration
STORE_ID = '70012004'
STORE_NAME = 'Fictional Market Demo #4'

# Database Configuration
DB_PATH = 'demo_store_inventory.db'
USE_POSTGRESQL = True

# PostgreSQL Connection (from environment or default).
# NOTE: deliberately reads DEMO_DATABASE_URL — NOT DATABASE_URL — so this demo
# build can never inherit a production connection string from the shell env.
DATABASE_URL = os.environ.get('DEMO_DATABASE_URL', 'postgresql://postgres:8989@127.0.0.1:5432/levaintron_demo')

# Timezone Configuration
DEFAULT_TIMEZONE = pytz.timezone('America/Denver')
TIMEZONE_NAME = 'MST'

# Product Configuration
SHELF_LIFE_DAYS = 16

# Baseline Configuration (for token generation/reset)
CURRENT_BASELINE_DATE = datetime.now(DEFAULT_TIMEZONE).strftime('%Y-%m-%d')
BASELINE_DESCRIPTION = "Fresh system baseline"


def get_database():
    """
    Database factory function - returns InventoryDatabasePG instance
    NOT the DATABASE_URL string!
    """
    if USE_POSTGRESQL:
        try:
            from .inventory_database_pg import InventoryDatabasePG
        except ImportError:
            from inventory_database_pg import InventoryDatabasePG
        return InventoryDatabasePG(DATABASE_URL)
    else:
        try:
            from .inventory_database import InventoryDatabase
        except ImportError:
            from inventory_database import InventoryDatabase
        return InventoryDatabase(DB_PATH)



def generate_baseline_id():
    """Generate unique baseline ID with timestamp (includes seconds)"""
    return datetime.now().strftime("baseline_%Y%m%d_%H%M%S")

def get_latest_baseline_id(db):
    """Get the most recent baseline_id from physical_counts"""
    db.cursor.execute('''
        SELECT baseline_id FROM physical_counts 
        WHERE baseline_id IS NOT NULL
        ORDER BY baseline_id DESC 
        LIMIT 1
    ''')
    result = db.cursor.fetchone()
    return result['baseline_id'] if result else None