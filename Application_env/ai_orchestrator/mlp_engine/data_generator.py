"""
Training Data Generator for Bread MLP

Generates synthetic training data with SEASONAL SINE WAVE patterns:
- Winter (Jan-Feb): HIGH demand (4-5 loaves/day base)
- Summer (Jun-Aug): LOW demand (1-2 loaves/day base)
- Uses inverted cosine wave matching your simulator

STOCK-AWARE Decision Logic (12-day shelf life constraint):
- Calculates "days of inventory" = stock / daily_sales_rate
- ORDER 0: >8 days of inventory OR stock >25 (risk of expiration)
- ORDER 20: <2 days of inventory OR stock <3 (critical stockout emergency)
- ORDER 10: <4 days of inventory OR stock <8 (risk of stockout)
- ORDER 5: 4-8 days of inventory (healthy buffer)

Target: Maintain 5-8 days of inventory to prevent both:
  1. Stockouts (lost sales)
  2. Expiration (bread hitting 12-day limit)

For use in the Levaintron demo project.
"""
import random
import math
from dataclasses import dataclass
from typing import List, Tuple
import numpy as np


@dataclass
class TrainingSample:
    """Single training sample with seasonal awareness."""
    current_inventory: int
    day_of_week: int
    hour_of_day: int
    recent_sales_rate: float
    weather_score: float
    is_holiday: bool
    day_of_year: int
    decision: int


def get_seasonal_multiplier(day_of_year: int) -> float:
    """
    Calculate seasonal demand multiplier using inverted sine wave.

    Pattern (matches your bread simulator):
    - Peak demand: Winter (around day 15 = mid-January)
    - Low demand: Summer (around day 196 = mid-July)

    Returns: 0.6 (summer) to 1.4 (winter)
    """
    phase_shift = 80
    seasonal = 0.5 * (1 + math.cos(2 * math.pi * (day_of_year - phase_shift) / 365))
    return 0.6 + 0.8 * seasonal


def get_base_sales_rate(day_of_year: int) -> float:
    """
    Get base sales rate for a given day of year.

    Uses seasonal multiplier to create realistic yearly pattern:
    - Winter: ~4-5 loaves/day
    - Summer: ~1-2 loaves/day
    - Spring/Fall: ~2-3 loaves/day
    """
    seasonal_mult = get_seasonal_multiplier(day_of_year)
    base = 2.5
    return base * seasonal_mult + random.gauss(0, 0.3)


def get_correct_decision(
        current_inventory: int,
        day_of_week: int,
        hour_of_day: int,
        recent_sales_rate: float,
        weather_score: float,
        is_holiday: bool
) -> int:
    """
    Calculate the correct ordering decision based on observable features.

    This is the target function the MLP learns to approximate.

    KEY CONSTRAINT: Bread has 12-day shelf life!
    - If stock / daily_sales > 10 days, we're over-stocked
    - Target: keep 5-10 days of inventory (safety buffer + freshness)

    Decision Rules (STOCK-AWARE for 12-day shelf life):
    - ORDER 0: High inventory that would exceed 10 days supply
    - ORDER 20: Critical stockout emergency (<2 days inventory OR stock <3)
    - ORDER 10: Low inventory (<8) OR high demand with low stock
    - ORDER 5: Moderate situations
    """
    demand_multiplier = 1.0

    is_peak_hour = (7 <= hour_of_day <= 10) or (12 <= hour_of_day <= 14)
    if is_peak_hour:
        demand_multiplier *= 1.3

    if day_of_week in (1, 2, 3):
        demand_multiplier *= 0.7
    elif day_of_week in (4, 5, 6):
        demand_multiplier *= 1.3
    else:
        demand_multiplier *= 0.85

    if is_holiday:
        demand_multiplier *= 1.5

    demand_multiplier *= (0.6 + 0.4 * weather_score)

    effective_sales_rate = max(0.5, recent_sales_rate * demand_multiplier)

    days_of_inventory = current_inventory / effective_sales_rate

    if days_of_inventory > 10:
        return 0

    if days_of_inventory > 8:
        return 0

    if current_inventory > 25:
        return 0

    if current_inventory < 3 or days_of_inventory < 2:
        return 20

    if days_of_inventory < 4:
        return 10

    if current_inventory < 8:
        return 10

    if effective_sales_rate > 3.5 and current_inventory < 18:
        return 10

    if days_of_inventory < 6:
        return 5

    return 5


def generate_training_sample(day_of_year: int = None) -> TrainingSample:
    """
    Generate a single training sample with SEASONAL patterns.

    If day_of_year is provided, uses that for seasonal calculation.
    Otherwise, picks a random day of year.
    """
    if day_of_year is None:
        day_of_year = random.randint(1, 365)

    day_of_week = random.randint(0, 6)
    hour_of_day = random.randint(6, 20)

    recent_sales_rate = max(0.5, get_base_sales_rate(day_of_year))

    seasonal_mult = get_seasonal_multiplier(day_of_year)
    if seasonal_mult > 1.1:
        weather_score = random.uniform(0.3, 0.8)
    else:
        weather_score = random.uniform(0.6, 1.0)

    is_holiday = random.random() < 0.05
    if day_of_year in range(355, 366) or day_of_year in range(1, 3):
        is_holiday = random.random() < 0.4

    if random.random() < 0.08:
        current_inventory = random.randint(0, 2)
    elif random.random() < 0.10:
        current_inventory = random.randint(3, 5)
    elif random.random() < 0.08:
        current_inventory = random.randint(6, 7)
    else:
        base_inventory = 15
        seasonal_inventory_adj = (1 - seasonal_mult) * 10
        current_inventory = max(1, min(45, int(
            base_inventory + seasonal_inventory_adj + random.gauss(0, 5)
        )))

    decision = get_correct_decision(
        current_inventory, day_of_week, hour_of_day,
        recent_sales_rate, weather_score, is_holiday
    )

    return TrainingSample(
        current_inventory=current_inventory,
        day_of_week=day_of_week,
        hour_of_day=hour_of_day,
        recent_sales_rate=round(recent_sales_rate, 2),
        weather_score=round(weather_score, 3),
        is_holiday=is_holiday,
        day_of_year=day_of_year,
        decision=decision
    )


def generate_training_data(count: int = 500, full_year_coverage: bool = True) -> List[TrainingSample]:
    """
    Generate multiple training samples.

    If full_year_coverage=True, ensures samples from all 365 days.
    This gives the model exposure to all seasonal patterns.
    """
    samples = []

    if full_year_coverage:
        samples_per_day = max(1, count // 365)
        for day in range(1, 366):
            for _ in range(samples_per_day):
                samples.append(generate_training_sample(day_of_year=day))

        while len(samples) < count:
            samples.append(generate_training_sample())
    else:
        samples = [generate_training_sample() for _ in range(count)]

    random.shuffle(samples)
    return samples[:count]


def samples_to_tensors(samples: List[TrainingSample]) -> Tuple[np.ndarray, np.ndarray]:
    """Convert samples to numpy arrays for training."""
    X = np.array([
        [
            s.current_inventory / 50.0,
            s.day_of_week / 6.0,
            s.hour_of_day / 23.0,
            s.recent_sales_rate / 6.0,
            s.weather_score,
            float(s.is_holiday)
        ]
        for s in samples
    ], dtype=np.float32)

    decision_to_class = {0: 0, 5: 1, 10: 2, 20: 3}
    y = np.array([decision_to_class[s.decision] for s in samples], dtype=np.int64)

    return X, y


def get_class_distribution(samples: List[TrainingSample]) -> dict:
    """Get distribution of decision classes in samples."""
    counts = {0: 0, 5: 0, 10: 0, 20: 0}
    for s in samples:
        counts[s.decision] += 1
    total = len(samples)
    return {k: f"{v} ({v / total * 100:.1f}%)" for k, v in counts.items()}


def get_seasonal_distribution(samples: List[TrainingSample]) -> dict:
    """Get distribution of samples by season."""
    seasons = {
        "Winter (Dec-Feb)": [12, 1, 2],
        "Spring (Mar-May)": [3, 4, 5],
        "Summer (Jun-Aug)": [6, 7, 8],
        "Fall (Sep-Nov)": [9, 10, 11]
    }

    counts = {s: 0 for s in seasons}
    for sample in samples:
        month = ((sample.day_of_year - 1) // 30) % 12 + 1
        for season_name, months in seasons.items():
            if month in months:
                counts[season_name] += 1
                break

    total = len(samples)
    return {k: f"{v} ({v / total * 100:.1f}%)" for k, v in counts.items()}


if __name__ == "__main__":
    print("=" * 60)
    print("SEASONAL TRAINING DATA GENERATOR")
    print("Using sine wave pattern: Winter HIGH, Summer LOW")
    print("=" * 60)

    print("\nSeasonal multiplier examples:")
    for day, name in [(15, "Jan 15 (Winter)"), (105, "Apr 15 (Spring)"),
                      (196, "Jul 15 (Summer)"), (288, "Oct 15 (Fall)")]:
        mult = get_seasonal_multiplier(day)
        base_rate = get_base_sales_rate(day)
        print(f"  {name}: multiplier={mult:.2f}, base_sales={base_rate:.2f}")

    print("\nGenerating 10,000 training samples with full year coverage...")
    samples = generate_training_data(10000, full_year_coverage=True)

    print(f"\nClass distribution:")
    for decision, count in get_class_distribution(samples).items():
        print(f"  Order {decision}: {count}")

    print(f"\nSeasonal distribution:")
    for season, count in get_seasonal_distribution(samples).items():
        print(f"  {season}: {count}")

    print(f"\nSample entries by season:")
    for day, name in [(15, "Winter"), (196, "Summer")]:
        sample = generate_training_sample(day_of_year=day)
        print(f"  {name}: inv={sample.current_inventory}, sales={sample.recent_sales_rate:.1f}, "
              f"decision={sample.decision}")

    X, y = samples_to_tensors(samples)
    print(f"\nFeatures shape: {X.shape}")
    print(f"Labels shape: {y.shape}")
