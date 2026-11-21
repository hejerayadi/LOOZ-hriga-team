"""The two saved models: loading with the pinned versions, the SAME preparation and
prediction as the notebooks, exact SHAP values, every feature mapped to a farmer word."""
import json
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
import sklearn

from ml import features as F
from ml import models as M
from ml.factors import FROST_FEATURES, STRESS_FEATURES, check_mapping

FIX = json.loads((Path(__file__).parent / "ml_fixtures" / "sim_history.json").read_text())

# The 5 complete rows printed by frost_prediction.ipynb (cell 4: raw.head()), all columns the model uses.
NOTEBOOK_ROWS = pd.DataFrame([
    dict(t_dec_c=21.0, rh_dec_pct=67.0, td_dec_c=14.6407, dewpoint_depression_dec=6.3593, t_sunset_c=22.0, rh_sunset_pct=64.0,
         cooling_since_sunset=1.0, cooling_last_hour=1.0, t_max_today_c=25.0, t_min_last_night_c=17.0, last_night_floor_hours=0,
         tmax_change_1d=1.0, rh_min_today=53.0, rh_at_sensor_cap=0.0, td_change_since_noon=0.8066, td_change_1d=2.3646,
         vpd_dec_kpa=0.8207, tsoil_dec_c=22.9375, tsoil_max_today=23.0625, tsoil_minus_tair_dec=1.9375, vwc_dec=0.043,
         sat_ratio_dec=0.1000, rew_dec=-0.0663, light_day_mean_adc=3359.0000, light_saturated_hours=8, light_sunset_adc=4000.0,
         piezo_rms_dec=3.42, piezo_rms_evening=3.6800, piezo_rms_day=5.9243, sky_emissivity_clear=0.8228, lnet_clear_wm2=62.4751,
         brunt_clear_cooling_c=5.9775, brunt_clear_tmin_c=15.0225),
    dict(t_dec_c=22.0, rh_dec_pct=72.0, td_dec_c=16.7202, dewpoint_depression_dec=5.2798, t_sunset_c=23.0, rh_sunset_pct=66.0,
         cooling_since_sunset=1.0, cooling_last_hour=1.0, t_max_today_c=26.0, t_min_last_night_c=18.0, last_night_floor_hours=0,
         tmax_change_1d=1.0, rh_min_today=56.0, rh_at_sensor_cap=0.0, td_change_since_noon=0.0245, td_change_1d=3.0309,
         vpd_dec_kpa=0.7403, tsoil_dec_c=23.5625, tsoil_max_today=23.8750, tsoil_minus_tair_dec=1.5625, vwc_dec=0.036,
         sat_ratio_dec=0.0837, rew_dec=-0.1718, light_day_mean_adc=3355.5833, light_saturated_hours=9, light_sunset_adc=4009.0,
         piezo_rms_dec=3.64, piezo_rms_evening=3.7133, piezo_rms_day=5.9229, sky_emissivity_clear=0.8382, lnet_clear_wm2=56.7044,
         brunt_clear_cooling_c=5.5305, brunt_clear_tmin_c=16.4695),
    dict(t_dec_c=22.0, rh_dec_pct=73.0, td_dec_c=16.9375, dewpoint_depression_dec=5.0625, t_sunset_c=24.0, rh_sunset_pct=67.0,
         cooling_since_sunset=2.0, cooling_last_hour=1.0, t_max_today_c=26.0, t_min_last_night_c=19.0, last_night_floor_hours=0,
         tmax_change_1d=0.0, rh_min_today=58.0, rh_at_sensor_cap=0.0, td_change_since_noon=-0.9581, td_change_1d=2.2968,
         vpd_dec_kpa=0.7139, tsoil_dec_c=22.9375, tsoil_max_today=23.1250, tsoil_minus_tair_dec=0.9375, vwc_dec=0.053,
         sat_ratio_dec=0.1233, rew_dec=0.0844, light_day_mean_adc=3313.4545, light_saturated_hours=8, light_sunset_adc=3980.0,
         piezo_rms_dec=4.36, piezo_rms_evening=4.5033, piezo_rms_day=6.1986, sky_emissivity_clear=0.8399, lnet_clear_wm2=55.9930,
         brunt_clear_cooling_c=5.2285, brunt_clear_tmin_c=16.7715),
    dict(t_dec_c=21.0, rh_dec_pct=70.0, td_dec_c=15.3209, dewpoint_depression_dec=5.6791, t_sunset_c=23.0, rh_sunset_pct=64.0,
         cooling_since_sunset=2.0, cooling_last_hour=2.0, t_max_today_c=26.0, t_min_last_night_c=18.0, last_night_floor_hours=0,
         tmax_change_1d=1.0, rh_min_today=54.0, rh_at_sensor_cap=0.0, td_change_since_noon=-0.8421, td_change_1d=1.8627,
         vpd_dec_kpa=0.7461, tsoil_dec_c=23.3750, tsoil_max_today=23.4375, tsoil_minus_tair_dec=2.3750, vwc_dec=0.049,
         sat_ratio_dec=0.1140, rew_dec=0.0241, light_day_mean_adc=3364.3333, light_saturated_hours=8, light_sunset_adc=3990.0,
         piezo_rms_dec=4.03, piezo_rms_evening=4.0833, piezo_rms_day=6.1129, sky_emissivity_clear=0.8280, lnet_clear_wm2=60.2826,
         brunt_clear_cooling_c=5.6820, brunt_clear_tmin_c=15.3180),
    dict(t_dec_c=22.0, rh_dec_pct=67.0, td_dec_c=15.5920, dewpoint_depression_dec=6.4080, t_sunset_c=23.0, rh_sunset_pct=60.0,
         cooling_since_sunset=1.0, cooling_last_hour=0.0, t_max_today_c=26.0, t_min_last_night_c=18.0, last_night_floor_hours=0,
         tmax_change_1d=1.0, rh_min_today=51.0, rh_at_sensor_cap=0.0, td_change_since_noon=-0.0890, td_change_1d=2.3960,
         vpd_dec_kpa=0.8725, tsoil_dec_c=24.0000, tsoil_max_today=24.1875, tsoil_minus_tair_dec=2.0000, vwc_dec=0.037,
         sat_ratio_dec=0.0860, rew_dec=-0.1567, light_day_mean_adc=3356.8333, light_saturated_hours=8, light_sunset_adc=3986.0,
         piezo_rms_dec=4.05, piezo_rms_evening=3.7100, piezo_rms_day=5.8629, sky_emissivity_clear=0.8296, lnet_clear_wm2=60.3938,
         brunt_clear_cooling_c=5.8734, brunt_clear_tmin_c=16.1266),
])
for _c, _v in dict(night_length_h=13.8953, critical_temp_c=np.nan, days_from_bloom_start=-66, latitude=34.72, elevation_m=23,
                   theta_fc=0.114, theta_wp=0.047, theta_sat=0.43, doy_sin=-0.7143, doy_cos=0.6998, floor_is_cover_crop=0,
                   soil_type="sand", pheno_stage="dormant_or_other").items():
    NOTEBOOK_ROWS[_c] = _v
NOTEBOOK_ROWS["position_code"] = [-1, 0, 0, 0, 1]


@pytest.fixture(scope="module")
def models():
    return M.load()


def test_bundles_load_with_the_pinned_versions_without_warnings(models):
    assert sklearn.__version__ == "1.6.1"
    assert models.warnings == []
    assert models.frost["model_name"] == "Logistic Regression"
    assert models.stress["model_name"] == "LightGBM (tuned)"
    assert list(models.stress["classes"]) == ["frost", "heat", "none", "rootzone", "water_deficit", "waterlogging"]
    assert len(models.frost["features"]) == 56 and len(models.stress["features"]) == 92
    assert round(models.frost["threshold"], 3) == 0.664          # the alarm threshold for 90 % recall
    assert models.frost_version == "frost-logreg-skl1.6.1" and models.stress_version == "stress-lgbm-skl1.6.1"


def test_frost_notebook_rows_give_the_notebook_prediction(models):
    """The 5 complete rows of the notebook, through the notebook's own predict_frost (copied verbatim) and
    through our service: the same probability. (The notebook printed no prediction for these rows; its
    8 test-season examples were printed with only 4 columns, so they cannot be rebuilt.)"""
    nb = M.predict_frost(NOTEBOOK_ROWS, models.frost)
    for i in range(len(NOTEBOOK_ROWS)):
        r = M.frost_predict(NOTEBOOK_ROWS.iloc[[i]], models.frost)
        assert round(r.probability, 3) == nb["frost_probability"].iloc[i]
        assert (nb["ALARM"].iloc[i] == "FROST ALERT") == r.alarm
        assert r.probability < 0.01                                  # warm November evenings: no frost
    assert (nb["ALARM"] == "-").all()


def test_frost_preparation_matches_the_notebook(models):
    x = M.prepare_frost(NOTEBOOK_ROWS, models.frost)
    assert list(x.columns) == models.frost["features"]
    assert (x["sensitive_stage"] == 0).all() and (x["critical_temp_c"] == -10).all()
    assert (x["soil_sand"] == 1).all() and (x["soil_clay"] == 0).all()
    assert (x["stage_dormant_or_other"] == 1).all() and (x["stage_bloom"] == 0).all()
    capped = M.prepare_frost(NOTEBOOK_ROWS.assign(t_dec_c=99.0), models.frost)
    assert (capped["t_dec_c"] == 30.0).all()                       # the saved IQR fence (k = 3)


def test_frost_linear_shap_is_exact(models):
    r = M.frost_predict(NOTEBOOK_ROWS.iloc[[0]], models.frost)
    logit = r.base_value + r.shap.sum()
    assert abs(1 / (1 + np.exp(-logit)) - r.probability) < 1e-12
    shap = pytest.importorskip("shap")
    pipe = models.frost["model"]
    z = pipe.named_steps["scaler"].transform(M.prepare_frost(NOTEBOOK_ROWS.iloc[[0]], models.frost))
    expl = shap.LinearExplainer(pipe.named_steps["model"], np.zeros((1, z.shape[1])))
    assert np.abs(np.asarray(expl.shap_values(z)).reshape(-1) - r.shap.values).max() < 1e-9


def _stress_rows():
    ctx = dict(soil_type="sandy_loam", theta_fc=0.25, theta_wp=0.11, theta_sat=0.44, node_position="mid",
               irrigation_system="drip", ground_cover_frac=0.5, cover_crop=False, root_depth_m=0.6, bloom_start="01-20",
               latitude=34.74, elevation_m=20, irrigation_water_ec_dsm=None)
    rows = {k: F.stress_row(F.hourly(pts), ctx)[0] for k, pts in FIX["summer"].items()}
    F.add_vs_orchard(rows)
    return pd.DataFrame(list(rows.values()))


def test_stress_same_prediction_as_the_notebook_function(models):
    """The stress notebook was saved WITHOUT outputs (no printed prediction to compare with): its own
    predict_stress (copied verbatim) and our service give the same class and confidence."""
    rows = _stress_rows()
    nb = M.predict_stress(rows, models.stress)
    for i in range(len(rows)):
        r = M.stress_predict(rows.iloc[[i]], models.stress)
        assert r.state == nb["predicted_stress"].iloc[i]
        assert round(r.confidence, 3) == nb["confidence"].iloc[i]
        assert abs(sum(r.probabilities.values()) - 1) < 1e-9


def test_stress_tree_shap_is_exact(models):
    rows = _stress_rows()
    r = M.stress_predict(rows.iloc[[1]], models.stress)
    pipe = models.stress["model"]
    xt = pd.DataFrame(pipe[:-1].transform(M.prepare_stress(rows.iloc[[1]], models.stress)), columns=models.stress["features"])
    k = list(models.stress["classes"]).index(r.state)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        raw = pipe.named_steps["model"].predict(xt, raw_score=True)[0]
    assert abs(r.base_value + r.shap.sum() - raw[k]) < 1e-6        # SHAP adds up to the model's score
    shap = pytest.importorskip("shap")
    sv = np.asarray(shap.TreeExplainer(pipe.named_steps["model"]).shap_values(xt))
    s_k = sv[0, :, k] if sv.ndim == 3 else sv[k][0]
    assert np.abs(s_k - r.shap.values).max() < 1e-6


def test_every_feature_has_a_farmer_word(models):
    assert check_mapping(models.frost["features"], FROST_FEATURES) == []
    assert check_mapping(models.stress["features"], STRESS_FEATURES) == []


def test_missing_flags_and_rule_fills_like_the_notebook():
    row = pd.DataFrame([dict(uptake_per_etc=np.nan, uptake_per_etc_7d=0.5, irrigation_system="rainfed",
                             irrigation_water_ec_dsm=np.nan, rain_api_mm=np.nan, piezo_z14=np.nan,
                             vwc_predawn_trend_3d=np.nan, vwc_predawn_delta_1d=np.nan, leaf_on=True)])
    x = M.add_missing_flags_and_rule_fills(row).iloc[0]
    assert x["uptake_measured"] == 0 and x["uptake_7d_measured"] == 1
    assert x["irrigation_water_ec_dsm"] == 0.0 and x["ec_unknown"] == 0      # rainfed: no irrigation water
    assert x["rain_api_missing"] == 1 and x["rain_api_mm"] == 0.0
    assert x["piezo_z14"] == 0.0 and x["leaf_on"] == 1
    drip = M.add_missing_flags_and_rule_fills(row.assign(irrigation_system="drip")).iloc[0]
    assert drip["ec_unknown"] == 1                                            # drip, never measured
