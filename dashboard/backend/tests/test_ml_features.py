"""The features rebuilt from the raw readings (the dataset generators were not given):
the formulas against the 5 complete rows of the frost notebook, the hourly grid, the
24-hour stress window, the frost night, the season stages."""
import json
import math
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from ml import features as F
from ml import physics as P

FIX = json.loads((Path(__file__).parent / "ml_fixtures" / "sim_history.json").read_text())
# t, rh, td, dewpoint depression, vpd, emissivity, lnet, brunt cooling, vwc (rows 0-4 of the notebook)
ROWS = [(21, 67, 14.6407, 6.3593, 0.8207, 0.8228, 62.4751, 5.9775, 0.043),
        (22, 72, 16.7202, 5.2798, 0.7403, 0.8382, 56.7044, 5.5305, 0.036),
        (22, 73, 16.9375, 5.0625, 0.7139, 0.8399, 55.9930, 5.2285, 0.053),
        (21, 70, 15.3209, 5.6791, 0.7461, 0.8280, 60.2826, 5.6820, 0.049),
        (22, 67, 15.5920, 6.4080, 0.8725, 0.8296, 60.3938, 5.8734, 0.037)]
CTX = dict(soil_type="sandy_loam", theta_fc=0.25, theta_wp=0.11, theta_sat=0.44, node_position="low",
           irrigation_system="drip", ground_cover_frac=0.45, cover_crop=False, root_depth_m=0.6, bloom_start="01-20",
           latitude=34.74, elevation_m=20, irrigation_water_ec_dsm=None)


@pytest.mark.parametrize("t, rh, td, dd, vpd, eps, lnet, cool, vwc", ROWS)
def test_physics_matches_the_notebook_rows(t, rh, td, dd, vpd, eps, lnet, cool, vwc):
    assert abs(P.dew_point_c(t, rh) - td) < 0.01
    assert abs(t - P.dew_point_c(t, rh) - dd) < 0.01
    assert abs(P.vpd_kpa(t, rh) - vpd) < 0.001
    e = P.sky_emissivity_clear(t, td)
    assert abs(e - eps) < 0.001
    assert abs(P.lnet_clear_wm2(t, eps) - lnet) < 0.05
    night = 13.8953
    assert abs(P.brunt_cooling_c(lnet, night - 2, vwc) - cool) / cool < 0.01     # fitted on these rows (sand)


def test_night_length_close_to_the_notebook():
    # doy 319, latitude 34.72: 13.8953 h in the dataset
    assert abs((24 - P.day_length_h(34.72, 319)) - 13.8953) < 0.06
    assert abs(math.sin(2 * math.pi * 319 / 365.25) - (-0.7143)) < 0.001


def test_stages_of_the_season():
    assert P.days_from_bloom_start(date(2022, 11, 15), "01-20") == -66          # the notebook's first row
    assert P.frost_stage(-66) == "dormant_or_other" and P.frost_stage(-3) == "pink_bud"
    assert P.frost_stage(29) == "bloom" and P.frost_stage(30) == "small_nut" and P.frost_stage(67) == "dormant_or_other"
    assert P.CRITICAL_TEMP == {"pink_bud": -3.3, "bloom": -2.2, "small_nut": -1.7}
    assert P.stress_stage(date(2026, 6, 15), P.days_from_bloom_start(date(2026, 6, 15), "01-20")) == "kernel_fill"
    assert P.stress_stage(date(2027, 2, 18), 29) == "bloom"
    assert P.stress_stage(date(2026, 8, 10), 200) == "hull_split"
    assert P.stress_stage(date(2026, 12, 10), -40) == "dormant"
    assert P.leaf_on(date(2026, 6, 15), 146) and not P.leaf_on(date(2027, 1, 5), -15)
    assert P.kc_fao(date(2026, 12, 10), -40) == 0.40 and 0.85 <= P.kc_fao(date(2026, 6, 15), 146) <= 0.9


def _pts(hours, start=datetime(2026, 6, 14, 0, tzinfo=timezone.utc) - timedelta(hours=1), **over):
    out = []
    for i in range(hours):
        t = start + timedelta(hours=i)
        local_h = (t.hour + 1) % 24
        tair = 27 + 9 * math.cos(2 * math.pi * (local_h - 15) / 24)
        p = [int(t.timestamp()), 22.0 - 0.1 * (i % 24), 22.0, round(tair), 55, 4095 if 8 <= local_h <= 17 else 0,
             4.0, 1.0, 0]
        for k, v in over.items():
            p[{"sm": 1, "tsoil": 2, "tair": 3, "rh": 4}[k]] = v(i, local_h) if callable(v) else v
        out.append(p)
    return out


def test_hourly_grid_removes_impossible_values_and_keeps_gaps():
    pts = _pts(6)
    pts[1][2] = 85.0          # DS18B20 power-on value
    pts[2][2] = -127.0        # DS18B20 disconnected
    pts[3][1] = 101           # impossible soil moisture
    del pts[4]                # a missing hour
    h = F.hourly(pts)
    assert len(h) == 6 and h.index[0].hour == 0                     # Tunisia time (UTC+1), every hour
    assert np.isnan(h["tsoil"].iloc[1]) and np.isnan(h["tsoil"].iloc[2]) and np.isnan(h["vwc"].iloc[3])
    assert h.iloc[4].isna().all()
    assert abs(h["vwc"].iloc[0] - 0.22) < 1e-9                       # % -> m3/m3


def test_stress_window_needs_20_valid_hours():
    assert F.stress_row(F.hourly(_pts(10)), CTX) == (None, "not_enough_data")
    row, st = F.stress_row(F.hourly(_pts(24)), CTX)
    assert st == "ok" and row["n_valid_hours"] == 24


def test_stress_day_features():
    row, _ = F.stress_row(F.hourly(_pts(49)), CTX)     # the last 24 h: 01:00 .. 00:00 (with the midnight wetting)
    assert row["hours_above_35"] == sum(1 for h in range(24) if round(27 + 9 * math.cos(2 * math.pi * (h - 15) / 24)) >= 35)
    assert row["light_saturated_hours"] == 10 and row["light_hours"] == 10
    # predawn = the 05:00 reading: 22.0 - 0.1 * 5 = 21.5 %
    assert abs(row["rew_predawn"] - ((0.215 - 0.11) / (0.25 - 0.11))) < 1e-6
    assert abs(row["depletion_frac"] - (1 - row["rew_predawn"])) < 1e-12
    assert row["wetting_event"] == 1                                 # 19.7 -> 22.0 % at midnight: a wetting
    assert 0.1 <= row["p_adj"] <= 0.8 and row["pheno_stage"] == "kernel_fill" and row["leaf_on"]
    assert np.isnan(row["rain_api_mm"]) and row["irrigation_logged_mm"] == 0.0
    assert np.isnan(row["drawdown_day_mm"])                          # a wetting day: water use not measured


def test_vs_orchard_is_the_difference_to_the_median():
    rows = {"a": {"rew_predawn": 0.2, "drawdown_per_etc_7d": np.nan, "uptake_per_etc_7d": np.nan,
                  "piezo_wind_adj": 0.1, "tsoil_amp": 4.0, "hours_near_saturation": 0},
            "b": {"rew_predawn": 0.6, "drawdown_per_etc_7d": np.nan, "uptake_per_etc_7d": np.nan,
                  "piezo_wind_adj": 0.3, "tsoil_amp": 5.0, "hours_near_saturation": 2},
            "c": {"rew_predawn": 0.8, "drawdown_per_etc_7d": np.nan, "uptake_per_etc_7d": np.nan,
                  "piezo_wind_adj": 0.2, "tsoil_amp": 6.0, "hours_near_saturation": 0}}
    F.add_vs_orchard(rows)
    assert abs(rows["a"]["rew_predawn_vs_orchard"] - (0.2 - 0.6)) < 1e-12
    assert rows["b"]["hours_near_saturation_vs_orchard"] == 2
    one = {"a": dict(rows["a"])}
    F.add_vs_orchard(one)
    assert one["a"]["rew_predawn_vs_orchard"] == 0.0                 # a single box: no comparison


def test_frost_daytime_and_evening():
    pts = FIX["frost"]["NODE-04"]
    h = F.hourly(pts)
    noon = h.loc[: pd.Timestamp("2027-02-18 12:00")]
    row, st, night = F.frost_row(noon, CTX)
    assert st == "ok" and not night.after_sunset and row["cooling_since_sunset"] == 0.0
    assert row["pheno_stage"] == "bloom" and row["critical_temp_c"] == -2.2 and row["days_from_bloom_start"] == 29
    assert row["position_code"] == -1 and row["soil_type"] == "sandy_loam"
    eve = h.loc[: pd.Timestamp("2027-02-18 21:00")]
    row, st, night = F.frost_row(eve, CTX)
    assert night.after_sunset and night.night_date == date(2027, 2, 18) and 17 < night.sunset_h < 19
    assert row["cooling_since_sunset"] > 0 and row["t_dec_c"] < row["t_sunset_c"]
    assert abs(row["brunt_clear_tmin_c"] - (row["t_dec_c"] - row["brunt_clear_cooling_c"])) < 1e-9
    late = h.loc[: pd.Timestamp("2027-02-19 04:00")]
    row, st, night = F.frost_row(late, CTX)
    assert night.night_date == date(2027, 2, 18)                     # before 9:00 = the night going on


def test_frost_needs_history():
    h = F.hourly(FIX["frost"]["NODE-01"][:10])
    assert F.frost_row(h, CTX)[1] == "not_enough_data"
