# The features of the two ML models (how LOOZ computes them)

**Important:** the dataset generators (`almond_stress_dataset.py` with `daily_features()`, and the
frost generator) were **not** in `AI_modules_time_series/`. Only the two notebooks and the two
bundles were. Every feature below was therefore **rebuilt** from: the notebooks' code and comments,
the feature lists of the bundles, the saved IQR fences / scaler means / imputer medians (they give
quartiles and medians of the training data), and the **5 complete rows** printed by
`frost_prediction.ipynb` (cell 4). When the generators are found, compare them with
`dashboard/backend/ml/features.py` and `physics.py` and fix any difference (then run
`pytest tests/test_ml_*.py`).

Code: `dashboard/backend/ml/features.py` (windows, aggregates), `ml/physics.py` (formulas),
`ml/models.py` (the notebooks' own preparation, copied verbatim). Tests: `tests/test_ml_features.py`.

## Raw data (Node-RED → Supabase, migration 019)

One reading per box every 15 minutes (simulation: every 5 s). History in `node_readings`: one point
per hour of measured time (demo gateway; `gateways.history_minutes`), 30 days. The worker puts it on an
**hourly grid in Tunisia time** (UTC+1) and removes impossible values (DS18B20 85 / −127 °C, soil
moisture outside 0.5–70 %, air outside −40..60 °C...).

| Channel | Column | Sensor (like the datasets) |
| --- | --- | --- |
| Soil moisture | `soil_moisture_pct` (VWC × 100) | capacitive probe |
| Soil temperature | `soil_temp_c` | DS18B20, steps of 1/16 °C |
| Air temperature, humidity | `air_temp_c`, `humidity_pct` | DHT11: whole numbers, **0 °C at most low**, humidity 20–90 % (the 75th percentile of `rh_max` in the bundle is exactly 90) |
| Light | `light_adc` | 12-bit ADC, saturates in full sun (≥ 4000) |
| Piezo on the trunk | `piezo_rms`, `piezo_events_h` | vibration RMS; acoustic "clicks" counted in the last hour |

## Frost model (56 features) — "frost tonight" (≤ 0 °C before 9:00)

Trained for ONE decision time: 2 h after sunset. LOOZ runs it at **every 15-minute step, all day**
(decision of the user): the "_dec" values are the **latest reading**. The night is "tonight" from
9:00, "the night going on" before 9:00. **Outside the evening the inputs are outside the training
distribution** (by day the probability stays near 0; during the night it follows the cooling).

| Feature | How | Sure? |
| --- | --- | --- |
| `t_dec_c`, `rh_dec_pct` | latest hour | — |
| `td_dec_c` | Magnus dew point (17.625, 243.04) | ±0.01 °C on the 5 rows |
| `dewpoint_depression_dec` | t − td | exact |
| `vpd_dec_kpa` | Tetens es(T)·(1−RH) | exact on the rows |
| `t_sunset_c`, `rh_sunset_pct` | reading of the sunset hour (FAO-56 day length, solar noon 12:19) ; by day = now | approx. |
| `cooling_since_sunset` | t_sunset − t_now (0 by day) | approx. |
| `cooling_last_hour` | t(−1 h) − t | — |
| `t_max_today_c`, `rh_min_today`, `tsoil_max_today` | 06:00 → sunset of the night's day | approx. window |
| `t_min_last_night_c`, `last_night_floor_hours` | previous sunset → 09:00; hours at the DHT11 floor (≤ 0 °C) | approx. |
| `tmax_change_1d`, `td_change_since_noon`, `td_change_1d` | differences with yesterday / 12–13 h / 24 h before | — |
| `rh_at_sensor_cap` | RH ≥ 90 (DHT11 cap) | from the fences |
| `tsoil_dec_c`, `tsoil_minus_tair_dec`, `vwc_dec` | latest | — |
| `sat_ratio_dec`, `rew_dec` | vwc/θsat ; (vwc−θwp)/(θfc−θwp) | matches the rows (rounding) |
| `light_day_mean_adc`, `light_saturated_hours`, `light_sunset_adc` | mean of lit hours, hours ≥ 4000, reading the hour before sunset | approx. |
| `piezo_rms_dec / _evening / _day` | latest / since sunset / daytime mean (3.5 if no piezo) | approx. |
| `sky_emissivity_clear` | Brutsaert 1.24 (e/T)^(1/7) | ±0.001 on the rows |
| `lnet_clear_wm2` | σT⁴ (0.97 − ε) | ±0.01 W/m² on the rows |
| `brunt_clear_cooling_c` | 2·Lnet·√t / (√π·μ), t = night length − 2 h, **μ = 2169 + 6265·vwc fitted on the 5 rows (sand)** | ±1 % on sand, unknown for other soils |
| `brunt_clear_tmin_c` | t − cooling | exact |
| `night_length_h` | 24 − FAO-56 day length | ±0.03 h |
| `days_from_bloom_start` | from the zone's bloom start (MM-DD; default per governorate, Sfax 01-20) | — |
| `pheno_stage` | pink bud −14..−1 d, bloom 0..29, small nut 30..66 (lengths fitted to the stage shares of the scaler) | approx. |
| `critical_temp_c` | pink bud −3.3, bloom −2.2, small nut −1.7 °C (weighted mean = scaler mean −2.16) ; else empty → −10 + `sensitive_stage` (notebook) | approx. |
| `latitude`, `elevation_m`, `theta_*`, `soil_type`, `floor_is_cover_crop`, `position_code` | farm context (`ml_zone_context()`) | — |
| `doy_sin/cos` | 2π·doy/365.25 | ±0.0003 |

## Stress model (92 features) — 6 classes, a DAILY model

"Today" = the **last 24 hours** before the latest reading (so it can run at every step); the 3/7/14-day
features use the previous calendar days. Needs ≥ 20 valid hours in the last 24 h (else "not enough data").

| Group | Features | How |
| --- | --- | --- |
| Daily air/soil | `tair_*`, `rh_*`, `tsoil_*`, `vpd_*` (max, daylight, 12–15 h, 0–5 h), `hours_above_35/40`, `degree_hours_above_35`, `tair_floor_hours`, `tair_below_0_hours` (= hours at the DHT11 floor, both), `rh_floor_hours` (RH ≤ 20), `dht_missing_hours`, `n_valid_hours`, `tsoil_amp`, `tsoil_minus_tair` | hourly aggregates |
| Light | `light_mean_adc` (24 h), `light_hours` (> 50), `light_saturated_hours` (≥ 4000) | approx. thresholds |
| Piezo | `piezo_rate_day/midday/night`, `piezo_rms_midday`, `piezo_max`, `piezo_day_night_diff`, `piezo_wind_adj` (= rate_midday/(1+rms_midday), fitted to the medians), `piezo_midday_7d`, `piezo_z14` (z-score vs 14 days, sd ≥ 0.25) | approx. |
| Water | `rew_predawn` (05:00), `rew_mean`, `depletion_frac`, `below_raw`, `sat_ratio_max`, `excess_frac_max`, `hours_near_saturation` (vwc ≥ fc + ½(sat−fc)), `vwc_max_rise_1h`, `wetting_event` (rise ≥ 0.005), `water_in_mm` (Σ(rise − 0.003)·300 mm), `drawdown_day_mm` (no wetting & leaves out), `uptake_est_mm` (drawdown − ½ drainage above fc), `*_per_etc`, `days_since_wetting`, `water_balance_7d_mm`, `rew_min_7d`, `hours_near_sat_3d` | **approximations** (the generator's root-zone water balance is unknown) |
| Crop | `kc_fao` (FAO-56 almond 0.40/0.90/0.65, stages 20/60/120/60 days from leaf-out), `leaf_on` (bloom+20 d → mid-November), `et0_hs_mm` (Hargreaves-Samani), `etc_hs_mm` = Kc·ET0·min(1, cover/0.85) (Keller-Karmeli), `p_adj` = 0.4 + 0.04(5 − ETc) (**exactly the imputer medians**), `swp_baseline_bar` = −0.4 − 3.3·VPD_midday (fitted to the medians) | approx. |
| Season | `pheno_stage` (Tunisian calendar: dormant, bloom 0–29 d, fruit set 30–66, fruit growth → 20 May, kernel fill → 15 July, hull split → 31 Aug, post-harvest → 31 Oct, leaf fall November), `doy_sin/cos` | approx. |
| Context | `latitude`, `ground_cover_frac`, `irrigation_system`, `irrigation_water_ec_dsm` (empty = unknown → `ec_unknown`, notebook rule) | farm context |
| External | `rain_api_mm` = **missing** (no weather service yet → `rain_api_missing` = 1), `irrigation_logged_mm` = 0 (the journal is not connected) | known gap |
| Orchard | `*_vs_orchard` = the box minus the median of the boxes of the same orchard (0 with one box) | — |

Then the notebook's own `add_missing_flags_and_rule_fills()` and `encode()` are applied (copied
verbatim in `ml/models.py`), and the saved pipeline caps and imputes.

## Checks done

- Both bundles load with scikit-learn 1.6.1 / LightGBM 4.6.0 / numpy 2.2 / pandas 2.2 **without a warning**.
- The 5 complete rows of the frost notebook: our service = the notebook's `predict_frost` (verbatim).
  The notebook's 8 printed test-season predictions show only 4 columns: they cannot be rebuilt.
  The stress notebook was saved **without outputs**: our service = its `predict_stress` on our rows.
- SHAP: frost = exact linear SHAP (= `shap.LinearExplainer`, max difference 0.0); stress = LightGBM
  TreeSHAP (= `shap.TreeExplainer`, < 1e-6) — both checked with the `shap` package.
- On the Node-RED simulation: leaking zone B → `water_deficit`, hot zone C → `heat`, heat wave →
  `heat`, winter → `none`; frost night → zone D (low spot) frost risk from 19:00, zone C (high) last;
  summer frost probability ≈ 0. **This is a check of the plumbing, not of the accuracy**: the data is
  simulated and several features are approximations. Validate on real nights and days before trusting it.
