"""The custom classes of stress_detection.ipynb, EXACTLY as in the notebook
(cells 19 and 25). The saved pipeline (stress_model.joblib) was pickled from
the notebook, so it refers to them as "__main__.IQRCapper": register() puts
them there before joblib.load.

The saved stress model is LightGBM (tuned): BalancedXGBClassifier is not used
by it, but it is defined too (as the notebook does) when xgboost is installed.
"""
import __main__

from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.utils.class_weight import compute_sample_weight


class IQRCapper(BaseEstimator, TransformerMixin):
    # Clip continuous columns to [Q1 - k*IQR, Q3 + k*IQR] learned on the training data
    def __init__(self, columns=None, k=3.0):
        self.columns, self.k = columns, k

    def fit(self, X, y=None):
        cols = [c for c in (self.columns or []) if c in X.columns]
        q1, q3 = X[cols].quantile(0.25), X[cols].quantile(0.75)
        iqr = q3 - q1
        self.cols_ = list(iqr[iqr > 0].index)            # skip zero-IQR count columns
        self.low_ = q1[self.cols_] - self.k * iqr[self.cols_]
        self.high_ = q3[self.cols_] + self.k * iqr[self.cols_]
        return self

    def transform(self, X):
        X = X.copy()
        X[self.cols_] = X[self.cols_].clip(self.low_, self.high_, axis=1)
        return X


try:
    from xgboost import XGBClassifier

    class BalancedXGBClassifier(XGBClassifier):
        # XGBoost + balanced class weights (like class_weight="balanced" in scikit-learn)
        def fit(self, X, y, **kwargs):
            kwargs.setdefault("sample_weight", compute_sample_weight("balanced", y))
            return super().fit(X, y, **kwargs)
except ImportError:  # xgboost is optional: the saved stress model is LightGBM
    class BalancedXGBClassifier:  # type: ignore[no-redef]
        def __init__(self, *args, **kwargs):
            raise ImportError("xgboost is not installed (pip install xgboost) — the saved model does not need it")


def register() -> None:
    """Makes the classes findable as __main__.IQRCapper / __main__.BalancedXGBClassifier."""
    __main__.IQRCapper = IQRCapper
    __main__.BalancedXGBClassifier = BalancedXGBClassifier
