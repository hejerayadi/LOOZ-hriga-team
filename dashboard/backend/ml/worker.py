"""The ML worker: predictions for every new 15-minute step of the sensor boxes.

    cd dashboard/backend
    .venv\\Scripts\\Activate.ps1
    python -m ml.worker            (Ctrl+C to stop; --once = one round, for a test)

Every ML_POLL_SECONDS (10) it asks Supabase for the boxes with a reading newer
than their last prediction (ml_worker_jobs), reads the history of their
orchard (ml_worker_history), computes the features, runs BOTH models, keeps
the SHAP main reasons, asks Groq for the explanation only when the prediction
changed, and saves everything (ml_worker_save). In the accelerated demo a new
step arrives with each batch of Node-RED (every 20-60 s); with real boxes,
every 15 minutes.

It talks to Supabase with the PUBLIC (publishable) key + its own secret key
ML_WORKER_KEY (made by `select public.ml_worker_new_key('ML-01');`): the
database checks that key. No service_role key. Settings in dashboard/backend/.env.
"""
from __future__ import annotations

import argparse
import logging
import os
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
import numpy as np
import pandas as pd

from . import features as F
from . import models as M
from .explain import Explainer, build_facts, explanation_key
from .factors import FROST_FEATURES, STRESS_FEATURES, top_factors

log = logging.getLogger("looz.ml")
ENV_FILE = Path(__file__).resolve().parent.parent / ".env"
ZONE_LETTERS_AR = "أبجدهوزحطيكلمنسعفصقر"   # the abjad order (app: lib/core/zone_letters.dart)
LIKELY_FROST = 0.85      # frost probability from which a frost risk is "likely"
SENSOR_FAULTS_OK = {"battery_low", "signal_weak", "packets_lost", "duplicate_seq"}


def read_env(path: Path = ENV_FILE) -> dict[str, str]:
    env = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$", line)
            if m and not line.lstrip().startswith("#"):
                env[m.group(1)] = m.group(2).strip("'\"")
    env.update({k: v for k, v in os.environ.items() if k.startswith(("SUPABASE_", "ML_", "GROQ_"))})
    return env


class Supabase:
    """The 3 worker functions of migration 019, through the REST API (public key + worker key)."""

    def __init__(self, url: str, anon_key: str, worker_key: str, ipv4_only: bool = False,
                 client: httpx.Client | None = None):
        self.base = url.rstrip("/") + "/rest/v1/rpc/"
        self.headers = {"apikey": anon_key, "Authorization": f"Bearer {anon_key}", "Content-Type": "application/json"}
        self.key = worker_key
        transport = httpx.HTTPTransport(local_address="0.0.0.0") if ipv4_only else None
        self.client = client or httpx.Client(timeout=30.0, transport=transport)

    def rpc(self, fn: str, args: dict):
        r = self.client.post(self.base + fn, json={"p_key": self.key, **args}, headers=self.headers)
        if r.status_code >= 400:
            raise RuntimeError(f"{fn}: HTTP {r.status_code} {r.text[:200]}")
        return r.json()

    def jobs(self, limit: int = 50) -> dict:
        return self.rpc("ml_worker_jobs", {"p_limit": limit})

    def history(self, orchard_id: str, since: datetime) -> dict:
        return self.rpc("ml_worker_history", {"p_orchard": orchard_id, "p_since": since.isoformat()})

    def save(self, predictions: list[dict]) -> dict:
        return self.rpc("ml_worker_save", {"p_batch": {"predictions": predictions}})


def zone_names(letter: str | None, name: str | None) -> tuple[str, str]:
    """"المنطقة ب" / "Zone B" (the farmer's own name if he gave one)."""
    if name:
        return name, name
    letter = (letter or "A").upper()
    idx = ord(letter) - ord("A")
    ar = ZONE_LETTERS_AR[idx] if 0 <= idx < len(ZONE_LETTERS_AR) else letter
    return f"المنطقة {ar}", f"Zone {letter}"


def sensor_problem(job: dict) -> bool:
    faults = set(job.get("faults") or [])
    return job.get("level") == "sensor" or bool(faults - SENSOR_FAULTS_OK)


def readings_of(job: dict) -> dict:
    r = {k: v for k, v in (job.get("latest") or {}).items() if v is not None}
    r["measured_at"] = job["measured_at"]
    return r


def local_clock(iso: str) -> str:
    t = datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone(F.TUNIS)
    return t.strftime("%H:%M")


class Worker:
    def __init__(self, db: Supabase, models: M.Models, explainer: Explainer | None):
        self.db, self.models, self.explainer = db, models, explainer
        self.frost_ref = pd.Series(models.frost["model"].named_steps["scaler"].mean_, index=models.frost["features"])
        imp = models.stress["model"].named_steps["impute"]
        self.stress_ref = pd.Series(imp.statistics_, index=models.stress["features"])

    # ----- one round -----
    def run_once(self) -> dict:
        data = self.db.jobs()
        settings, jobs = data.get("settings") or {}, data.get("jobs") or []
        if not jobs:
            return {"jobs": 0}
        likely_min = float(settings.get("ml_likely_min") or 0.6)
        explain_on = bool(settings.get("ml_explain_enabled")) and bool(settings.get("ml_groq_model"))
        if self.explainer and settings.get("ml_groq_model"):
            self.explainer.model = settings["ml_groq_model"]
        by_orchard: dict[str, list[dict]] = {}
        for j in jobs:
            by_orchard.setdefault(j["orchard_id"], []).append(j)
        out: list[dict] = []
        for orchard_id, ojobs in by_orchard.items():
            latest = max(datetime.fromisoformat(j["measured_at"].replace("Z", "+00:00")) for j in ojobs)
            hist = self.db.history(orchard_id, latest - timedelta(days=15)).get("nodes") or {}
            out += self.predict_orchard(ojobs, hist, likely_min, explain_on)
        self.explain_all(out, explain_on)
        result = self.db.save(out) if out else {}
        log.info("round: %d jobs, %d predictions, saved %s", len(jobs), len(out), result)
        return {"jobs": len(jobs), "predictions": len(out), "saved": result}

    def explain_all(self, preds: list[dict], explain_on: bool) -> None:
        """The Groq texts, PROBLEMS FIRST (the budget per minute may not cover every box): frost risk,
        then a stress, then the rest. A prediction without a text gets one at a later round."""
        def rank(p):
            return 0 if p.get("state") == "frost_risk" else 1 if p.get("state") not in (None, "none", "no_frost") else 2
        for p in sorted(preds, key=rank):
            facts, prev = p.pop("_facts", None), p.pop("_previous", None)
            if facts is None or not (explain_on and self.explainer):
                continue
            e = self.explainer.explain(facts, p["explanation_key"], prev)
            p["explanation"], p["explanation_source"] = e.texts, e.source

    def predict_orchard(self, jobs: list[dict], hist: dict, likely_min: float, explain_on: bool) -> list[dict]:
        ctx_by = {j["node_id"]: j["context"] for j in jobs}
        hourly = {nid: F.hourly(points) for nid, points in hist.items()}
        # stress rows of EVERY box of the orchard (for the "_vs_orchard" features)
        stress_rows: dict[str, dict | None] = {}
        for nid, h in hourly.items():
            ctx = ctx_by.get(nid) or next(iter(ctx_by.values()))
            stress_rows[nid] = F.stress_row(h, ctx)[0]
        F.add_vs_orchard(stress_rows)
        preds = []
        for j in jobs:
            nid = j["node_id"]
            h = hourly.get(nid, pd.DataFrame(columns=F.COLS))
            preds += self.predict_node(j, h, stress_rows.get(nid), likely_min, explain_on)
        return preds

    def predict_node(self, job: dict, h: pd.DataFrame, srow: dict | None, likely_min: float, explain_on: bool) -> list[dict]:
        base = {"node_id": job["node_id"], "measured_at": job["measured_at"], "readings": readings_of(job)}
        prev = job.get("previous") or {}
        if sensor_problem(job):
            return [{**base, "model": m, "status": "sensor_problem", "state": None,
                     "model_version": getattr(self.models, f"{m}_version")} for m in ("frost", "stress")]
        out = []
        zone_ar, zone_fr = zone_names(job.get("zone_letter"), job.get("zone_name"))
        clock = local_clock(job["measured_at"])
        # ----- frost -----
        frow, fstatus, _night = F.frost_row(h, job["context"])
        if fstatus != "ok":
            out.append({**base, "model": "frost", "status": fstatus, "state": None,
                        "model_version": self.models.frost_version})
        else:
            r = M.frost_predict(pd.DataFrame([frow]), self.models.frost)
            state = "frost_risk" if r.alarm else "no_frost"
            p = r.probability
            certainty = ("likely" if p >= LIKELY_FROST else "unsure") if r.alarm else \
                ("likely" if p < r.threshold / 2 else "unsure")
            towards = 1.0 if r.alarm else -1.0
            facts = top_factors(r.shap, r.prepared, self.frost_ref, FROST_FEATURES, towards)
            out.append(self._finish(base, "frost", state, p, certainty, {"frost": round(p, 4)}, r.threshold, facts,
                                    self.models.frost_version, prev.get("frost"), zone_ar, zone_fr, job, clock,
                                    explain_on))
        # ----- stress -----
        if srow is None:
            out.append({**base, "model": "stress", "status": "not_enough_data", "state": None,
                        "model_version": self.models.stress_version})
        else:
            r = M.stress_predict(pd.DataFrame([srow]), self.models.stress)
            certainty = "likely" if r.confidence >= likely_min else "unsure"
            facts = top_factors(r.shap, r.model_input, self.stress_ref, STRESS_FEATURES, 1.0)
            out.append(self._finish(base, "stress", r.state, r.confidence, certainty,
                                    {k: round(v, 4) for k, v in r.probabilities.items()}, None, facts,
                                    self.models.stress_version, prev.get("stress"), zone_ar, zone_fr, job, clock,
                                    explain_on))
        return out

    def _finish(self, base, model, state, conf, certainty, probs, threshold, factors, version, prev, zone_ar,
                zone_fr, job, clock, explain_on) -> dict:
        key = explanation_key(model, state, certainty, factors, zone_fr)
        facts = build_facts(model, state, certainty, factors, zone_ar, zone_fr, job.get("latest") or {}, clock)
        return {**base, "model": model, "status": "ok", "state": state, "confidence": round(float(conf), 4),
                "certainty": certainty, "probabilities": probs, "threshold": threshold, "factors": factors,
                "explanation": None, "explanation_source": "template", "explanation_key": key,
                "model_version": version, "_facts": facts, "_previous": prev}


def build(env: dict | None = None) -> Worker:
    env = env or read_env()
    missing = [k for k in ("SUPABASE_URL", "SUPABASE_ANON_KEY", "ML_WORKER_KEY") if not env.get(k)]
    if missing:
        raise SystemExit(f"Missing in dashboard/backend/.env: {', '.join(missing)} (see PROJECT_STATUS.md section 18)")
    if not re.match(r"^lml_[0-9a-f]{64}$", env["ML_WORKER_KEY"]):
        raise SystemExit("ML_WORKER_KEY must look like lml_ + 64 letters/digits (select public.ml_worker_new_key('ML-01');)")
    models = M.load(env.get("ML_MODELS_DIR"))
    for w in models.warnings:
        log.warning("model: %s", w)
    db = Supabase(env["SUPABASE_URL"], env["SUPABASE_ANON_KEY"], env["ML_WORKER_KEY"],
                  ipv4_only=env.get("SUPABASE_IPV4_ONLY", "").lower() == "true")
    explainer = Explainer(env.get("GROQ_API_KEY", ""), "qwen/qwen3.8-27b",
                          per_minute=int(env.get("ML_GROQ_PER_MINUTE") or 6),
                          url=env.get("ML_GROQ_URL") or "https://api.groq.com/openai/v1/chat/completions")
    return Worker(db, models, explainer)


def main(argv: list[str] | None = None) -> None:
    ap = argparse.ArgumentParser(description="LOOZ ML worker (frost + stress predictions)")
    ap.add_argument("--once", action="store_true", help="one round, then stop")
    args = ap.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)   # (its lines would show the URLs)
    env = read_env()
    worker = build(env)
    poll = max(2.0, float(env.get("ML_POLL_SECONDS") or 10))
    log.info("ML worker started (models %s, %s), every %.0f s", worker.models.frost_version,
             worker.models.stress_version, poll)
    while True:
        try:
            r = worker.run_once()
        except Exception as e:  # keep running: the next round tries again
            log.error("round failed: %s", str(e)[:300])
            r = {"jobs": 0}
        if args.once:
            print(r)
            return
        time.sleep(1.0 if r.get("jobs", 0) >= 50 else poll)


if __name__ == "__main__":
    sys.exit(main())
