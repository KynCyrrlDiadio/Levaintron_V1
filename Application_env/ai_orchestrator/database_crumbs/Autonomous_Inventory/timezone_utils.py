#!/usr/bin/env python3
"""
Timezone Utilities for Demo Store Inventory System
DevOps Standard: Store UTC, Display MST

Usage:
    from timezone_utils import to_mst, now_mst_str, format_timestamp
    
    # Display database timestamp in MST
    print(f"Created: {to_mst('2025-11-05 19:19:07')}")
    # Output: Created: 2025-11-05 12:19:07 MST
    
    # Current time for logging
    print(f"[{now_mst_str()}] Processing inventory...")
    # Output: [2025-11-05 15:45:23 MST] Processing inventory...
"""

import pytz
from datetime import datetime


# Timezone configuration
MST = pytz.timezone('America/Denver')  # Handles MST/MDT automatically
UTC = pytz.utc


def to_mst(utc_str, include_tz=True):
    """
    Convert UTC timestamp string to MST/MDT
    
    Args:
        utc_str: UTC timestamp string '2025-11-05 19:19:07'
        include_tz: Include timezone suffix (MST/MDT)
    
    Returns:
        MST timestamp string '2025-11-05 12:19:07 MST'
    
    Example:
        >>> to_mst('2025-11-05 19:19:07')
        '2025-11-05 12:19:07 MST'
    """
    if not utc_str:
        return None
    
    try:
        # Parse UTC string
        utc_dt = datetime.strptime(utc_str, '%Y-%m-%d %H:%M:%S')
        utc_dt = UTC.localize(utc_dt)
        
        # Convert to MST
        mst_dt = utc_dt.astimezone(MST)
        
        if include_tz:
            return mst_dt.strftime('%Y-%m-%d %H:%M:%S %Z')
        else:
            return mst_dt.strftime('%Y-%m-%d %H:%M:%S')
    
    except (ValueError, TypeError) as e:
        print(f"Warning: Could not convert timestamp '{utc_str}': {e}")
        return utc_str


def now_mst():
    """
    Get current time in MST/MDT
    
    Returns:
        datetime object in MST timezone
    """
    return datetime.now(MST)


def now_mst_str(include_tz=True):
    """
    Get current MST time as string
    
    Args:
        include_tz: Include timezone suffix
    
    Returns:
        '2025-11-05 15:45:23 MST'
    
    Example:
        >>> now_mst_str()
        '2025-11-05 15:45:23 MST'
    """
    if include_tz:
        return now_mst().strftime('%Y-%m-%d %H:%M:%S %Z')
    else:
        return now_mst().strftime('%Y-%m-%d %H:%M:%S')


def now_utc():
    """
    Get current UTC time (for database storage)
    
    Returns:
        datetime object in UTC
    """
    return datetime.utcnow()


def now_utc_str():
    """
    Get current UTC time as string (for database inserts)
    
    Returns:
        '2025-11-05 22:45:23'
    """
    return now_utc().strftime('%Y-%m-%d %H:%M:%S')


def format_timestamp(utc_str, pretty=True):
    """
    Format timestamp for display in reports
    
    Args:
        utc_str: UTC timestamp string
        pretty: Use pretty format vs standard
    
    Returns:
        Pretty: 'Nov 5, 2025 12:19 PM MST'
        Standard: '2025-11-05 12:19:07 MST'
    
    Example:
        >>> format_timestamp('2025-11-05 19:19:07')
        'Nov 5, 2025 12:19 PM MST'
    """
    if not utc_str:
        return None
    
    try:
        utc_dt = datetime.strptime(utc_str, '%Y-%m-%d %H:%M:%S')
        utc_dt = UTC.localize(utc_dt)
        mst_dt = utc_dt.astimezone(MST)
        
        if pretty:
            return mst_dt.strftime('%b %d, %Y %I:%M %p %Z')
        else:
            return mst_dt.strftime('%Y-%m-%d %H:%M:%S %Z')
    
    except (ValueError, TypeError) as e:
        print(f"Warning: Could not format timestamp '{utc_str}': {e}")
        return utc_str


def get_local_date_str():
    """
    Get current date in MST (YYYY-MM-DD format)
    
    Returns:
        '2025-11-05'
    
    Example:
        >>> get_local_date_str()
        '2025-11-05'
    """
    return now_mst().strftime('%Y-%m-%d')


def get_local_datetime_str():
    """
    Get current datetime in MST (YYYY-MM-DD HH:MM:SS format)
    
    Returns:
        '2025-11-05 15:45:23'
    """
    return now_mst().strftime('%Y-%m-%d %H:%M:%S')


# Convenience functions for common use cases
def log_timestamp():
    """Get timestamp for log messages"""
    return now_mst_str(include_tz=True)


def db_timestamp():
    """Get timestamp for database inserts (UTC)"""
    return now_utc_str()


def display_timestamp(utc_str):
    """Quick display conversion from UTC to MST"""
    return to_mst(utc_str, include_tz=True)


# Test function
def test_conversions():
    """Test timezone conversions"""
    print("=" * 70)
    print("TIMEZONE CONVERSION TESTS")
    print("=" * 70)
    
    test_utc = '2025-11-05 19:19:07'
    
    print(f"\nUTC timestamp: {test_utc}")
    print(f"MST conversion: {to_mst(test_utc)}")
    print(f"Pretty format: {format_timestamp(test_utc)}")
    
    print(f"\nCurrent UTC: {now_utc_str()}")
    print(f"Current MST: {now_mst_str()}")
    print(f"Current date (MST): {get_local_date_str()}")
    
    print(f"\nFor logging: [{log_timestamp()}] Message here")
    print(f"For database: INSERT ... VALUES ('{db_timestamp()}')")
    
    print("=" * 70)


if __name__ == "__main__":
    test_conversions()
