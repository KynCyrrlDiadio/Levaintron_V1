"""
Weather Forecast Fetcher — Open-Meteo API for Demoville, AB

Fetches 14-day forecast and computes an outdoor_score (0.0-1.0) for
BBQ-adjacent products (hotdogs, hamburger buns, sausage buns).

The outdoor_score is the 9th MLP input for weather-sensitive products.

Encoding:
  - Temperature component: 0.0 below 5°C, linear ramp 5-25°C, 1.0 above 25°C
  - Rain penalty: TWO-FACTOR — probability AND intensity
      prob_penalty = precip_prob / 100
      intensity   = 0.3 (forecast 0mm) → 1.0 (forecast 10mm+)
      rain_factor = 1 - (prob_penalty * intensity)
    A 90% prob of 1mm drizzle dampens less than a 90% prob of 15mm downpour.
  - Snow override: hard floor 0.0 if WMO weathercode indicates snow/freezing

Usage:
    from weather_forecast import WeatherFetcher
    wf = WeatherFetcher()
    forecast = wf.get_forecast()       # 14-day forecast with outdoor scores
    score = wf.get_outdoor_score()     # today's score
    score = wf.get_outdoor_score(3)    # score 3 days from now (lead time)
"""

import json
import urllib.request
from datetime import datetime, timedelta
from typing import Dict, List, Optional

# Demo build: generic central-Alberta coordinates (not a real store location).
DEMO_LAT = 53.5461
DEMO_LON = -113.4938
TIMEZONE = "America/Edmonton"

SNOW_CODES = {
    56, 57,   # freezing drizzle
    66, 67,   # freezing rain
    71, 73, 75, 77,  # snowfall
    85, 86,   # snow showers
}

API_URL = (
    "https://api.open-meteo.com/v1/forecast"
    f"?latitude={DEMO_LAT}&longitude={DEMO_LON}"
    "&daily=temperature_2m_max,temperature_2m_min,"
    "precipitation_probability_max,precipitation_sum,weathercode"
    f"&timezone={TIMEZONE}&forecast_days=14"
)


def compute_outdoor_score(temp_max: float, temp_min: float,
                          precip_prob: float, weathercode: int,
                          precip_mm: float = 0.0) -> float:
    """
    Compute outdoor BBQ score 0.0-1.0 from daily weather parameters.

    temp_max:    daily high °C
    precip_prob: max precipitation probability 0-100
    weathercode: WMO weather code
    precip_mm:   forecast precipitation amount in mm (intensity granularity)
    """
    if weathercode in SNOW_CODES:
        return 0.0

    avg_temp = (temp_max + temp_min) / 2.0

    if avg_temp <= 5.0:
        temp_score = 0.0
    elif avg_temp >= 25.0:
        temp_score = 1.0
    else:
        temp_score = (avg_temp - 5.0) / 20.0

    # Two-factor rain: probability × intensity.
    # Even at 100% probability, a 0mm forecast (false alarm) only takes 30% off.
    # A 100% probability of 10mm+ takes the full prob penalty.
    prob_penalty = precip_prob / 100.0
    intensity = min(1.0, max(0.3, 0.3 + (precip_mm / 10.0) * 0.7))
    rain_factor = 1.0 - (prob_penalty * intensity)

    return round(max(0.0, min(1.0, temp_score * rain_factor)), 3)


class WeatherFetcher:

    def __init__(self):
        self._cache: Optional[Dict] = None
        self._cache_time: Optional[datetime] = None
        self._cache_ttl = timedelta(hours=3)

    def _fetch(self) -> Dict:
        now = datetime.now()
        if self._cache and self._cache_time and (now - self._cache_time) < self._cache_ttl:
            return self._cache

        try:
            req = urllib.request.Request(API_URL, headers={"User-Agent": "LevaintronDemo/1.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode())

            daily = data["daily"]
            forecast = []
            for i in range(len(daily["time"])):
                temp_max = daily["temperature_2m_max"][i]
                temp_min = daily["temperature_2m_min"][i]
                precip_prob = daily["precipitation_probability_max"][i]
                precip_sum = daily["precipitation_sum"][i]
                wcode = daily["weathercode"][i]

                score = compute_outdoor_score(temp_max, temp_min, precip_prob, wcode, precip_sum)

                forecast.append({
                    "date": daily["time"][i],
                    "temp_max": temp_max,
                    "temp_min": temp_min,
                    "precip_probability": precip_prob,
                    "precipitation_mm": precip_sum,
                    "weathercode": wcode,
                    "outdoor_score": score,
                })

            result = {
                "location": "Demoville, AB",
                "latitude": data.get("latitude"),
                "longitude": data.get("longitude"),
                "elevation": data.get("elevation"),
                "fetched_at": now.strftime("%Y-%m-%d %H:%M:%S"),
                "days": forecast,
            }

            self._cache = result
            self._cache_time = now
            return result

        except Exception as e:
            print(f"WeatherFetcher: API call failed: {e}")
            return {"location": "Demoville, AB", "error": str(e), "days": []}

    def get_forecast(self) -> Dict:
        return self._fetch()

    def get_outdoor_score(self, days_ahead: int = 0) -> float:
        forecast = self._fetch()
        days = forecast.get("days", [])
        if days_ahead < len(days):
            return days[days_ahead]["outdoor_score"]
        return 0.5

    def get_scores_for_lead_time(self, lead_time_days: int = 3) -> List[float]:
        forecast = self._fetch()
        days = forecast.get("days", [])
        return [d["outdoor_score"] for d in days[:lead_time_days]]


def generate_outdoor_score_for_training(month: int, temp_noise: float = 3.0) -> float:
    """
    Generate realistic outdoor scores for MLP training data.
    Simulates Alberta weather patterns by month including precipitation amount.

    Returns a score 0.0-1.0 matching real seasonal temperature + rainfall distributions.
    """
    import random

    MONTHLY_TEMP_AVG = {
        1: -12.0, 2: -9.0, 3: -3.0, 4: 5.0,
        5: 11.0, 6: 15.5, 7: 18.0, 8: 17.0,
        9: 12.0, 10: 5.5, 11: -3.0, 12: -10.0,
    }

    MONTHLY_PRECIP_PROB = {
        1: 15, 2: 15, 3: 20, 4: 30,
        5: 35, 6: 45, 7: 40, 8: 35,
        9: 30, 10: 20, 11: 20, 12: 15,
    }

    MONTHLY_SNOW_CHANCE = {
        1: 0.70, 2: 0.60, 3: 0.45, 4: 0.20,
        5: 0.05, 6: 0.00, 7: 0.00, 8: 0.00,
        9: 0.03, 10: 0.15, 11: 0.45, 12: 0.65,
    }

    # Demoville avg per-event rain mm by month — drives intensity granularity.
    # Summer thunderstorms can dump 15mm+; spring/fall is mostly drizzle 1-5mm.
    MONTHLY_AVG_RAIN_MM = {
        1: 1.5, 2: 1.5, 3: 2.0, 4: 3.5,
        5: 6.0, 6: 9.0, 7: 8.0, 8: 7.0,
        9: 5.0, 10: 3.0, 11: 2.0, 12: 1.5,
    }

    base_temp = MONTHLY_TEMP_AVG.get(month, 10.0)
    temp_max = base_temp + random.gauss(5, temp_noise)
    temp_min = base_temp + random.gauss(-2, temp_noise)

    precip_base = MONTHLY_PRECIP_PROB.get(month, 30)
    precip_prob = max(0, min(100, precip_base + random.gauss(0, 15)))

    snow_chance = MONTHLY_SNOW_CHANCE.get(month, 0.0)
    weathercode = 71 if random.random() < snow_chance else 3

    # Generate precip_mm correlated with prob: high prob → likely meaningful rain,
    # low prob → likely 0mm even if a token amount slips through.
    if precip_prob < 20:
        precip_mm = 0.0 if random.random() < 0.85 else round(random.uniform(0, 1.5), 1)
    else:
        avg_mm = MONTHLY_AVG_RAIN_MM.get(month, 4.0)
        # Lognormal-ish: most days near avg, occasional heavy storm
        precip_mm = max(0.0, round(random.gammavariate(2.0, avg_mm / 2.0), 1))

    return compute_outdoor_score(temp_max, temp_min, precip_prob, weathercode, precip_mm)


if __name__ == "__main__":
    print("=" * 60)
    print("WEATHER FORECAST — DEMO REGION, AB")
    print("=" * 60)

    wf = WeatherFetcher()
    forecast = wf.get_forecast()

    if forecast.get("error"):
        print(f"Error: {forecast['error']}")
    else:
        print(f"\nFetched at: {forecast['fetched_at']}")
        print(f"Location: {forecast['location']} (elev {forecast['elevation']}m)\n")
        print(f"{'Date':<12} {'High':>5} {'Low':>5} {'Precip%':>7} {'Rain mm':>7} {'WMO':>4} {'Score':>6}")
        print("-" * 52)
        for d in forecast["days"]:
            print(f"{d['date']:<12} {d['temp_max']:>5.1f} {d['temp_min']:>5.1f} "
                  f"{d['precip_probability']:>6}% {d['precipitation_mm']:>6.1f} "
                  f"{d['weathercode']:>4} {d['outdoor_score']:>6.3f}")

    print("\n\nTraining data outdoor scores by month (10 samples each):")
    print("-" * 40)
    for m in range(1, 13):
        scores = [generate_outdoor_score_for_training(m) for _ in range(100)]
        avg = sum(scores) / len(scores)
        print(f"  Month {m:2d}: avg={avg:.3f}  range=[{min(scores):.3f}, {max(scores):.3f}]")
