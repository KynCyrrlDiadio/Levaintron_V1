"""Autonomous Inventory System — demo build (analyzer tools omitted)"""
from .config import get_database
from .inventory_database_pg import InventoryDatabasePG

__all__ = ['get_database', 'InventoryDatabasePG']
