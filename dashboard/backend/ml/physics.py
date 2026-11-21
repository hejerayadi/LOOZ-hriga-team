"""Physics and agronomy formulas used by the features.

The dataset generators (almond_stress_dataset.py, the frost generator) were NOT
given with the notebooks: these formulas were rebuilt from the notebooks, the
column names and the values of the 5 complete rows printed by
frost_prediction.ipynb (cell 4). Each one says how close it is (see
docs/ml_features.md and tests/test_ml_features.py).
"""
from __future__ import annotations

import math
from datetime import date

SIGMA = 5.670374419e-8  # Stefan-Boltzmann (W m-2 K-4)


def es_kpa(t_c: float) -> float:
    """Saturation vapour pressure (kPa), Tetens / FAO-56: matches vpd_dec_kpa of the rows exactly."""
    return 0.6108 * math.exp(17.27 * t_c / (t_c + 237.3))


def dew_point_c(t_c: float, rh_pct: float) -> float:
    """Dew point (°C), Magnus (17.625, 243.04): within 0.003 °C of td_dec_c of the rows."""
    rh = min(max(rh_pct, 1.0), 100.0)
    g = math.log(rh / 100.0) + 17.625 * t_c / (243.04 + t_c)
    return 243.04 * g / (17.625 - g)


def vpd_kpa(t_c: float, rh_pct: float) -> float:
    return es_kpa(t_c) * (1 - min(max(rh_pct, 0.0), 100.0) / 100.0)


def sky_emissivity_clear(t_c: float, td_c: float) -> float:
    """Brutsaert (1975) clear-sky emissivity: 1.24 (e/T)^(1/7), e in hPa (actual vapour pressure)."""
    e_hpa = 10 * es_kpa(td_c)
    return 1.24 * (e_hpa / (t_c + 273.15)) ** (1 / 7)


def lnet_clear_wm2(t_c: float, emissivity: float) -> float:
    """Net long-wave loss of a clear night: sigma T^4 (0.97 - emissivity) (matches the rows to 0.01 W/m2)."""
    return SIGMA * (t_c + 273.15) ** 4 * (0.97 - emissivity)


def brunt_cooling_c(lnet: float, hours_left: float, vwc: float) -> float:
    """Brunt's clear-night cooling: 2 Lnet sqrt(t) / (sqrt(pi) mu), t = hours from the decision time to
    sunrise. mu (soil thermal admittance) = 2169 + 6265 vwc was FITTED on the 5 rows (sand,
    within 0.5 %): an approximation for the other soils."""
    mu = 2169.0 + 6265.0 * max(vwc, 0.0)
    return 2.0 * lnet * math.sqrt(max(hours_left, 0.5) * 3600.0) / (math.sqrt(math.pi) * mu)


def declination(doy: int) -> float:
    return 0.409 * math.sin(2 * math.pi * doy / 365 - 1.39)


def day_length_h(lat_deg: float, doy: int) -> float:
    """FAO-56 day length (no refraction). Night length = 24 - this (0.03 h from the rows)."""
    phi = math.radians(lat_deg)
    x = max(-1.0, min(1.0, -math.tan(phi) * math.tan(declination(doy))))
    return 24.0 / math.pi * math.acos(x)


def solar_noon_local_h(lon_deg: float = 10.2) -> float:
    """Clock hour of solar noon in Tunisia (UTC+1, no summer time)."""
    return 12.0 + (15.0 - lon_deg) / 15.0


def sunset_local_h(lat_deg: float, doy: int, lon_deg: float = 10.2) -> float:
    return solar_noon_local_h(lon_deg) + day_length_h(lat_deg, doy) / 2


def ra_mm_day(lat_deg: float, doy: int) -> float:
    """Extraterrestrial radiation (FAO-56 eq. 21), in mm/day of water (x 0.408)."""
    phi = math.radians(lat_deg)
    dr = 1 + 0.033 * math.cos(2 * math.pi * doy / 365)
    d = declination(doy)
    ws = math.acos(max(-1.0, min(1.0, -math.tan(phi) * math.tan(d))))
    ra = 24 * 60 / math.pi * 0.0820 * dr * (ws * math.sin(phi) * math.sin(d) + math.cos(phi) * math.cos(d) * math.sin(ws))
    return 0.408 * ra


def et0_hargreaves_mm(tmax: float, tmin: float, tmean: float, lat_deg: float, doy: int) -> float:
    """Hargreaves-Samani reference evapotranspiration (mm/day)."""
    return max(0.0, 0.0023 * ra_mm_day(lat_deg, doy) * (tmean + 17.8) * math.sqrt(max(tmax - tmin, 0.0)))


# ---------- the season of the almond tree ----------
def bloom_start_for(day: date, mmdd: str) -> date:
    """The first day of bloom of the season that contains `day` (bloom in Jan-Mar: from August,
    the next bloom counts)."""
    month, d = (int(x) for x in mmdd.split("-"))
    year = day.year + 1 if day.month >= 8 else day.year
    return date(year, month, d)


def days_from_bloom_start(day: date, mmdd: str) -> int:
    return (day - bloom_start_for(day, mmdd)).days


def frost_stage(days_from_bloom: int) -> str:
    """Stages of the frost model. Lengths fitted to the share of rows of each stage in the
    frost notebook's scaler (pink bud 14 days, bloom 30, small nut 37)."""
    if -14 <= days_from_bloom < 0:
        return "pink_bud"
    if 0 <= days_from_bloom < 30:
        return "bloom"
    if 30 <= days_from_bloom < 67:
        return "small_nut"
    return "dormant_or_other"


# Critical temperatures (10 % kill) of the frost model, chosen so their weighted mean matches the
# scaler mean of critical_temp_c (-2.16 °C over the sensitive rows).
CRITICAL_TEMP = {"pink_bud": -3.3, "bloom": -2.2, "small_nut": -1.7}


def stress_stage(day: date, days_from_bloom: int) -> str:
    """Stages of the stress model (Tunisian almond calendar, approximation)."""
    md = (day.month, day.day)
    if 0 <= days_from_bloom < 30:
        return "bloom"
    if 30 <= days_from_bloom < 67:
        return "fruit_set"
    if days_from_bloom >= 67 and md < (5, 20):
        return "fruit_growth"
    if (5, 20) <= md <= (7, 15):
        return "kernel_fill"
    if (7, 16) <= md <= (8, 31):
        return "hull_split"
    if (9, 1) <= md <= (10, 31):
        return "postharvest"
    if (11, 1) <= md <= (11, 30):
        return "leaf_fall"
    return "dormant"


def leaf_on(day: date, days_from_bloom: int) -> bool:
    """Leaves out from about 20 days after the start of bloom to mid-November."""
    if day.month == 12 or (day.month == 11 and day.day > 15):
        return False
    if day.month <= 4 and days_from_bloom < 20:
        return False
    return True


def kc_fao(day: date, days_from_bloom: int) -> float:
    """FAO-56 almond Kc (ini 0.40, mid 0.90, end 0.65), stages 20 / 60 / 120 / 60 days from leaf-out."""
    if not leaf_on(day, days_from_bloom):
        return 0.40
    d = days_from_bloom - 20
    if d < 0:  # (bloom in late winter: leaves counted from the next season)
        d += 365
    if d < 20:
        return 0.40
    if d < 80:
        return 0.40 + (0.90 - 0.40) * (d - 20) / 60
    if d < 200:
        return 0.90
    if d < 260:
        return 0.90 + (0.65 - 0.90) * (d - 200) / 60
    return 0.65


def ground_cover_factor(cover: float) -> float:
    """Keller-Karmeli reduction of crop water use for a partial canopy: min(1, cover / 0.85)."""
    return min(1.0, max(cover, 0.05) / 0.85)


def swp_baseline_bar(vpd_midday: float) -> float:
    """Almond stem water potential of a well-watered tree (bar), linear in the midday VPD.
    Fitted to the medians of the stress model's imputer (-6.20 bar at 1.75 kPa)."""
    return -0.4 - 3.3 * vpd_midday
