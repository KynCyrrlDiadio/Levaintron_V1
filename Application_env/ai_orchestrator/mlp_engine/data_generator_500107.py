"""
Seasonal-Aware Training Data Generator for Demo_500g_Rye_Bread MLP v10.0

Adapted from data_generator_seasonal.py for:
  - SKU 500107 (Demo_500g_Rye_Bread)
  - Tray Factor 9 → ORDER classes: [0, 9, 18, 27, 36] (5 classes)
  - Higher base sales (~12.8/day avg vs ~5.5/day for white bread)
  - Seasonal multipliers derived from actual the demo store sales data
  - Interpolated multipliers for Mar/Apr from cubic spline

Features (8 inputs - same architecture as white bread MLP):
  [0] current_inventory / 80.0    (higher ceiling for rye volume)
  [1] day_of_week / 6.0
  [2] expected_daily_sales / 25.0  (scaled for rye's higher demand)
  [3] actual_sales_rate / 25.0
  [4] monthly_multiplier           (~0.77-1.47)
  [5] is_holiday                   (0 or 1)
  [6] pipeline_incoming / 150.0    (wider range for better pipeline resolution)
  [7] returns_rate / 20.0          (recent return rate 0-15%)

Lead time: 7 days (vs 3 for white bread) — must plan further ahead

Decision philosophy (TF 9, 5 classes — v10.0):
  - ORDER 0:  Well-stocked (effective > 60 or days > 7) OR very high returns
  - ORDER 9:  Light top-up (1 tray) — moderate stock with pipeline, low season,
              or high returns with adequate coverage. Fills the gap between
              ORDER 0 (nothing) and ORDER 18 (2 full trays) to reduce overstock.
              ONLY used when stock+pipeline gives 4-6 days coverage — never when
              days_eff < 4 (under-ordering risk) or > 6 (should cancel).
  - ORDER 18: Standard sustaining order (2 trays, matches ~12.8/day demand)
  - ORDER 27: High demand / moderate urgency (3 trays)
  - ORDER 36: Emergency / peak season / critically low stock (4 trays)
"""
import random
import math
from dataclasses import dataclass
from typing import List, Tuple
import numpy as np


MONTHLY_MULTIPLIERS_RYE = {
    1: 1.50, 2: 1.15, 3: 0.72, 4: 0.91,
    5: 1.10, 6: 0.79, 7: 0.99, 8: 1.03,
    9: 1.12, 10: 0.94, 11: 1.04, 12: 0.91
}

DOW_MULTIPLIERS_RYE = {
    0: 0.98, 1: 1.14, 2: 0.89, 3: 0.92,
    4: 1.06, 5: 0.96, 6: 1.05
}

BASE_SALES_RYE = 12.51

ORDER_CLASSES_RYE = [0, 9, 18, 27, 36]

# Week-of-month multipliers — intra-month demand variance from daily_sales_log
WEEK_OF_MONTH_MULTIPLIERS_RYE = {
    1:  {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00},  # Jan [FLAT]
    2:  {1: 1.30, 2: 1.10, 3: 0.64, 4: 0.55},  # Feb [DATA]
    3:  {1: 1.00, 2: 0.74, 3: 0.97, 4: 1.25},  # Mar [DATA]
    4:  {1: 1.15, 2: 0.92, 3: 0.80, 4: 0.90},  # Apr [INTERP Feb+Mar]
    5:  {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00},  # May [FLAT]
    6:  {1: 0.99, 2: 0.87, 3: 0.97, 4: 1.16},  # Jun [DATA]
    7:  {1: 0.94, 2: 1.34, 3: 0.87, 4: 0.91},  # Jul [DATA]
    8:  {1: 1.31, 2: 0.73, 3: 0.96, 4: 0.99},  # Aug [DATA]
    9:  {1: 0.87, 2: 1.00, 3: 1.13, 4: 1.01},  # Sep [DATA]
    10: {1: 0.96, 2: 0.97, 3: 1.00, 4: 1.12},  # Oct [DATA]
    11: {1: 0.97, 2: 0.93, 3: 1.31, 4: 1.00},  # Nov [DATA]
    12: {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00},  # Dec [FLAT]
}


def get_week_of_month(day: int) -> int:
    if day <= 7: return 1
    elif day <= 14: return 2
    elif day <= 21: return 3
    else: return 4


@dataclass
class RyeTrainingSample:
    current_inventory: int
    day_of_week: int
    expected_daily_sales: float
    actual_sales_rate: float
    monthly_multiplier: float
    is_holiday: bool
    pipeline_incoming: int
    returns_rate: float
    decision: int


def get_expected_sales_rye(month: int, dow: int, day_of_month: int = 15) -> float:
    monthly_mult = MONTHLY_MULTIPLIERS_RYE.get(month, 1.0)
    dow_mult = DOW_MULTIPLIERS_RYE.get(dow, 1.0)
    week = get_week_of_month(day_of_month)
    week_mult = WEEK_OF_MONTH_MULTIPLIERS_RYE.get(month, {}).get(week, 1.0)
    base = BASE_SALES_RYE * monthly_mult * dow_mult * week_mult
    return round(base + random.gauss(0, 0.5), 1)


def generate_returns_rate() -> float:
    r = random.random()
    if r < 0.40:
        return round(random.uniform(0.0, 2.0), 1)
    elif r < 0.70:
        return round(random.uniform(2.0, 5.0), 1)
    elif r < 0.85:
        return round(random.uniform(5.0, 8.0), 1)
    elif r < 0.95:
        return round(random.uniform(8.0, 12.0), 1)
    else:
        return round(random.uniform(12.0, 15.0), 1)


def get_correct_decision_rye(
    current_inventory: int,
    expected_daily_sales: float,
    actual_sales_rate: float,
    monthly_multiplier: float,
    is_holiday: bool,
    day_of_week: int,
    pipeline_incoming: int,
    returns_rate: float = 0.0
) -> int:
    """
    Decision logic for NB 500 Rye (TF 9) — v11.0 HYBRID.

    Derived from reference production model weight dissection + v6 overstock fixes.
    Reference insight: ORDER 18 is the workhorse (days_eff 2.5-6.0), ORDER 9 is
    a narrow transition band (5.5-6.5 days_eff). Peak season skips ORDER 9/18
    entirely — goes ORDER 36/27 → ORDER 0.

    v6 insight: normal cancel_threshold=90 + mid-stock trim at effective_stock>=55
    cuts overstock from 97→52 days.

    ORDER classes: [0, 9, 18, 27, 36]
    Demand ~12.8/day avg, 4 deliveries/week.
    Lead time: 7 days.
    """
    effective_demand = max(1.0, expected_daily_sales)
    if is_holiday:
        effective_demand *= 1.4

    effective_stock = current_inventory + pipeline_incoming
    days_eff = effective_stock / effective_demand
    days_cur = current_inventory / effective_demand

    peak_season = monthly_multiplier > 1.1
    low_season = monthly_multiplier < 0.85
    high_demand = effective_demand >= 12.0
    very_high_demand = effective_demand >= 15.0

    high_returns = returns_rate > 8.0
    very_high_returns = returns_rate > 12.0

    # ═══ ORDER 0 — cancel (v6 thresholds) ═══════════════════════
    if low_season:
        cancel_threshold = 95
        cancel_days = 8
    elif peak_season:
        cancel_threshold = 90
        cancel_days = 7
    else:
        cancel_threshold = 90
        cancel_days = 7
    if effective_stock > cancel_threshold or days_eff > cancel_days:
        return 0

    # Reference: cancel when both inv and pipeline are heavy
    if current_inventory > 45 and pipeline_incoming > 35:
        return 0
    if current_inventory > 35 and pipeline_incoming > 45:
        return 0

    # Returns-based cancel
    if very_high_returns and days_eff > 5.5:
        return 0

    # ═══ ORDER 36 — emergency (reference: days_eff < 1.4) ════════
    if current_inventory == 0 and pipeline_incoming == 0:
        return 36
    if current_inventory == 0 and pipeline_incoming < 18:
        return 36
    if current_inventory < 5 and pipeline_incoming < 9:
        return 36

    # Peak emergencies — Reference model orders 36 up to days_eff ~3.0
    if peak_season and days_eff < 2.5:
        return 36
    if peak_season and monthly_multiplier > 1.3 and current_inventory < 15 and pipeline_incoming < 18:
        return 36

    # ═══ PEAK SEASON — tightened to reduce Apr/Sep overstock ════
    if peak_season:
        # Mid-stock trim in peak — catch overstock before it builds
        if effective_stock >= 50 and days_eff > 3.5:
            return 9
        # ORDER 27 from days_eff 2.5-3.0
        if days_eff < 3.0:
            return 27
        # Barely-peak: ORDER 18 from 3.0+
        if monthly_multiplier < 1.2 and days_eff < 5.5:
            return 18
        # High peak: ORDER 27 up to 3.5
        if days_eff < 3.5:
            return 27
        # ORDER 9 transition for peak: days_eff 4.5+
        if days_eff > 4.5:
            return 9
        # days_eff 3.5-4.5 in peak → ORDER 18
        return 18

    # ═══ LOW SEASON — Reference model leans heavy on ORDER 18 ══════════
    if low_season:
        # Emergency: low stock in slow months
        if current_inventory < 10 and pipeline_incoming < 27:
            return 27
        # Reference: ORDER 27 when days_eff < 3.0
        if days_eff < 3.0:
            return 27
        # ORDER 9 narrow band: days_eff 5.5-6.5 (reference pattern)
        if 5.5 <= days_eff <= 6.5:
            return 9
        # ORDER 18 dominates: days_eff 3.0-5.5 (reference workhorse)
        return 18

    # ═══ NORMAL SEASON — reference + v6 mid-stock trim ═══════════

    # ORDER 27: days_eff < 3.0 (reference boundary)
    if current_inventory < 10 and pipeline_incoming < 18:
        return 27
    if days_eff < 3.0:
        return 27
    if current_inventory < 15 and pipeline_incoming < 27 and high_demand:
        return 27

    # v6 mid-stock trim — prevents Aug/Sep/Oct overstock buildup
    if effective_stock >= 50 and days_eff > 4.2:
        return 9

    # High returns trim
    if high_returns and days_eff > 4.2:
        return 9

    # Normal season: ORDER 18 for days_eff 3.0-4.2, ORDER 9 for 4.2+
    if days_eff > 4.2:
        return 9

    # ORDER 18: days_eff 3.0-4.2
    return 18


def generate_pipeline_incoming_rye():
    r = random.random()
    if r < 0.15:
        return 0
    elif r < 0.35:
        return random.choice([18, 27])
    elif r < 0.60:
        return random.choice([18, 27, 36])
    elif r < 0.80:
        return random.choice([27, 36, 45])
    else:
        return random.choice([36, 54, 72])


def generate_rye_sample(month: int = None, dow: int = None) -> RyeTrainingSample:
    if month is None:
        month = random.randint(1, 12)
    if dow is None:
        dow = random.randint(0, 6)
    day_of_month = random.randint(1, 28)

    monthly_mult = MONTHLY_MULTIPLIERS_RYE.get(month, 1.0)
    expected_sales = get_expected_sales_rye(month, dow, day_of_month)

    noise = random.gauss(0, 2.0)
    actual_sales = max(1.0, expected_sales + noise)

    is_holiday = random.random() < 0.05
    if month == 12 and random.random() < 0.3:
        is_holiday = True
    if month == 7 and random.random() < 0.15:
        is_holiday = True

    pipeline_incoming = generate_pipeline_incoming_rye()
    returns_rate = generate_returns_rate()

    r = random.random()
    if r < 0.05:
        current_inventory = random.randint(0, 3)
    elif r < 0.10:
        current_inventory = random.randint(4, 10)
    elif r < 0.20:
        current_inventory = random.randint(35, 65)
    elif r < 0.30:
        current_inventory = random.randint(25, 50)
    elif r < 0.55:
        current_inventory = random.randint(15, 35)
    elif r < 0.75:
        current_inventory = random.randint(10, 25)
    else:
        base = max(5, int(expected_sales * random.uniform(1.5, 3.5)))
        current_inventory = max(1, min(75, base + random.randint(-5, 5)))

    decision = get_correct_decision_rye(
        current_inventory, expected_sales, actual_sales,
        monthly_mult, is_holiday, dow, pipeline_incoming,
        returns_rate
    )

    return RyeTrainingSample(
        current_inventory=current_inventory,
        day_of_week=dow,
        expected_daily_sales=round(expected_sales, 2),
        actual_sales_rate=round(actual_sales, 2),
        monthly_multiplier=round(monthly_mult, 3),
        is_holiday=is_holiday,
        pipeline_incoming=pipeline_incoming,
        returns_rate=round(returns_rate, 1),
        decision=decision
    )


def generate_rye_training_data(count: int = 50000) -> List[RyeTrainingSample]:
    samples = []
    samples_per_combo = max(1, count // (12 * 7))

    for month in range(1, 13):
        for dow in range(7):
            for _ in range(samples_per_combo):
                samples.append(generate_rye_sample(month=month, dow=dow))

    while len(samples) < count:
        samples.append(generate_rye_sample())

    random.shuffle(samples)
    return samples[:count]


def rye_samples_to_tensors(samples: List[RyeTrainingSample]) -> Tuple[np.ndarray, np.ndarray]:
    """
    Convert to tensors with rye-specific normalization (v9.0).

    Features (MUST match inference):
      [0] inventory / 80.0          (higher ceiling for rye)
      [1] day_of_week / 6.0
      [2] expected_daily_sales / 25.0  (higher demand range)
      [3] actual_sales_rate / 25.0
      [4] monthly_multiplier
      [5] is_holiday (0 or 1)
      [6] pipeline_incoming / 150.0  (wider range for pipeline resolution)
      [7] returns_rate / 20.0
    """
    X = np.array([
        [
            s.current_inventory / 80.0,
            s.day_of_week / 6.0,
            s.expected_daily_sales / 25.0,
            s.actual_sales_rate / 25.0,
            s.monthly_multiplier,
            float(s.is_holiday),
            s.pipeline_incoming / 150.0,
            s.returns_rate / 20.0,
        ]
        for s in samples
    ], dtype=np.float32)

    decision_to_class = {0: 0, 9: 1, 18: 2, 27: 3, 36: 4}
    y = np.array([decision_to_class[s.decision] for s in samples], dtype=np.int64)

    return X, y


def get_rye_class_distribution(samples: List[RyeTrainingSample]) -> dict:
    counts = {0: 0, 9: 0, 18: 0, 27: 0, 36: 0}
    for s in samples:
        counts[s.decision] += 1
    total = len(samples)
    return {k: f"{v} ({v/total*100:.1f}%)" for k, v in counts.items()}


if __name__ == "__main__":
    print("=" * 60)
    print("RYE BREAD TRAINING DATA GENERATOR v10.0 (TF 9)")
    print("SKU 500107 — Demo_500g_Rye_Bread")
    print("Order classes: [0, 9, 18, 27, 36]  (5 classes)")
    print("Pipeline norm: /150")
    print("=" * 60)

    print("\nExpected sales by month (Monday):")
    for month in range(1, 13):
        sales = get_expected_sales_rye(month, 0)
        mult = MONTHLY_MULTIPLIERS_RYE[month]
        print(f"  Month {month:2d}: expected={sales:.1f}/day, multiplier={mult:.2f}")

    print("\nGenerating 50,000 rye training samples...")
    samples = generate_rye_training_data(50000)

    print(f"\nClass distribution:")
    for decision, count in get_rye_class_distribution(samples).items():
        print(f"  Order {decision}: {count}")

    X, y = rye_samples_to_tensors(samples)
    print(f"\nFeatures shape: {X.shape}  (8 features)")
    print(f"Labels shape: {y.shape}")

    print("\nSample entries:")
    for s in samples[:8]:
        print(f"  inv={s.current_inventory:3d}, expected={s.expected_daily_sales:.1f}, "
              f"pipeline={s.pipeline_incoming:2d}, returns={s.returns_rate:.1f}%, "
              f"mult={s.monthly_multiplier:.2f}, decision=ORDER {s.decision}")
