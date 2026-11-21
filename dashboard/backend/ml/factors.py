"""SHAP values -> the main reasons in farmer words.

Every feature of the two models belongs to ONE factor code (migration 019,
ml_factor_codes()). The app never shows a feature name: it shows the text of
the code (ARB files) with its level ("low" / "high", from the value compared
with the training mean / median). Codes marked "same" have one text whatever
the level.

The SHAP values of the features of a code are added up, then turned towards
the predicted state (frost model: towards "frost" if a frost risk is
predicted, else towards "no frost"; stress model: the predicted class): the
codes that push towards the predicted state are the reasons, the biggest first.
"""
from __future__ import annotations

import re

import numpy as np
import pandas as pd

# feature -> (code, inverted): inverted = a HIGH value means the "low" text of the code.
FROST_FEATURES: dict[str, tuple[str, bool]] = {
    "t_dec_c": ("evening_temp", False), "rh_dec_pct": ("air_humidity", False), "td_dec_c": ("dew_point", False),
    "dewpoint_depression_dec": ("dew_point", True), "t_sunset_c": ("evening_temp", False),
    "rh_sunset_pct": ("air_humidity", False), "cooling_since_sunset": ("cooling_fast", False),
    "cooling_last_hour": ("cooling_fast", False), "t_max_today_c": ("air_heat", False),
    "t_min_last_night_c": ("night_cold", False), "last_night_floor_hours": ("night_cold", True),
    "tmax_change_1d": ("air_heat", False), "rh_min_today": ("air_humidity", False),
    "rh_at_sensor_cap": ("air_humidity", False), "td_change_since_noon": ("dew_point", False),
    "td_change_1d": ("dew_point", False), "vpd_dec_kpa": ("air_dryness", False), "tsoil_dec_c": ("soil_temp", False),
    "tsoil_max_today": ("soil_temp", False), "tsoil_minus_tair_dec": ("soil_temp", False),
    "vwc_dec": ("soil_water", False), "sat_ratio_dec": ("soil_water", False), "rew_dec": ("soil_water", False),
    "light_day_mean_adc": ("sunlight", False), "light_saturated_hours": ("sunlight", False),
    "light_sunset_adc": ("sunlight", False), "piezo_rms_dec": ("tree_sounds", False),
    "piezo_rms_evening": ("tree_sounds", False), "piezo_rms_day": ("tree_sounds", False),
    "sky_emissivity_clear": ("clear_sky", True), "lnet_clear_wm2": ("clear_sky", False),
    "brunt_clear_cooling_c": ("cooling_fast", False), "brunt_clear_tmin_c": ("night_low_expected", False),
    "night_length_h": ("season_stage", False), "critical_temp_c": ("season_stage", False),
    "days_from_bloom_start": ("season_stage", False), "latitude": ("zone_place", False),
    "elevation_m": ("zone_place", False), "theta_fc": ("soil_type", False), "theta_wp": ("soil_type", False),
    "theta_sat": ("soil_type", False), "doy_sin": ("season_stage", False), "doy_cos": ("season_stage", False),
    "floor_is_cover_crop": ("ground_cover", False), "position_code": ("zone_place", False),
    "sensitive_stage": ("season_stage", False),
}
for _f in ["soil_clay", "soil_clay_loam", "soil_loam", "soil_loamy_sand", "soil_sand", "soil_sandy_loam"]:
    FROST_FEATURES[_f] = ("soil_type", False)
for _f in ["stage_bloom", "stage_dormant_or_other", "stage_pink_bud", "stage_small_nut"]:
    FROST_FEATURES[_f] = ("season_stage", False)

STRESS_FEATURES: dict[str, tuple[str, bool]] = {
    "n_valid_hours": ("data_quality", False), "vwc_max_rise_1h": ("watering", False),
    "tsoil_mean": ("soil_temp", False), "tsoil_min": ("soil_temp", False), "tsoil_max": ("soil_temp", False),
    "tair_mean": ("air_heat", False), "tair_max": ("air_heat", False), "tair_min": ("night_cold", False),
    "rh_mean": ("air_humidity", False), "rh_min": ("air_humidity", False), "rh_max": ("air_humidity", False),
    "vpd_max_kpa": ("air_dryness", False), "vpd_day_kpa": ("air_dryness", False),
    "vpd_midday_kpa": ("air_dryness", False), "vpd_night_kpa": ("air_dryness", False),
    "dht_missing_hours": ("data_quality", False), "light_mean_adc": ("sunlight", False),
    "light_hours": ("sunlight", False), "light_saturated_hours": ("sunlight", False),
    "piezo_rate_day": ("tree_sounds", False), "piezo_rate_midday": ("tree_sounds", False),
    "piezo_rate_night": ("tree_sounds", False), "piezo_rms_midday": ("tree_sounds", False),
    "piezo_max": ("tree_sounds", False), "hours_above_35": ("air_heat", False), "hours_above_40": ("air_heat", False),
    "degree_hours_above_35": ("air_heat", False), "tair_floor_hours": ("night_cold", True),
    "tair_below_0_hours": ("night_cold", True), "rh_floor_hours": ("air_humidity", True),
    "tsoil_amp": ("soil_temp", False), "tsoil_minus_tair": ("soil_temp", False), "latitude": ("zone_place", False),
    "ground_cover_frac": ("ground_cover", False), "irrigation_water_ec_dsm": ("irrigation_type", False),
    "doy_sin": ("season_stage", False), "doy_cos": ("season_stage", False), "kc_fao": ("tree_water_need", False),
    "leaf_on": ("season_stage", False), "et0_hs_mm": ("tree_water_need", False),
    "etc_hs_mm": ("tree_water_need", False), "p_adj": ("tree_water_need", True), "rew_predawn": ("soil_water", False),
    "rew_mean": ("soil_water", False), "depletion_frac": ("soil_water", True), "below_raw": ("soil_water", True),
    "sat_ratio_max": ("soil_too_wet", False), "excess_frac_max": ("soil_too_wet", False),
    "hours_near_saturation": ("soil_too_wet", False), "swp_baseline_bar": ("air_dryness", True),
    "wetting_event": ("watering", False), "drawdown_day_mm": ("soil_drying", False),
    "drawdown_per_etc": ("soil_drying", False), "uptake_est_mm": ("soil_drying", False),
    "uptake_per_etc": ("soil_drying", False), "piezo_day_night_diff": ("tree_sounds", False),
    "piezo_wind_adj": ("tree_sounds", False), "rain_api_mm": ("watering", False),
    "irrigation_logged_mm": ("watering", False), "rew_min_7d": ("soil_water", False),
    "hours_near_sat_3d": ("soil_too_wet", False), "hours_above_35_3d": ("air_heat", False),
    "vpd_max_3d": ("air_dryness", False), "piezo_midday_7d": ("tree_sounds", False),
    "drawdown_per_etc_7d": ("soil_drying", False), "uptake_per_etc_7d": ("soil_drying", False),
    "tsoil_amp_7d": ("soil_temp", False), "piezo_z14": ("tree_sounds", False),
    "days_since_wetting": ("watering", True), "water_in_mm": ("watering", False),
    "water_balance_7d_mm": ("watering", False), "uptake_measured": ("data_quality", False),
    "uptake_7d_measured": ("data_quality", False), "ec_unknown": ("irrigation_type", False),
    "rain_api_missing": ("data_quality", False),
}
for _f in ["rew_predawn_vs_orchard", "drawdown_per_etc_7d_vs_orchard", "uptake_per_etc_7d_vs_orchard",
           "piezo_wind_adj_vs_orchard", "tsoil_amp_vs_orchard", "hours_near_saturation_vs_orchard"]:
    STRESS_FEATURES[_f] = ("other_zones", False)
for _f in ["irr_drip", "irr_rainfed", "irr_rainfed_supplemental"]:
    STRESS_FEATURES[_f] = ("irrigation_type", False)
for _f in ["stage_bloom", "stage_dormant", "stage_fruit_growth", "stage_fruit_set", "stage_hull_split",
           "stage_kernel_fill", "stage_leaf_fall", "stage_postharvest"]:
    STRESS_FEATURES[_f] = ("season_stage", False)

CODES = ["soil_water", "soil_drying", "soil_too_wet", "watering", "tree_water_need", "air_heat", "night_cold",
         "evening_temp", "cooling_fast", "night_low_expected", "dew_point", "air_humidity", "air_dryness", "clear_sky",
         "sunlight", "soil_temp", "tree_sounds", "season_stage", "zone_place", "soil_type", "irrigation_type",
         "ground_cover", "other_zones", "data_quality"]
SAME_TEXT = {"season_stage", "soil_type", "irrigation_type", "other_zones", "data_quality"}

# Simple words for the Groq prompt (the app has its own copy in the ARB files).
FACTOR_TEXTS: dict[str, dict[str, tuple[str, str]]] = {
    "soil_water": {"low": ("ماء قليل في التربة", "peu d'eau dans le sol"),
                   "high": ("التربة فيها برشا ماء", "beaucoup d'eau dans le sol")},
    "soil_drying": {"low": ("التربة تنشف بشوية", "le sol sèche lentement"),
                    "high": ("التربة تنشف بسرعة", "le sol sèche vite")},
    "soil_too_wet": {"low": ("التربة موش مشبعة بالماء", "le sol n'est pas gorgé d'eau"),
                     "high": ("التربة مشبعة بالماء", "le sol est gorgé d'eau")},
    "watering": {"low": ("ما جاش ماء للتربة من مدة", "pas d'eau arrivée au sol depuis un moment"),
                 "high": ("جا ماء للتربة (سقي ولا مطر)", "de l'eau est arrivée (arrosage ou pluie)")},
    "tree_water_need": {"low": ("الشجر يحتاج شوية ماء في الوقت هذا", "les arbres ont peu besoin d'eau en ce moment"),
                        "high": ("الشجر يحتاج برشا ماء في الوقت هذا", "les arbres ont besoin de beaucoup d'eau en ce moment")},
    "air_heat": {"low": ("النهار موش سخون", "la journée n'est pas chaude"),
                 "high": ("سخانة قوية في النهار", "forte chaleur la journée")},
    "night_cold": {"low": ("الليل اللي فات كان بارد", "la nuit dernière était froide"),
                   "high": ("الليل اللي فات ما كانش بارد", "la nuit dernière n'était pas froide")},
    "evening_temp": {"low": ("الحرارة توّا منخفضة", "il fait froid maintenant"),
                     "high": ("الحرارة توّا موش منخفضة", "il ne fait pas froid maintenant")},
    "cooling_fast": {"low": ("الحرارة تهبط بشوية", "la température baisse lentement"),
                     "high": ("الحرارة تهبط بسرعة", "la température baisse vite")},
    "night_low_expected": {"low": ("الليلة تنجم تبرد برشا", "la nuit peut devenir très froide"),
                           "high": ("الليلة ما تبردش برشا", "la nuit ne devrait pas être très froide")},
    "dew_point": {"low": ("الهواء ناشف (نقطة الندى منخفضة)", "l'air est sec (point de rosée bas)"),
                  "high": ("الهواء فيه رطوبة (نقطة الندى عالية)", "l'air est humide (point de rosée haut)")},
    "air_humidity": {"low": ("رطوبة الهواء منخفضة", "l'air est peu humide"),
                     "high": ("رطوبة الهواء عالية", "l'air est très humide")},
    "air_dryness": {"low": ("الهواء موش ناشف", "l'air n'est pas sec"),
                    "high": ("الهواء ناشف وسخون", "l'air est sec et chaud")},
    "clear_sky": {"low": ("السماء موش صافية", "le ciel n'est pas dégagé"),
                  "high": ("السماء صافية: السخانة تهرب في الليل", "ciel clair : la chaleur s'échappe la nuit")},
    "sunlight": {"low": ("شمس قليلة", "peu de soleil"), "high": ("شمس قوية", "beaucoup de soleil")},
    "soil_temp": {"low": ("التربة باردة", "le sol est froid"), "high": ("التربة سخونة", "le sol est chaud")},
    "tree_sounds": {"low": ("جذع الشجرة هادئ", "le tronc est calme"),
                    "high": ("جذع الشجرة يعطي إشارات عطش", "le tronc donne des signes de soif")},
    "zone_place": {"low": ("المنطقة في بقعة منخفضة (البرد يتجمع فيها)", "la zone est dans un creux (le froid s'y accumule)"),
                   "high": ("المنطقة في بقعة عالية", "la zone est en hauteur")},
    "ground_cover": {"low": ("الشجر صغير وما يغطيش الأرض", "petits arbres qui couvrent peu le sol"),
                     "high": ("الشجر كبير ويغطي الأرض", "grands arbres qui couvrent le sol")},
    "season_stage": {"same": ("وقت العام ومرحلة الشجر", "la saison et le stade des arbres")},
    "soil_type": {"same": ("نوع التربة", "le type de sol")},
    "irrigation_type": {"same": ("طريقة السقي وملوحة الماء", "le mode d'arrosage et le sel de l'eau")},
    "other_zones": {"same": ("مقارنة بالمناطق الأخرى متاعك", "comparé à vos autres zones")},
    "data_quality": {"same": ("بعض القراءات ناقصة", "certaines mesures manquent")},
}


def factor_text(code: str, level: str | None, lang: str) -> str:
    entry = FACTOR_TEXTS[code]
    ar, fr = entry.get("same") or entry.get(level or "high") or entry["high"]
    return ar if lang == "ar" else fr


def top_factors(shap: pd.Series, values: pd.Series, reference: pd.Series, mapping: dict[str, tuple[str, bool]],
                towards: float = 1.0, k: int = 4) -> list[dict]:
    """The k main reasons: SHAP added up per code, turned towards the predicted state (towards = +1 or -1).

    Returns [{"code", "level", "share", "feature", "value", "shap"}], biggest first; share = part of
    the total push of the reasons (0..1)."""
    groups: dict[str, list[tuple[str, float]]] = {}
    for feat, s in shap.items():
        code, _ = mapping.get(feat, ("data_quality", False))
        groups.setdefault(code, []).append((feat, float(s) * towards))
    scored = []
    for code, items in groups.items():
        total = sum(s for _, s in items)
        if total <= 1e-6:
            continue
        feat, s = max(items, key=lambda it: it[1])
        inverted = mapping.get(feat, ("", False))[1]
        v = float(values.get(feat, np.nan))
        ref = float(reference.get(feat, np.nan))
        if code in SAME_TEXT or np.isnan(v) or np.isnan(ref):
            level = None
        else:
            high = v > ref
            level = "high" if high != inverted else "low"
        scored.append({"code": code, "level": level, "total": total, "feature": feat,
                       "value": None if np.isnan(v) else round(v, 4), "shap": round(s, 4)})
    scored.sort(key=lambda d: d["total"], reverse=True)
    top = scored[:k]
    whole = sum(d["total"] for d in top) or 1.0
    for d in top:
        d["share"] = round(d.pop("total") / whole, 3)
    return top


_SAFE = re.compile(r"^[a-z0-9_]+$")


def check_mapping(features: list[str], mapping: dict[str, tuple[str, bool]]) -> list[str]:
    """Features of a model without a code (must be empty), and codes outside the list."""
    bad = [f for f in features if f not in mapping]
    bad += [c for c, _ in mapping.values() if c not in CODES or not _SAFE.match(c)]
    return bad
