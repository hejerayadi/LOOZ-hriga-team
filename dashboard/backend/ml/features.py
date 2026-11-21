"""From the raw readings of a sensor box (+ the farm context) to the features of
the two models.

The generators of the datasets (almond_stress_dataset.py daily_features() and
the frost generator) were NOT in AI_modules_time_series/: everything here was
rebuilt from the notebooks, the feature lists and fences of the bundles and the
5 complete rows printed by the frost notebook. docs/ml_features.md lists every
feature with how it is computed and how sure we are.

Input: the history points of the box ([epoch s, soil %, soil °C, air °C,
air %, light ADC, piezo RMS, piezo events/h, number of faults], see
ml_worker_history in migration 019), one point per hour (demo) or per
15 minutes (real boxes). They are put on an HOURLY grid in Tunisia time
(UTC+1, no summer time).

- Stress (a DAILY model): "today" = the last 24 hours before the latest
  reading (so a prediction can run at every 15-minute step), the days before =
  calendar days (for the 3, 7 and 14-day features).
- Frost (trained for the decision 2 h after sunset): the "night" is tonight
  (from 9:00) or the night going on (before 9:00). Its "_dec" values are the
  LATEST reading, at any hour (decision of the user: every 15 minutes, all day
  long). Outside the evening the inputs are outside what the model learned.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone

import numpy as np
import pandas as pd

from . import physics as P

TUNIS = timezone(timedelta(hours=1))
COLS = ["vwc", "tsoil", "tair", "rh", "light", "prms", "pev"]
DHT_RH_CAP = 90.0      # the DHT11 of the datasets never reads more (quartile 3 of rh_max = 90)
DHT_RH_FLOOR = 20.0    # its lowest humidity
DHT_T_FLOOR = 0.0      # the DHT11 reads 0 °C at most low (frost = hours at this floor)
LIGHT_DAY = 50         # ADC above this: daylight
LIGHT_SAT = 4000       # ADC from this: the light sensor is saturated (full sun)
MIN_STRESS_HOURS = 20  # valid hours needed in the last 24 h
MIN_FROST_HOURS = 20   # valid hours needed in the last 26 h (last night + today)


def hourly(points: list[list], now_utc: datetime | None = None) -> pd.DataFrame:
    """History points -> one row per local hour (mean of the readings of that hour), impossible
    values removed (DS18B20 85 / -127, out of range), missing hours kept as empty rows."""
    if not points:
        return pd.DataFrame(columns=COLS, dtype=float)
    a = pd.DataFrame(points, columns=["t", "sm", "tsoil", "tair", "rh", "light", "prms", "pev", "nf"])
    a = a.apply(pd.to_numeric, errors="coerce")
    a["vwc"] = a["sm"] / 100.0
    a.loc[~a["sm"].between(0.5, 70), "vwc"] = np.nan
    a.loc[a["tsoil"].isin([85.0, -127.0]) | ~a["tsoil"].between(-20, 60), "tsoil"] = np.nan
    a.loc[~a["tair"].between(-40, 60), "tair"] = np.nan
    a.loc[~a["rh"].between(0, 100), "rh"] = np.nan
    a.loc[~a["light"].between(0, 4095), "light"] = np.nan
    a.loc[a["prms"] < 0, "prms"] = np.nan
    a.loc[a["pev"] < 0, "pev"] = np.nan
    local = pd.to_datetime(a["t"], unit="s", utc=True).dt.tz_convert(TUNIS).dt.tz_localize(None)
    a["hour"] = local.dt.floor("h")
    h = a.groupby("hour")[COLS].mean()
    full = pd.date_range(h.index.min(), h.index.max(), freq="h")
    return h.reindex(full)


def _rew(vwc, ctx):
    return (vwc - ctx["theta_wp"]) / (ctx["theta_fc"] - ctx["theta_wp"])


def _mean(s):
    s = s.dropna()
    return float(s.mean()) if len(s) else np.nan


def _max(s):
    s = s.dropna()
    return float(s.max()) if len(s) else np.nan


def _min(s):
    s = s.dropna()
    return float(s.min()) if len(s) else np.nan


def _at_hour(w: pd.DataFrame, hours: list[int], col: str) -> float:
    return _mean(w.loc[w.index.hour.isin(hours), col])


# ---------- stress: one day ----------
def day_features(w: pd.DataFrame, ctx: dict, day: date) -> dict:
    """The daily features of one 24-hour window (no 3/7/14-day features, no orchard features)."""
    f: dict = {}
    valid = w[["vwc", "tsoil", "tair", "rh"]].notna().all(axis=1)
    f["n_valid_hours"] = int(valid.sum())
    rise = w["vwc"].diff()
    f["vwc_max_rise_1h"] = _max(rise)
    for col, name in [("tsoil", "tsoil"), ("tair", "tair"), ("rh", "rh")]:
        f[f"{name}_mean"], f[f"{name}_max"], f[f"{name}_min"] = _mean(w[col]), _max(w[col]), _min(w[col])
    vpd = pd.Series([P.vpd_kpa(t, r) if pd.notna(t) and pd.notna(r) else np.nan for t, r in zip(w["tair"], w["rh"])],
                    index=w.index)
    daylight = (w["light"] > LIGHT_DAY) if w["light"].notna().any() else pd.Series(w.index.hour.isin(range(7, 19)), index=w.index)
    midday = pd.Series(w.index.hour.isin([12, 13, 14]), index=w.index)
    night = pd.Series(w.index.hour.isin([0, 1, 2, 3, 4]), index=w.index)
    f["vpd_max_kpa"] = _max(vpd)
    f["vpd_day_kpa"] = _mean(vpd[daylight])
    f["vpd_midday_kpa"] = _mean(vpd[midday])
    f["vpd_night_kpa"] = _mean(vpd[night])
    f["dht_missing_hours"] = int((w["tair"].isna() | w["rh"].isna()).sum())
    f["light_mean_adc"] = _mean(w["light"])
    f["light_hours"] = int((w["light"] > LIGHT_DAY).sum())
    f["light_saturated_hours"] = int((w["light"] >= LIGHT_SAT).sum())
    f["piezo_rate_day"] = _mean(w["pev"][daylight])
    f["piezo_rate_midday"] = _mean(w["pev"][midday])
    f["piezo_rate_night"] = _mean(w["pev"][night])
    f["piezo_rms_midday"] = _mean(w["prms"][midday])
    f["piezo_max"] = _max(w["pev"])
    t = w["tair"]
    f["hours_above_35"] = int((t >= 35).sum())
    f["hours_above_40"] = int((t >= 40).sum())
    f["degree_hours_above_35"] = float((t - 35).clip(lower=0).sum())
    f["tair_floor_hours"] = int((t <= DHT_T_FLOOR).sum())
    f["tair_below_0_hours"] = int((t <= 0).sum())
    f["rh_floor_hours"] = int((w["rh"] <= DHT_RH_FLOOR).sum())
    f["tsoil_amp"] = f["tsoil_max"] - f["tsoil_min"]
    f["tsoil_minus_tair"] = f["tsoil_mean"] - f["tair_mean"]
    f["latitude"] = ctx["latitude"]
    f["ground_cover_frac"] = ctx["ground_cover_frac"]
    f["irrigation_water_ec_dsm"] = ctx.get("irrigation_water_ec_dsm")
    f["irrigation_system"] = ctx["irrigation_system"]
    doy = day.timetuple().tm_yday
    f["doy_sin"], f["doy_cos"] = math.sin(2 * math.pi * doy / 365.25), math.cos(2 * math.pi * doy / 365.25)
    dfb = P.days_from_bloom_start(day, ctx["bloom_start"])
    f["pheno_stage"] = ctx.get("pheno_stage_override") or P.stress_stage(day, dfb)
    f["kc_fao"] = P.kc_fao(day, dfb)
    f["leaf_on"] = P.leaf_on(day, dfb)
    tmax, tmin, tmean = f["tair_max"], f["tair_min"], f["tair_mean"]
    f["et0_hs_mm"] = P.et0_hargreaves_mm(tmax, tmin, tmean, ctx["latitude"], doy) if pd.notna(tmax) else np.nan
    f["etc_hs_mm"] = f["et0_hs_mm"] * f["kc_fao"] * P.ground_cover_factor(ctx["ground_cover_frac"])
    f["p_adj"] = min(0.8, max(0.1, 0.4 + 0.04 * (5 - f["etc_hs_mm"]))) if pd.notna(f["etc_hs_mm"]) else np.nan
    vwc_pre = _at_hour(w, [5], "vwc")
    if np.isnan(vwc_pre):
        vwc_pre = _at_hour(w, [4, 6], "vwc")
    f["rew_predawn"] = _rew(vwc_pre, ctx)
    f["rew_mean"] = _rew(_mean(w["vwc"]), ctx)
    f["depletion_frac"] = 1 - f["rew_predawn"]
    f["below_raw"] = int(pd.notna(f["depletion_frac"]) and pd.notna(f["p_adj"]) and f["depletion_frac"] > f["p_adj"])
    vmax = _max(w["vwc"])
    f["sat_ratio_max"] = vmax / ctx["theta_sat"]
    f["excess_frac_max"] = (vmax - ctx["theta_fc"]) / (ctx["theta_sat"] - ctx["theta_fc"])
    near = ctx["theta_fc"] + 0.5 * (ctx["theta_sat"] - ctx["theta_fc"])
    f["hours_near_saturation"] = int((w["vwc"] >= near).sum())
    f["swp_baseline_bar"] = P.swp_baseline_bar(f["vpd_midday_kpa"]) if pd.notna(f["vpd_midday_kpa"]) else np.nan
    f["wetting_event"] = int(pd.notna(f["vwc_max_rise_1h"]) and f["vwc_max_rise_1h"] >= 0.005)
    depth_mm = 1000 * ctx.get("root_depth_m", 0.6)
    f["water_in_mm"] = float((rise - 0.003).clip(lower=0).sum() * 300)
    v = w["vwc"].dropna()
    if f["wetting_event"] or not f["leaf_on"] or len(v) < 12:
        f["drawdown_day_mm"] = np.nan        # water use cannot be measured on wetting days / in winter
    else:
        f["drawdown_day_mm"] = float((v.iloc[0] - v.iloc[-1]) * depth_mm)
    etc = f["etc_hs_mm"]
    f["drawdown_per_etc"] = f["drawdown_day_mm"] / etc if pd.notna(f["drawdown_day_mm"]) and etc and etc > 0.1 else np.nan
    if pd.notna(f["drawdown_day_mm"]):
        drainage = max(0.0, _mean(w["vwc"]) - ctx["theta_fc"]) * depth_mm * 0.5
        f["uptake_est_mm"] = f["drawdown_day_mm"] - drainage
        f["uptake_per_etc"] = f["uptake_est_mm"] / etc if etc and etc > 0.1 else np.nan
    else:
        f["uptake_est_mm"] = np.nan
        f["uptake_per_etc"] = np.nan
    f["piezo_day_night_diff"] = f["piezo_rate_day"] - f["piezo_rate_night"]
    f["piezo_wind_adj"] = f["piezo_rate_midday"] / (1 + f["piezo_rms_midday"]) \
        if pd.notna(f["piezo_rate_midday"]) and pd.notna(f["piezo_rms_midday"]) else np.nan
    f["rain_api_mm"] = np.nan          # no weather service connected yet: "missing" (flag = 1)
    f["irrigation_logged_mm"] = 0.0    # the farmer's journal is not connected yet
    return f


def stress_row(h: pd.DataFrame, ctx: dict) -> tuple[dict | None, str]:
    """The stress features of the last 24 h of one box (+ its previous days). (row, status)."""
    if h.empty:
        return None, "not_enough_data"
    end = h.index.max()
    today = h.loc[end - pd.Timedelta(hours=23): end]
    if today[["vwc", "tsoil", "tair", "rh"]].notna().all(axis=1).sum() < MIN_STRESS_HOURS:
        return None, "not_enough_data"
    day = end.date()
    f = day_features(today, ctx, day)
    # previous calendar days (before the 24-h window), newest first
    past: list[dict] = []
    for k in range(1, 14):
        d = (end - pd.Timedelta(hours=23)).normalize() - pd.Timedelta(days=k)
        w = h.loc[d: d + pd.Timedelta(hours=23)]
        if w[["vwc", "tair"]].notna().all(axis=1).sum() >= 12:
            past.append(day_features(w, ctx, d.date()))
    last3, last7 = [f] + past[:2], [f] + past[:6]

    def agg(rows, key, how):
        vals = [r[key] for r in rows if pd.notna(r.get(key))]
        if not vals:
            return np.nan
        return {"min": min, "max": max, "sum": sum, "mean": lambda v: sum(v) / len(v)}[how](vals)

    f["rew_min_7d"] = agg(last7, "rew_predawn", "min")
    f["hours_near_sat_3d"] = agg(last3, "hours_near_saturation", "sum")
    f["hours_above_35_3d"] = agg(last3, "hours_above_35", "sum")
    f["vpd_max_3d"] = agg(last3, "vpd_max_kpa", "max")
    f["piezo_midday_7d"] = agg(last7, "piezo_rate_midday", "mean")
    f["drawdown_per_etc_7d"] = agg(last7, "drawdown_per_etc", "mean")
    f["uptake_per_etc_7d"] = agg(last7, "uptake_per_etc", "mean")
    f["tsoil_amp_7d"] = agg(last7, "tsoil_amp", "mean")
    hist14 = [r["piezo_rate_midday"] for r in past[:14] if pd.notna(r.get("piezo_rate_midday"))]
    if len(hist14) >= 3 and pd.notna(f["piezo_rate_midday"]):
        sd = float(np.std(hist14))
        f["piezo_z14"] = (f["piezo_rate_midday"] - float(np.mean(hist14))) / max(sd, 0.25)
    else:
        f["piezo_z14"] = np.nan        # no history yet (the notebook fills 0)
    f["days_since_wetting"] = 0 if f["wetting_event"] else next(
        (i + 1 for i, r in enumerate(past) if r.get("wetting_event")), len(past) + 1)
    f["water_balance_7d_mm"] = sum((r["water_in_mm"] or 0) - (r["etc_hs_mm"] if pd.notna(r["etc_hs_mm"]) else 0)
                                   for r in last7)
    f["vwc_predawn_trend_3d"] = np.nan  # (dropped by the model: absolute soil columns)
    f["vwc_predawn_delta_1d"] = np.nan
    return f, "ok"


VS_ORCHARD = {"rew_predawn": "rew_predawn_vs_orchard", "drawdown_per_etc_7d": "drawdown_per_etc_7d_vs_orchard",
              "uptake_per_etc_7d": "uptake_per_etc_7d_vs_orchard", "piezo_wind_adj": "piezo_wind_adj_vs_orchard",
              "tsoil_amp": "tsoil_amp_vs_orchard", "hours_near_saturation": "hours_near_saturation_vs_orchard"}


def add_vs_orchard(rows: dict[str, dict]) -> None:
    """Each box minus the median of the boxes of the same orchard (0 with a single box)."""
    for key, out in VS_ORCHARD.items():
        vals = [r[key] for r in rows.values() if r is not None and pd.notna(r.get(key))]
        med = float(np.median(vals)) if vals else np.nan
        for r in rows.values():
            if r is not None:
                r[out] = (r[key] - med) if pd.notna(r.get(key)) and pd.notna(med) else (0.0 if len(vals) <= 1 else np.nan)


# ---------- frost ----------
@dataclass
class NightInfo:
    night_date: date              # the evening the night starts
    sunset_h: float
    night_length_h: float
    after_sunset: bool
    notes: list[str] = field(default_factory=list)


def _night(end: pd.Timestamp, ctx: dict) -> NightInfo:
    d = end.date() - timedelta(days=1) if end.hour < 9 else end.date()
    doy = d.timetuple().tm_yday
    sunset = P.sunset_local_h(ctx["latitude"], doy)
    nl = 24 - P.day_length_h(ctx["latitude"], doy)
    after = end.hour < 9 or (end.hour + 0.5) >= sunset
    return NightInfo(d, sunset, nl, after)


def frost_row(h: pd.DataFrame, ctx: dict) -> tuple[dict | None, str, NightInfo | None]:
    """The frost features at the latest reading. (row, status, night)."""
    if h.empty:
        return None, "not_enough_data", None
    end = h.index.max()
    last26 = h.loc[end - pd.Timedelta(hours=25): end]
    if last26[["tair", "rh", "tsoil", "vwc"]].notna().all(axis=1).sum() < MIN_FROST_HOURS:
        return None, "not_enough_data", None
    now = h.loc[end]
    if any(pd.isna(now[c]) for c in ["tair", "rh", "tsoil", "vwc"]):
        return None, "not_enough_data", None
    n = _night(end, ctx)
    base = pd.Timestamp(n.night_date)
    sunset_ts = base + pd.Timedelta(hours=math.floor(n.sunset_h))

    def at(ts, col):
        return h[col].get(ts, np.nan) if ts in h.index else np.nan

    t, rh = float(now["tair"]), float(now["rh"])
    td = P.dew_point_c(t, rh)
    f: dict = {"t_dec_c": t, "rh_dec_pct": rh, "td_dec_c": td, "dewpoint_depression_dec": t - td}
    if n.after_sunset:
        t_sun, rh_sun = at(sunset_ts, "tair"), at(sunset_ts, "rh")
        if pd.isna(t_sun):
            t_sun, rh_sun = t, rh
    else:
        t_sun, rh_sun = t, rh       # daytime: the evening has not come yet
    f["t_sunset_c"], f["rh_sunset_pct"] = float(t_sun), float(rh_sun)
    f["cooling_since_sunset"] = float(t_sun - t) if n.after_sunset else 0.0
    prev = at(end - pd.Timedelta(hours=1), "tair")
    f["cooling_last_hour"] = float(prev - t) if pd.notna(prev) else 0.0
    day_w = h.loc[base + pd.Timedelta(hours=6): base + pd.Timedelta(hours=math.floor(n.sunset_h))]
    prev_day_w = h.loc[base - pd.Timedelta(hours=18): base - pd.Timedelta(days=1) + pd.Timedelta(hours=math.floor(n.sunset_h))]
    last_night = h.loc[base - pd.Timedelta(days=1) + pd.Timedelta(hours=math.floor(n.sunset_h)): base + pd.Timedelta(hours=9)]
    f["t_max_today_c"] = _max(day_w["tair"]) if day_w["tair"].notna().any() else t
    f["t_min_last_night_c"] = _min(last_night["tair"]) if last_night["tair"].notna().any() else t
    f["last_night_floor_hours"] = int((last_night["tair"] <= DHT_T_FLOOR).sum())
    pmax = _max(prev_day_w["tair"])
    f["tmax_change_1d"] = f["t_max_today_c"] - pmax if pd.notna(pmax) else 0.0
    f["rh_min_today"] = _min(day_w["rh"]) if day_w["rh"].notna().any() else rh
    f["rh_at_sensor_cap"] = float(rh >= DHT_RH_CAP)
    noon = h.loc[base + pd.Timedelta(hours=12): base + pd.Timedelta(hours=13)]
    td_noon = [P.dew_point_c(a, b) for a, b in zip(noon["tair"], noon["rh"]) if pd.notna(a) and pd.notna(b)]
    f["td_change_since_noon"] = td - float(np.mean(td_noon)) if td_noon else 0.0
    t24, rh24 = at(end - pd.Timedelta(hours=24), "tair"), at(end - pd.Timedelta(hours=24), "rh")
    f["td_change_1d"] = td - P.dew_point_c(t24, rh24) if pd.notna(t24) and pd.notna(rh24) else 0.0
    f["vpd_dec_kpa"] = P.vpd_kpa(t, rh)
    f["tsoil_dec_c"] = float(now["tsoil"])
    f["tsoil_max_today"] = _max(day_w["tsoil"]) if day_w["tsoil"].notna().any() else f["tsoil_dec_c"]
    f["tsoil_minus_tair_dec"] = f["tsoil_dec_c"] - t
    vwc = float(now["vwc"])
    f["vwc_dec"] = vwc
    f["sat_ratio_dec"] = vwc / ctx["theta_sat"]
    f["rew_dec"] = _rew(vwc, ctx)
    lit = day_w["light"][day_w["light"] > LIGHT_DAY]
    f["light_day_mean_adc"] = float(lit.mean()) if len(lit) else _mean(day_w["light"])
    f["light_saturated_hours"] = int((day_w["light"] >= LIGHT_SAT).sum())
    ls = at(base + pd.Timedelta(hours=math.floor(n.sunset_h - 0.5)), "light")
    f["light_sunset_adc"] = float(ls) if pd.notna(ls) else 4000.0
    f["piezo_rms_dec"] = float(now["prms"]) if pd.notna(now["prms"]) else np.nan
    evening = h.loc[sunset_ts: end] if n.after_sunset else h.loc[end: end]
    f["piezo_rms_evening"] = _mean(evening["prms"])
    f["piezo_rms_day"] = _mean(day_w["prms"])
    eps = P.sky_emissivity_clear(t, td)
    f["sky_emissivity_clear"] = eps
    f["lnet_clear_wm2"] = P.lnet_clear_wm2(t, eps)
    f["brunt_clear_cooling_c"] = P.brunt_cooling_c(f["lnet_clear_wm2"], n.night_length_h - 2, vwc)
    f["brunt_clear_tmin_c"] = t - f["brunt_clear_cooling_c"]
    f["night_length_h"] = n.night_length_h
    dfb = P.days_from_bloom_start(n.night_date, ctx["bloom_start"])
    stage = P.frost_stage(dfb)
    f["pheno_stage"] = stage
    f["critical_temp_c"] = P.CRITICAL_TEMP.get(stage, np.nan)
    f["days_from_bloom_start"] = dfb
    f["latitude"], f["elevation_m"] = ctx["latitude"], ctx["elevation_m"]
    f["theta_fc"], f["theta_wp"], f["theta_sat"] = ctx["theta_fc"], ctx["theta_wp"], ctx["theta_sat"]
    doy = n.night_date.timetuple().tm_yday
    f["doy_sin"], f["doy_cos"] = math.sin(2 * math.pi * doy / 365.25), math.cos(2 * math.pi * doy / 365.25)
    f["floor_is_cover_crop"] = int(bool(ctx.get("cover_crop")))
    f["position_code"] = {"low": -1, "mid": 0, "high": 1}.get(ctx.get("node_position", "mid"), 0)
    f["soil_type"] = ctx["soil_type"]
    for k in ["piezo_rms_dec", "piezo_rms_evening", "piezo_rms_day"]:
        if pd.isna(f[k]):
            f[k] = 3.5               # no piezo reading: a typical value (training mean 3.5-5.5)
    return f, "ok", n
