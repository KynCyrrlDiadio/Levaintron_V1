#!/usr/bin/env python3
"""
Build seasonal multipliers + daily forecast from daily_sales_log

Single source of truth for ALL multiplier tables. Reads raw sales data,
computes monthly, DOW, and week-of-month (WOM) multipliers, then populates:

  1. seasonal_pattern          — 84 rows (12 months × 7 DOW)
  2. daily_forecast            — 365+ rows per year
  3. product_monthly_multipliers — 12 rows per SKU
  4. product_dow_multipliers     — 7 rows per SKU
  5. product_wom_multipliers     — 48 rows per SKU (12 months × 4 weeks)

The product_*_multipliers tables are cached by mlp_inventory_bridge.py
at runtime for FIFO burn estimation. This script is the ONLY writer —
no hardcoded values anywhere else.

WOM methodology:
  [DATA]   — months with 14+ days: compute from weekly averages
  [FLAT]   — months with <7 days: all 4 weeks = 1.0
  [INTERP] — months with 0 days: average WOM shape from nearest neighbors

Usage:
    python -m Application_env.ai_orchestrator.build_forecast_from_sales --sku 500107
    python -m Application_env.ai_orchestrator.build_forecast_from_sales --sku 500107 --years 2025 2026 2027
    python -m Application_env.ai_orchestrator.build_forecast_from_sales --sku 500107 --all-tables
"""

import argparse
import os
import sys
from datetime import date, timedelta
from collections import defaultdict

import psycopg2

DB_URL = os.environ.get("DATABASE_URL", "postgresql://dev_driver:bread@localhost:5432/ordering_db")

DAY_ABBR = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
MONTH_NAMES = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
               'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

MIN_DAYS_DATA = 14   # Minimum days for [DATA] WOM confidence
MIN_DAYS_LOW = 7     # Minimum days for [LOW] confidence


def compute_seasonal_pattern(cur, sku, store_id):
    """
    Compute monthly and DOW multipliers from daily_sales_log.
    Returns dict of (month, dow_abbr) -> {expected, month_mult, dow_mult, confidence}.
    """
    # Get all sales data
    cur.execute("""
        SELECT sale_date, day_of_week, pieces_sold, month
        FROM daily_sales_log
        WHERE sku = %s AND store_id = %s
        ORDER BY sale_date
    """, (sku, store_id))
    rows = cur.fetchall()

    if not rows:
        print(f"  ERROR: No sales data in daily_sales_log for SKU {sku}")
        return None

    print(f"  Found {len(rows)} daily sales entries")

    # Overall average
    all_sales = [r[2] for r in rows]
    overall_avg = sum(all_sales) / len(all_sales)
    print(f"  Overall average: {overall_avg:.2f}/day")

    # Monthly averages (stored on instance for later use)
    month_sales = defaultdict(list)
    for r in rows:
        month_sales[r[3]].append(r[2])

    month_avgs = {}
    for m in range(1, 13):
        if m in month_sales:
            month_avgs[m] = sum(month_sales[m]) / len(month_sales[m])
        else:
            month_avgs[m] = overall_avg

    # DOW averages
    dow_sales = defaultdict(list)
    for r in rows:
        dow_sales[r[1]].append(r[2])

    dow_avgs = {}
    for d in DAY_ABBR:
        if d in dow_sales:
            dow_avgs[d] = sum(dow_sales[d]) / len(dow_sales[d])
        else:
            dow_avgs[d] = overall_avg

    # Compute multipliers
    month_mults = {}
    for m in range(1, 13):
        month_mults[m] = round(month_avgs[m] / overall_avg, 2) if overall_avg > 0 else 1.0

    dow_mults = {}
    for d in DAY_ABBR:
        dow_mults[d] = round(dow_avgs[d] / overall_avg, 2) if overall_avg > 0 else 1.0

    print(f"\n  Monthly multipliers:")
    for m in range(1, 13):
        data_days = len(month_sales.get(m, []))
        marker = " *estimated" if data_days == 0 else ""
        print(f"    {MONTH_NAMES[m]:>3}: {month_mults[m]:.2f} (avg {month_avgs[m]:.1f}/day, {data_days} days){marker}")

    print(f"\n  DOW multipliers:")
    for d in DAY_ABBR:
        data_days = len(dow_sales.get(d, []))
        print(f"    {d}: {dow_mults[d]:.2f} (avg {dow_avgs[d]:.1f}/day, {data_days} days)")

    # Build pattern: 12 months x 7 DOW
    pattern = {}
    for m in range(1, 13):
        for d in DAY_ABBR:
            expected = round(overall_avg * month_mults[m] * dow_mults[d], 1)
            data_days = len(month_sales.get(m, []))
            if data_days >= MIN_DAYS_DATA:
                confidence = 'high'
            elif data_days >= MIN_DAYS_LOW:
                confidence = 'medium'
            elif data_days > 0:
                confidence = 'low'
            else:
                confidence = 'estimated'

            pattern[(m, d)] = {
                'expected': expected,
                'month_mult': month_mults[m],
                'dow_mult': dow_mults[d],
                'confidence': confidence
            }

    return pattern, overall_avg, month_sales, dow_sales, month_mults, dow_mults


def compute_wom_multipliers(month_sales_raw, overall_avg):
    """
    Compute week-of-month multipliers from raw daily sales data.

    For each month, splits days into 4 weeks (1-7, 8-14, 15-21, 22+),
    computes weekly averages, and divides by the month's overall average.

    Returns:
        wom: dict {month: {week: multiplier}}
        wom_sources: dict {month: 'data'|'flat'|'interp'}
    """
    def get_week(day):
        if day <= 7: return 1
        elif day <= 14: return 2
        elif day <= 21: return 3
        else: return 4

    # Reorganize raw data by month -> week
    month_week_sales = defaultdict(lambda: defaultdict(list))
    month_day_count = defaultdict(int)

    for month, sales_list in month_sales_raw.items():
        month_day_count[month] = len(sales_list)

    # We need the actual sale_date to know which week. The month_sales_raw
    # only has pieces_sold values grouped by month. We need to re-query.
    # Instead, we'll return None and let the caller pass date-keyed data.
    return None, None


def compute_wom_from_rows(rows):
    """
    Compute WOM multipliers from raw (sale_date, pieces_sold, month) rows.

    Returns:
        wom: dict {month: {1: mult, 2: mult, 3: mult, 4: mult}}
        wom_sources: dict {month: 'data'|'flat'|'interp'}
    """
    def get_week(day):
        if day <= 7: return 1
        elif day <= 14: return 2
        elif day <= 21: return 3
        else: return 4

    month_week_sales = defaultdict(lambda: defaultdict(list))
    month_day_count = defaultdict(int)

    for sale_date, pieces_sold, month in rows:
        week = get_week(sale_date.day)
        month_week_sales[month][week].append(pieces_sold)
        month_day_count[month] += 1

    wom = {}
    wom_sources = {}
    data_months = []

    for m in range(1, 13):
        days = month_day_count.get(m, 0)

        if days >= MIN_DAYS_DATA:
            # [DATA] — enough data for reliable WOM
            total_pieces = sum(sum(month_week_sales[m][w]) for w in range(1, 5))
            total_days = sum(len(month_week_sales[m][w]) for w in range(1, 5))
            month_avg = total_pieces / total_days if total_days > 0 else 1.0

            wom[m] = {}
            for w in range(1, 5):
                if month_week_sales[m][w]:
                    week_avg = sum(month_week_sales[m][w]) / len(month_week_sales[m][w])
                    wom[m][w] = round(week_avg / month_avg, 2) if month_avg > 0 else 1.0
                else:
                    wom[m][w] = 1.0
            wom_sources[m] = 'data'
            data_months.append(m)

        elif days > 0:
            # [FLAT] — some data but not enough for reliable weekly split
            wom[m] = {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0}
            wom_sources[m] = 'flat'

        else:
            # No data at all — will be interpolated below
            wom[m] = {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0}
            wom_sources[m] = 'flat'

    # [INTERP] — for months with zero data, average WOM from nearest neighbors
    for m in range(1, 13):
        if month_day_count.get(m, 0) == 0:
            before = None
            after = None
            for candidate in sorted(data_months):
                if candidate < m:
                    before = candidate
            for candidate in sorted(data_months):
                if candidate > m:
                    after = candidate
                    break

            if before and after:
                for w in range(1, 5):
                    wom[m][w] = round((wom[before][w] + wom[after][w]) / 2, 2)
                wom_sources[m] = 'interp'
            elif before:
                wom[m] = dict(wom[before])
                wom_sources[m] = 'interp'
            elif after:
                wom[m] = dict(wom[after])
                wom_sources[m] = 'interp'

    return wom, wom_sources


def save_seasonal_pattern(cur, sku, store_id, pattern, overall_avg, month_sales, dow_sales):
    """Insert/update seasonal_pattern table."""
    rows = []
    for (m, d), p in sorted(pattern.items()):
        data_points = len(month_sales.get(m, []))
        rows.append((sku, store_id, m, d, overall_avg,
                      p['month_mult'], p['dow_mult'], p['expected'],
                      p['confidence'], data_points))

    cur.executemany("""
        INSERT INTO seasonal_pattern
        (sku, store_id, month, day_of_week, base_avg,
         monthly_multiplier, dow_multiplier, expected_daily,
         confidence, data_points)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (sku, store_id, month, day_of_week) DO UPDATE SET
            base_avg = EXCLUDED.base_avg,
            expected_daily = EXCLUDED.expected_daily,
            monthly_multiplier = EXCLUDED.monthly_multiplier,
            dow_multiplier = EXCLUDED.dow_multiplier,
            confidence = EXCLUDED.confidence,
            data_points = EXCLUDED.data_points,
            updated_at = NOW()
    """, rows)

    print(f"\n  Saved {len(rows)} seasonal_pattern entries")
    return len(rows)


def save_product_monthly_multipliers(cur, sku, store_id, month_mults, month_sales):
    """Insert/update product_monthly_multipliers from computed values."""
    count = 0
    for m in range(1, 13):
        data_days = len(month_sales.get(m, []))
        if data_days >= MIN_DAYS_DATA:
            confidence = 'high'
            source = 'data'
        elif data_days >= MIN_DAYS_LOW:
            confidence = 'medium'
            source = 'data'
        elif data_days > 0:
            confidence = 'low'
            source = 'data'
        else:
            confidence = 'estimated'
            source = 'estimated'

        cur.execute("""
            INSERT INTO product_monthly_multipliers
                (sku, store_id, month, multiplier, confidence, source)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (sku, store_id, month) DO UPDATE SET
                multiplier = EXCLUDED.multiplier,
                confidence = EXCLUDED.confidence,
                source = EXCLUDED.source,
                updated_at = NOW()
        """, (sku, store_id, m, month_mults[m], confidence, source))
        count += 1

    print(f"  Saved {count} product_monthly_multipliers entries")
    return count


def save_product_dow_multipliers(cur, sku, store_id, dow_mults, dow_sales):
    """Insert/update product_dow_multipliers from computed values."""
    count = 0
    for dow_idx, dow_name in enumerate(DAY_ABBR):
        data_days = len(dow_sales.get(dow_name, []))
        if data_days >= MIN_DAYS_DATA:
            confidence = 'high'
        elif data_days >= MIN_DAYS_LOW:
            confidence = 'medium'
        else:
            confidence = 'low'

        cur.execute("""
            INSERT INTO product_dow_multipliers
                (sku, store_id, day_of_week, multiplier, confidence, source)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (sku, store_id, day_of_week) DO UPDATE SET
                multiplier = EXCLUDED.multiplier,
                confidence = EXCLUDED.confidence,
                source = EXCLUDED.source,
                updated_at = NOW()
        """, (sku, store_id, dow_idx, dow_mults[dow_name], confidence, 'data'))
        count += 1

    print(f"  Saved {count} product_dow_multipliers entries")
    return count


def save_product_wom_multipliers(cur, sku, store_id, wom, wom_sources):
    """Insert/update product_wom_multipliers from computed values."""
    count = 0
    for m in range(1, 13):
        source = wom_sources.get(m, 'flat')
        for w in range(1, 5):
            cur.execute("""
                INSERT INTO product_wom_multipliers
                    (sku, store_id, month, week, multiplier, source)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (sku, store_id, month, week) DO UPDATE SET
                    multiplier = EXCLUDED.multiplier,
                    source = EXCLUDED.source,
                    updated_at = NOW()
            """, (sku, store_id, m, w, wom[m][w], source))
            count += 1

    print(f"  Saved {count} product_wom_multipliers entries")
    return count


def generate_daily_forecast(cur, sku, store_id, pattern, years):
    """Generate daily_forecast rows from seasonal_pattern."""
    cur.execute("""
        CREATE TABLE IF NOT EXISTS daily_forecast (
            id SERIAL PRIMARY KEY,
            sku VARCHAR(30) NOT NULL,
            store_id VARCHAR(20) NOT NULL DEFAULT '70012004',
            forecast_date DATE NOT NULL,
            day_of_week VARCHAR(10) NOT NULL,
            month INTEGER NOT NULL,
            expected_sales REAL NOT NULL,
            monthly_multiplier REAL NOT NULL DEFAULT 1.0,
            dow_multiplier REAL NOT NULL DEFAULT 1.0,
            confidence VARCHAR(20) DEFAULT 'medium',
            created_at TIMESTAMP DEFAULT NOW(),
            UNIQUE(sku, store_id, forecast_date)
        )
    """)

    total = 0
    for year in years:
        start = date(year, 1, 1)
        end = date(year, 12, 31)
        current = start
        rows = []

        while current <= end:
            m = current.month
            dow = DAY_ABBR[current.weekday()]
            key = (m, dow)

            if key in pattern:
                p = pattern[key]
                rows.append((
                    sku, store_id, current, dow, m,
                    p['expected'], p['month_mult'], p['dow_mult'], p['confidence']
                ))
            current += timedelta(days=1)

        cur.executemany("""
            INSERT INTO daily_forecast
            (sku, store_id, forecast_date, day_of_week, month, expected_sales,
             monthly_multiplier, dow_multiplier, confidence)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (sku, store_id, forecast_date) DO UPDATE SET
                expected_sales = EXCLUDED.expected_sales,
                monthly_multiplier = EXCLUDED.monthly_multiplier,
                dow_multiplier = EXCLUDED.dow_multiplier,
                confidence = EXCLUDED.confidence
        """, rows)

        print(f"  {year}: {len(rows)} daily forecast rows")
        total += len(rows)

    return total


def show_forecast_sample(cur, sku):
    print("\n  --- This Week's Forecast ---")
    cur.execute("""
        SELECT forecast_date, day_of_week, expected_sales, confidence
        FROM daily_forecast
        WHERE sku = %s AND forecast_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 6
        ORDER BY forecast_date
    """, (sku,))
    for r in cur.fetchall():
        print(f"    {r[0]} ({r[1]:>3}): {r[2]:.1f} pieces  [{r[3]}]")

    print("\n  --- Monthly Forecast Summary ---")
    cur.execute("""
        SELECT TO_CHAR(TO_DATE(month::text, 'MM'), 'Mon') AS mon,
               ROUND(AVG(expected_sales)::numeric, 1) AS avg_expected,
               confidence, month
        FROM daily_forecast
        WHERE sku = %s AND EXTRACT(YEAR FROM forecast_date) = EXTRACT(YEAR FROM CURRENT_DATE)
        GROUP BY month, confidence
        ORDER BY month
    """, (sku,))
    for r in cur.fetchall():
        print(f"    {r[0]}: {r[1]} avg/day  [{r[2]}]")


def show_wom_summary(wom, wom_sources):
    """Print WOM multiplier summary."""
    print("\n  --- WOM Multipliers ---")
    for m in range(1, 13):
        src = wom_sources.get(m, 'flat').upper()
        w1, w2, w3, w4 = wom[m][1], wom[m][2], wom[m][3], wom[m][4]
        print(f"    {MONTH_NAMES[m]:>3}: W1={w1:.2f} W2={w2:.2f} W3={w3:.2f} W4={w4:.2f}  [{src}]")


def main():
    parser = argparse.ArgumentParser(description='Build forecast from daily sales log')
    parser.add_argument('--sku', required=True, help='Product SKU')
    parser.add_argument('--store', default='70012004', help='Store ID')
    parser.add_argument('--years', nargs='+', type=int, default=[2025, 2026, 2027],
                        help='Years to generate forecast for')
    args = parser.parse_args()

    print("=" * 60)
    print("  BUILD FORECAST FROM SALES DATA")
    print("=" * 60)
    print(f"  SKU:   {args.sku}")
    print(f"  Store: {args.store}")
    print(f"  Years: {args.years}")
    print(f"  Source: daily_sales_log")
    print(f"  Target tables:")
    print(f"    1. seasonal_pattern           (12 months × 7 DOW)")
    print(f"    2. daily_forecast             (365/yr × {len(args.years)} years)")
    print(f"    3. product_monthly_multipliers (12 rows)")
    print(f"    4. product_dow_multipliers     (7 rows)")
    print(f"    5. product_wom_multipliers     (48 rows)")
    print("=" * 60)

    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()

    # Step 1: Compute monthly + DOW multipliers
    print("\n  Step 1: Computing monthly + DOW multipliers...")
    result = compute_seasonal_pattern(cur, args.sku, args.store)
    if not result:
        cur.close()
        conn.close()
        sys.exit(1)

    pattern, overall_avg, month_sales, dow_sales, month_mults, dow_mults = result

    # Step 2: Compute WOM multipliers from raw date-level data
    print("\n  Step 2: Computing WOM multipliers...")
    cur.execute("""
        SELECT sale_date, pieces_sold, month
        FROM daily_sales_log
        WHERE sku = %s AND store_id = %s
        ORDER BY sale_date
    """, (args.sku, args.store))
    raw_rows = cur.fetchall()
    wom, wom_sources = compute_wom_from_rows(raw_rows)
    show_wom_summary(wom, wom_sources)

    # Step 3: Save seasonal_pattern
    print("\n  Step 3: Saving seasonal_pattern...")
    save_seasonal_pattern(cur, args.sku, args.store, pattern, overall_avg, month_sales, dow_sales)
    conn.commit()

    # Step 4: Save product multiplier tables (bridge reads these)
    print("\n  Step 4: Saving product multiplier tables (bridge runtime)...")
    save_product_monthly_multipliers(cur, args.sku, args.store, month_mults, month_sales)
    save_product_dow_multipliers(cur, args.sku, args.store, dow_mults, dow_sales)
    save_product_wom_multipliers(cur, args.sku, args.store, wom, wom_sources)
    conn.commit()

    # Step 5: Generate daily forecast
    print("\n  Step 5: Generating daily forecast...")
    total = generate_daily_forecast(cur, args.sku, args.store, pattern, args.years)
    conn.commit()

    print(f"\n  Total: {total} daily forecast rows generated")

    show_forecast_sample(cur, args.sku)

    # Summary
    print("\n" + "=" * 60)
    print("  SUMMARY")
    print("=" * 60)
    print(f"  Base avg:          {overall_avg:.2f}/day")
    print(f"  seasonal_pattern:  84 rows")
    print(f"  daily_forecast:    {total} rows")
    print(f"  monthly_mults:     12 rows")
    print(f"  dow_mults:         7 rows")
    print(f"  wom_mults:         48 rows")
    print(f"  All tables sourced from: daily_sales_log ({len(raw_rows)} entries)")
    print("=" * 60)

    cur.close()
    conn.close()
    print("\n  Done.")


if __name__ == "__main__":
    main()
