"""The two saved models (AI_modules_time_series/): loading, the SAME preparation
as the notebooks, the prediction and its SHAP values.

- frost_model.joblib  (frost_prediction.ipynb): StandardScaler + LogisticRegression,
  "frost tonight" (air <= 0 °C before 9 am). Preparation = the notebook's
  predict_frost(): critical_temp_c filled with -10 + sensitive_stage, one-hot
  soil_type / pheno_stage, reindex on the bundle features, capping with the saved
  IQR fences. SHAP: exact linear SHAP (= shap.LinearExplainer with the training
  means as background): coef_j * (x_j - mean_j) / scale_j, in log-odds.
- stress_model.joblib (stress_detection.ipynb): IQRCapper + SimpleImputer +
  LightGBM (tuned), 6 classes. Preparation = the notebook's predict_stress():
  add_missing_flags_and_rule_fills(), encode(), reindex. SHAP: LightGBM's own
  TreeSHAP (pred_contrib=True, = shap.TreeExplainer) of the predicted class, on
  the capped + imputed inputs, in raw (log-odds) units.

The versions the bundles were saved with are pinned in requirements-ml.txt:
scikit-learn 1.6.1 (both bundles say so), LightGBM 4.x, numpy 2.x, pandas 2.2.
"""
from __future__ import annotations

import os
import warnings
from dataclasses import dataclass
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import sklearn

from .custom_classes import register

# The repository's folder with the 2 bundles (or ML_MODELS_DIR).
DEFAULT_DIR = Path(__file__).resolve().parents[3] / "AI_modules_time_series"
SAVED_SKLEARN = "1.6.1"


# ---------- the notebooks' preparation (copied, only made into functions) ----------
def predict_frost(evening_rows: pd.DataFrame, bundle: dict) -> pd.DataFrame:
    """frost_prediction.ipynb, cell 38 (verbatim)."""
    x = evening_rows.copy()
    x["sensitive_stage"] = x["critical_temp_c"].notna().astype(int)
    x["critical_temp_c"] = x["critical_temp_c"].fillna(-10.0)
    x = pd.get_dummies(x, columns=["soil_type", "pheno_stage"], prefix=["soil", "stage"], dtype=int)
    x = x.reindex(columns=bundle["features"], fill_value=0).astype(float)
    x[bundle["continuous"]] = x[bundle["continuous"]].clip(bundle["iqr_low"], bundle["iqr_high"], axis=1)
    p = bundle["model"].predict_proba(x)[:, 1]
    return pd.DataFrame({"frost_probability": p.round(3), "ALARM": np.where(p >= bundle["threshold"], "FROST ALERT", "-")},
                        index=evening_rows.index)


def prepare_frost(evening_rows: pd.DataFrame, bundle: dict) -> pd.DataFrame:
    """The input of the frost pipeline (the first 5 lines of predict_frost)."""
    x = evening_rows.copy()
    x["sensitive_stage"] = x["critical_temp_c"].notna().astype(int)
    x["critical_temp_c"] = x["critical_temp_c"].fillna(-10.0)
    x = pd.get_dummies(x, columns=["soil_type", "pheno_stage"], prefix=["soil", "stage"], dtype=int)
    x = x.reindex(columns=bundle["features"], fill_value=0).astype(float)
    x[bundle["continuous"]] = x[bundle["continuous"]].clip(bundle["iqr_low"], bundle["iqr_high"], axis=1)
    return x


NO_HISTORY_COLS = ["piezo_z14", "vwc_predawn_trend_3d", "vwc_predawn_delta_1d"]
CATEGORICAL = ["irrigation_system", "pheno_stage"]


def add_missing_flags_and_rule_fills(x):
    """stress_detection.ipynb, cell 11 (verbatim)."""
    # Deterministic rules (no statistics), used for training AND for new data
    x = x.copy()
    x["uptake_measured"] = x["uptake_per_etc"].notna().astype(int)
    x["uptake_7d_measured"] = x["uptake_per_etc_7d"].notna().astype(int)
    rainfed = x["irrigation_system"] != "drip"
    x.loc[rainfed, "irrigation_water_ec_dsm"] = 0.0
    x["ec_unknown"] = x["irrigation_water_ec_dsm"].isna().astype(int)
    x["rain_api_missing"] = x["rain_api_mm"].isna().astype(int)
    x["rain_api_mm"] = x["rain_api_mm"].fillna(0.0)
    x[NO_HISTORY_COLS] = x[NO_HISTORY_COLS].fillna(0.0)
    x["leaf_on"] = x["leaf_on"].astype(str).str.lower().isin(["true", "1"]).astype(int)
    return x


def encode(x):
    """stress_detection.ipynb, cell 21 (verbatim)."""
    x = pd.get_dummies(x, columns=CATEGORICAL, prefix=["irr", "stage"], dtype=int)
    return x.drop(columns=["pheno_stage_id"], errors="ignore")


def predict_stress(day_rows: pd.DataFrame, bundle: dict) -> pd.DataFrame:
    """stress_detection.ipynb, cell 37 (verbatim)."""
    # Same preparation as training, then class + confidence
    x = encode(add_missing_flags_and_rule_fills(day_rows))
    x = x.reindex(columns=bundle["features"], fill_value=0).astype(float)
    proba = bundle["model"].predict_proba(x)
    out = pd.DataFrame(proba.round(3), columns=[f"p_{c}" for c in bundle["classes"]], index=day_rows.index)
    out.insert(0, "predicted_stress", [bundle["classes"][i] for i in proba.argmax(1)])
    out.insert(1, "confidence", proba.max(1).round(3))
    return out


def prepare_stress(day_rows: pd.DataFrame, bundle: dict) -> pd.DataFrame:
    """The input of the stress pipeline (the first 2 lines of predict_stress)."""
    x = encode(add_missing_flags_and_rule_fills(day_rows))
    return x.reindex(columns=bundle["features"], fill_value=0).astype(float)


# ---------- loading ----------
@dataclass
class Models:
    frost: dict
    stress: dict
    frost_version: str
    stress_version: str
    warnings: list[str]


def load(models_dir: str | os.PathLike | None = None) -> Models:
    """Loads both bundles (registers the notebook classes first). Raises if a file is missing."""
    folder = Path(models_dir or os.environ.get("ML_MODELS_DIR") or DEFAULT_DIR)
    register()
    caught: list[str] = []
    with warnings.catch_warnings(record=True) as seen:
        warnings.simplefilter("always")
        frost = joblib.load(folder / "frost_model.joblib")
        stress = joblib.load(folder / "stress_model.joblib")
    caught = [str(w.message)[:200] for w in seen]
    if sklearn.__version__ != SAVED_SKLEARN:
        caught.append(f"scikit-learn {sklearn.__version__} installed, the bundles were saved with {SAVED_SKLEARN}")
    return Models(
        frost=frost, stress=stress,
        frost_version=f"frost-logreg-skl{SAVED_SKLEARN}",
        stress_version=f"stress-lgbm-skl{SAVED_SKLEARN}",
        warnings=caught,
    )


# ---------- prediction + SHAP ----------
@dataclass
class FrostResult:
    probability: float
    threshold: float
    alarm: bool
    shap: pd.Series          # log-odds contribution of each feature (towards frost)
    base_value: float        # log-odds when every feature is at its training mean
    prepared: pd.Series      # the model input (after the notebook's preparation)


def frost_predict(row: pd.DataFrame, bundle: dict) -> FrostResult:
    x = prepare_frost(row, bundle)
    pipe = bundle["model"]
    proba = float(pipe.predict_proba(x)[0, 1])
    scaler, lr = pipe.named_steps["scaler"], pipe.named_steps["model"]
    z = (x.values[0] - scaler.mean_) / scaler.scale_
    contrib = lr.coef_[0] * z
    return FrostResult(
        probability=proba, threshold=float(bundle["threshold"]), alarm=proba >= bundle["threshold"],
        shap=pd.Series(contrib, index=bundle["features"]), base_value=float(lr.intercept_[0]),
        prepared=x.iloc[0],
    )


@dataclass
class StressResult:
    state: str
    confidence: float
    probabilities: dict[str, float]
    shap: pd.Series          # TreeSHAP of the predicted class (raw margin)
    base_value: float
    prepared: pd.Series      # input of the pipeline (before capping / imputing)
    model_input: pd.Series   # after capping + imputing (what the trees saw)


# The saved stress pipeline gives its LightGBM a plain array (its imputer has no pandas output):
# scikit-learn then warns "X does not have valid feature names" (the notebook hides warnings too).
_NAMES_WARNING = "X does not have valid feature names"


def stress_predict(row: pd.DataFrame, bundle: dict) -> StressResult:
    x = prepare_stress(row, bundle)
    pipe = bundle["model"]
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", message=_NAMES_WARNING)
        proba = pipe.predict_proba(x)[0]
        xt = pd.DataFrame(np.asarray(pipe[:-1].transform(x), dtype=float), columns=bundle["features"])
        contrib = np.asarray(pipe.named_steps["model"].predict(xt, pred_contrib=True))
    k = int(np.argmax(proba))
    classes = list(bundle["classes"])
    xt = xt.values
    n_feat = len(bundle["features"])
    contrib = contrib.reshape(len(classes), n_feat + 1) if contrib.ndim == 2 and contrib.shape[0] == 1 \
        else contrib.reshape(-1)[: len(classes) * (n_feat + 1)].reshape(len(classes), n_feat + 1)
    return StressResult(
        state=classes[k], confidence=float(proba[k]),
        probabilities={c: float(p) for c, p in zip(classes, proba)},
        shap=pd.Series(contrib[k, :n_feat], index=bundle["features"]), base_value=float(contrib[k, n_feat]),
        prepared=x.iloc[0], model_input=pd.Series(xt[0], index=bundle["features"]),
    )
