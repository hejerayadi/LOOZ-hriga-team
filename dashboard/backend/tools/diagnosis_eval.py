"""Compares photo diagnosis models on ONE fixed test set (tools/test_set.json).

Run from dashboard/backend, venv active. Keys in backend/.env: read here,
NEVER printed (delete the lines after use):

    python tools/diagnosis_eval.py download                  get the photos (not in git)
    python tools/diagnosis_eval.py gemini gemini-3.8-flash    Gemini (GEMINI_VISION_API_KEY), 3 runs per photo
    python tools/diagnosis_eval.py qwen [Qwen/Qwen3-VL-235B-A22B-Instruct:deepinfra]   Qwen3-VL (HF_TOKEN)
    python tools/diagnosis_eval.py groq [qwen/qwen3.8-27b] --old   Qwen on Groq (GROQ_API_KEY), 1 run, 20 s apart
    python tools/diagnosis_eval.py model almond-diseases-detection-l7tfx/2      Roboflow (ROBOFLOW_API_KEY)
    python tools/diagnosis_eval.py workflow hajer-ayadi-obltz/general-segmentation-api-2
Options: --old (only the 9 photos of 15 Nov 2026), --runs N (Gemini, default 3),
         --thinking LOW|MEDIUM|HIGH (Gemini, default LOW), --pause S (seconds between
         calls, default 13: the free tier allows 5 requests per minute per model),
         --fresh (Gemini: start from zero; else it goes on where an earlier start stopped),
         --daily (Gemini: when the free tier's day is used up, wait for the next day and go on).
The free tier of gemini-3.6-flash (project looz-vision, Nov 2026): 5 requests per minute,
20 per day. On it the test set was run ONCE per photo (the first 6 photos 3 times, 16 Nov):
python tools/diagnosis_eval.py gemini gemini-3.6-flash --runs 1 --daily

The test set (50 photos): the 9 old ones (Wikimedia + the app's blossoms + a green
picture) and 41 chosen by hand on iNaturalist (research grade, CC0 / CC BY /
CC BY-SA; authors and links in test_set.json and tools/test_photos/CREDITS.md).
27 sick (shot hole, leaf curl, red leaf blotch = "leaf_spot") and 23 without disease
(healthy and autumn almond, olive, not a leaf: flowers, nuts, a green picture).
Most disease photos are on related Prunus trees (cherry laurel, peach, plum):
open photos of these diseases ON ALMOND are rare. The symptoms are the same.

The jury rule (15 Nov 2026): on the 9 old photos, at least 3 of the 4 diseases
found as SOME disease and at most 1 false alarm on the 5 "none" photos; on the
whole set: high recall on the sick photos and at most 1 false alarm per 5
"none" photos (20 %). A result counts when it is shown to the farmer:
Roboflow from 0.40 (app_settings.diagnosis_unsure); Gemini from SHOWN_GEMINI.
"""
import base64
import json
import os
import statistics
import sys
import time
import urllib.request
from collections import Counter
from pathlib import Path

import httpx
from dotenv import dotenv_values

HERE = Path(__file__).resolve().parent
PHOTOS = HERE / "test_photos"
SET = HERE / "test_set.json"
BLOSSOMS = HERE.parent.parent.parent / "mobile_app" / "assets" / "images" / "almond_blossoms.jpg"
SHOWN = 0.40           # Roboflow: the "غير متأكد" threshold of the app
SHOWN_GEMINI = 0.70    # Gemini / Qwen: shown from here (diagnosis_gemini_unsure of migration 018)
LIKELY_GEMINI = 0.90   # "على الأرجح" from here, with a box and an almond leaf (migration 018)
DISEASES = ["shot_hole", "leaf_curl", "leaf_spot"]
LABELS = DISEASES + ["none", "not_a_leaf"]
# Prompt sets of the Roboflow workflow (SAM 3 is prompted with words): prompt -> our code.
PROMPTS = {
    "the 3 class names": {"leaf_curl": "leaf_curl", "leaf_spot": "leaf_spot", "shot_hole": "shot_hole"},
    "plain words": {"curled red leaf": "leaf_curl", "brown spots on leaf": "leaf_spot", "holes in leaf": "shot_hole"},
}
HTTP = httpx.Client(timeout=120, transport=httpx.HTTPTransport(local_address="0.0.0.0"))
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
# Paid prices (Google, Nov 2026): $ per 1M tokens (input, output + thinking).
# Until 31 Dec 2026; from 1 Jan 2027 both are doubled ($1.50 / $7.50).
PRICES = {"gemini-3.8-flash": (0.75, 3.75), "gemini-3.6-flash": (0.75, 3.75)}
GEMINI_TIMEOUT = 60    # seconds; the farmer waits for this answer

# ---------------------------------------------------------------------
# What Gemini is asked (the same text goes into the Edge Function).
# ---------------------------------------------------------------------
GEMINI_PROMPT = """You check ONE photo sent by an almond farmer in Tunisia through a farming app.
Choose exactly ONE label:
- shot_hole: leaves with small round holes and/or small round red-brown or purple spots, often with a lighter or reddish ring, that dry and fall out ("shot hole", Wilsonomyces carpophilus).
- leaf_curl: leaves thickened, puckered, blistered, curled or twisted, often red, pink, yellow or pale green ("leaf curl", Taphrina deformans).
- leaf_spot: leaves with spots or blotches (red, orange, yellow, brown or black) WITHOUT holes and WITHOUT curling (for example "red leaf blotch", Polystigma).
- none: leaves (almond or another plant) without a visible sign of these diseases. Normal autumn yellowing, dry old leaves, insect bites, hail or mechanical damage: none.
- not_a_leaf: the photo does not show leaves well enough to judge: flowers, fruits or nuts, bark, soil, an object, or a photo too blurry, too dark or too far.
Rules:
- Judge only what you SEE. Do not guess a disease from the season or the place.
- Be conservative: when the signs are weak, unclear or could be something else, lower the confidence; when you see no clear sign, answer none or not_a_leaf.
- confidence: from 0 to 1, how sure you are that the label is right.
- reason: at most 15 words, English.
- plant: almond, olive, other or unknown (what the leaves look like).
- boxes: up to 5 boxes around the clearest disease signs (empty for none and not_a_leaf). Each box_2d is [ymin, xmin, ymax, xmax] normalized to 0-1000."""

GEMINI_SCHEMA = {
    "type": "object",
    "properties": {
        "label": {"type": "string", "enum": LABELS},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        "reason": {"type": "string"},
        "plant": {"type": "string", "enum": ["almond", "olive", "other", "unknown"]},
        "boxes": {
            "type": "array",
            "maxItems": 5,
            "items": {
                "type": "object",
                "properties": {"box_2d": {"type": "array", "items": {"type": "integer"},
                                          "minItems": 4, "maxItems": 4}},
                "required": ["box_2d"],
            },
        },
    },
    "required": ["label", "confidence", "reason", "plant", "boxes"],
}

# ---------------------------------------------------------------------
# What Qwen3-VL is asked: the same text, only the boxes in Qwen's own format
# ([x1, y1, x2, y2] on 0-1000, how Qwen3-VL is trained). Same text in the
# Edge Function.
# ---------------------------------------------------------------------
QWEN_PROMPT = GEMINI_PROMPT.replace(
    "Each box_2d is [ymin, xmin, ymax, xmax] normalized to 0-1000.",
    "Each bbox_2d is [x1, y1, x2, y2] (left, top, right, bottom) with coordinates normalized to 0-1000.",
) + "\nAnswer with the JSON object only."
QWEN_SCHEMA = json.loads(json.dumps(GEMINI_SCHEMA).replace('"box_2d"', '"bbox_2d"'))
HF_URL = "https://router.huggingface.co/v1/chat/completions"
QWEN_MODEL = "Qwen/Qwen3-VL-235B-A22B-Instruct:deepinfra"
# Hugging Face router, provider prices (no markup), $ per 1M tokens, 19 Nov 2026.
QWEN_PRICES = {
    "Qwen/Qwen3-VL-235B-A22B-Instruct:deepinfra": (0.20, 0.88),
    "Qwen/Qwen3-VL-30B-A3B-Instruct:deepinfra": (0.15, 0.60),
    "Qwen/Qwen3-VL-8B-Instruct:parasail": (0.25, 0.75),
}


def env_key(name: str) -> str:
    key = (dotenv_values(HERE.parent / ".env").get(name) or "").strip()
    if not key:
        sys.exit(f"{name} is not in dashboard/backend/.env")
    return key


def load_set(old_only: bool) -> list[dict]:
    photos = json.load(open(SET, encoding="utf-8"))["photos"]
    return [p for p in photos if p["old"] or not old_only]


def green_jpeg() -> bytes:
    """A 64 x 48 green JPEG (no leaf), the same as tests_live/test_live_diagnosis.py."""
    from tests_live.test_live_diagnosis import GREEN
    return GREEN


def photo(item: dict) -> bytes:
    if item["file"] == "GREEN":
        return green_jpeg()
    path = BLOSSOMS if item["file"] == "BLOSSOMS" else PHOTOS / item["file"]
    if not path.exists():
        sys.exit(f"{path.name} is missing: python tools/diagnosis_eval.py download "
                 f"(or by hand: {item.get('source')})")
    return path.read_bytes()


def download():
    """The iNaturalist photos (their open-data address); the old Wikimedia ones by hand."""
    PHOTOS.mkdir(exist_ok=True)
    items = json.load(open(SET, encoding="utf-8"))["photos"]
    got = 0
    for p in items:
        target = PHOTOS / p["file"]
        if not p.get("download") or target.exists():
            if not p.get("download") and p["file"] not in ("GREEN", "BLOSSOMS") and not target.exists():
                print(f"by hand: {p['file']} <- {p['source']}")
            continue
        req = urllib.request.Request(p["download"], headers={"User-Agent": "LoozDiagnosisEval/1.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            target.write_bytes(r.read())
        got += 1
        time.sleep(0.5)
    lines = ["# Test photos of tools/diagnosis_eval.py (not in git)", "",
             "The list, with the right answer of each photo: tools/test_set.json.", ""]
    for p in items:
        if p["file"] in ("GREEN", "BLOSSOMS"):
            continue
        who = f", {p['author']}" if p.get("author") else ""
        lines.append(f"- {p['file']}: {p['kind']} ({p.get('taxon') or 'Wikimedia Commons'}), "
                     f"{p['license']}{who}, {p['source']}")
    (PHOTOS / "CREDITS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{got} photos downloaded; CREDITS.md written")


# ---------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------
def outcome(shown: str | None, expected: str) -> str:
    """shown = the disease shown to the farmer, or None."""
    if expected not in DISEASES:
        return "false alarm" if shown else "correct"
    if shown == expected:
        return "correct"
    return "wrong disease" if shown else "missed"


def summary(title: str, rows: list[dict], old_only: bool):
    """rows: one per photo: {"item", "runs": [{"shown", "label", "conf", "secs", "cost"}]}."""
    print(f"\n== {title}")
    print(f"{'photo':24} {'expected':10} {'answers (label conf) x runs':48} {'majority':14} same")
    for r in rows:
        ans = " | ".join((f"{a['label']} {a['conf']:.2f}" if a.get("conf") is not None else a["label"])
                         + (f" {a['verdict'][0].upper()}" if a.get("verdict") else "") for a in r["runs"])
        same = "-" if r["stable"] is None else "yes" if r["stable"] else "NO"
        print(f"{r['item']['file']:24} {r['item']['expected']:10} {ans[:48]:48} {r['result']:14} {same}")

    def score(subset, label):
        sick = [r for r in subset if r["item"]["expected"] in DISEASES]
        none = [r for r in subset if r["item"]["expected"] not in DISEASES]
        found = sum(r["result"] in ("correct", "wrong disease") for r in sick)
        right = sum(r["result"] == "correct" for r in sick)
        alarms = sum(r["result"] == "false alarm" for r in none)
        print(f"   {label}: sick found {found}/{len(sick)} (right disease {right}), missed "
              f"{sum(r['result'] == 'missed' for r in sick)}, wrong disease "
              f"{sum(r['result'] == 'wrong disease' for r in sick)}, false alarms {alarms}/{len(none)}")
        return found, len(sick), alarms, len(none), right

    old = [r for r in rows if r["item"]["old"]]
    f_old, n_old, a_old, nn_old, _ = score(old, "old 9")
    jury_old = f_old >= 3 and a_old <= 1
    print(f"   JURY RULE on the old 9 (>= 3/4 found, <= 1 false alarm): {'PASS' if jury_old else 'FAIL'}")
    if not old_only:
        f, n, a, nn, right = score(rows, "all")
        for group in ["shot_hole", "leaf_curl", "leaf_spot"]:
            sub = [r for r in rows if r["item"]["expected"] == group]
            print(f"     {group:10}: found {sum(r['result'] in ('correct', 'wrong disease') for r in sub)}/{len(sub)}, "
                  f"right {sum(r['result'] == 'correct' for r in sub)}")
        for kind in sorted({r["item"]["kind"].split(" (")[0] for r in rows if r["item"]["expected"] not in DISEASES}):
            sub = [r for r in rows if r["item"]["kind"].split(" (")[0] == kind]
            print(f"     {kind:32}: false alarms {sum(r['result'] == 'false alarm' for r in sub)}/{len(sub)}")
        recall, alarm_rate = f / n, a / nn
        print(f"   overall: recall on sick {recall:.0%}, right disease {right / n:.0%}, "
              f"false alarms {alarm_rate:.0%} ({a * 5 / nn:.1f} per 5 'none' photos)")
        overall = recall >= 0.80 and alarm_rate <= 0.20
        print(f"   OVERALL RULE (recall >= 80 %, <= 1 false alarm per 5 none): {'PASS' if overall else 'FAIL'}")
    runs = [a for r in rows for a in r["runs"] if a.get("secs") is not None]
    if runs:
        tested = [r for r in rows if r["stable"] is not None]
        print(f"   stability: {sum(r['stable'] for r in tested)}/{len(tested)} photos with several runs gave the "
              f"same answer every run; NOT TESTED for {len(rows) - len(tested)} photos (1 run)")
        print(f"   time median {statistics.median(a['secs'] for a in runs):.1f} s, "
              f"max {max(a['secs'] for a in runs):.1f} s (answered calls only)")
        costs = [a["cost"] for a in runs if a.get("cost") is not None]
        if costs:
            print(f"   cost per photo (paid price): mean ${statistics.mean(costs):.5f}, "
                  f"max ${max(costs):.5f}  (about {statistics.mean(costs) * 1000:.2f} $ per 1,000 photos)")


def finish_row(item: dict, runs: list[dict]) -> dict:
    results = [outcome(a["shown"], item["expected"]) for a in runs]
    majority = Counter(results).most_common(1)[0][0]
    labels = [a["label"] for a in runs]
    # stable: None = not tested (only 1 run).
    return {"item": item, "runs": runs, "result": majority,
            "stable": len(set(labels)) == 1 if len(runs) > 1 else None}


# ---------------------------------------------------------------------
# Gemini
# ---------------------------------------------------------------------
def gemini_once(key: str, model: str, data: bytes, thinking: str) -> dict:
    body = {
        "contents": [{"role": "user", "parts": [
            {"inlineData": {"mimeType": "image/jpeg" if data[:3] == b"\xff\xd8\xff" else "image/png",
                            "data": base64.b64encode(data).decode()}},
            {"text": GEMINI_PROMPT}]}],
        "generationConfig": {"responseMimeType": "application/json", "responseJsonSchema": GEMINI_SCHEMA,
                             "thinkingConfig": {"thinkingLevel": thinking}},
    }
    for attempt in range(4):
        t0 = time.time()
        try:
            r = HTTP.post(GEMINI_URL.format(model=model), headers={"x-goog-api-key": key}, json=body,
                          timeout=GEMINI_TIMEOUT)
        except httpx.TransportError as e:  # timeout or network: counts as a failed try
            print(f"   {type(e).__name__} after {time.time() - t0:.0f} s, trying again")
            time.sleep(10)
            continue
        secs = time.time() - t0
        if r.status_code == 429 or r.status_code >= 500:
            info = r.text.replace(key, "<key>")
            wait = 30
            per_day = False
            try:
                err = r.json()["error"]
                for d in err.get("details", []):
                    if d.get("@type", "").endswith("RetryInfo"):
                        wait = int(float(str(d.get("retryDelay", "30s")).rstrip("s"))) + 2
                    if d.get("@type", "").endswith("QuotaFailure"):
                        for v in d.get("violations", []):
                            print(f"   quota: {v.get('quotaId')} = {v.get('quotaValue')} ({v.get('quotaMetric')})")
                            per_day = per_day or "PerDay" in str(v.get("quotaId"))
            except Exception:  # noqa: BLE001
                pass
            if per_day:
                raise DailyLimit()
            print(f"   HTTP {r.status_code}, waiting {wait} s ({info[:120]})")
            time.sleep(wait)
            continue
        if r.status_code != 200:
            return {"label": f"HTTP {r.status_code}", "shown": None, "conf": None, "secs": secs,
                    "error": r.text.replace(key, "<key>")[:300]}
        answer = r.json()
        usage = answer.get("usageMetadata", {})
        price_in, price_out = PRICES.get(model, (None, None))
        cost = None if price_in is None else (
            usage.get("promptTokenCount", 0) * price_in
            + (usage.get("candidatesTokenCount", 0) + usage.get("thoughtsTokenCount", 0)) * price_out) / 1e6
        try:
            text = answer["candidates"][0]["content"]["parts"][-1]["text"]
            out = json.loads(text)
        except Exception:  # noqa: BLE001
            return {"label": "unreadable", "shown": None, "conf": None, "secs": secs, "cost": cost}
        label, conf = out.get("label"), float(out.get("confidence") or 0)
        shown = label if label in DISEASES and conf >= SHOWN_GEMINI else None
        return {"label": label, "conf": conf, "shown": shown, "secs": secs, "cost": cost,
                "reason": out.get("reason"), "plant": out.get("plant"), "boxes": out.get("boxes"),
                "tokens": [usage.get("promptTokenCount"), usage.get("candidatesTokenCount"),
                           usage.get("thoughtsTokenCount")]}
    return {"label": "no answer", "shown": None, "conf": None, "secs": None}


def judged(a: dict) -> dict:
    """The farmer's view of an answer of Gemini / Qwen, like migration 018:
    shown from 0.70; "likely" from 0.90 with a box and an almond leaf."""
    label, conf = a.get("label"), a.get("conf") or 0.0
    sick = label in DISEASES and conf >= SHOWN_GEMINI
    has_box = any(isinstance(b, dict) and (b.get("box_2d") or b.get("bbox_2d")) for b in (a.get("boxes") or []))
    likely = sick and conf >= LIKELY_GEMINI and has_box and a.get("plant") in ("almond", "unknown")
    return {**a, "shown": label if sick else None,
            "verdict": "likely" if likely else "unsure" if sick else "nothing"}


class NoCredits(Exception):
    """Hugging Face: no credits left (HTTP 402)."""


def qwen_once(key: str, model: str, data: bytes, thinking: str = "") -> dict:
    """Qwen3-VL through the Hugging Face router (OpenAI-compatible)."""
    import os
    url = os.environ.get("HF_ROUTER_URL") or HF_URL   # a fake router for the offline check
    return chat_vlm_once(url, key, model, data, QWEN_PRICES.get(model), "json_schema")


# Groq: OpenAI-compatible; free tier for qwen/qwen3.8-27b (19 Nov 2026, from its
# headers): 1,000 requests a day, 8,000 tokens a minute.
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "qwen/qwen3.8-27b"
GROQ_FORMAT = {"type": "json_schema"}   # becomes json_object if Groq refuses a schema for this model
LIMITS_SEEN: dict = {}


def groq_once(key: str, model: str, data: bytes, thinking: str = "") -> dict:
    import os
    url = os.environ.get("GROQ_URL") or GROQ_URL       # a fake Groq for the offline check
    return chat_vlm_once(url, key, model, data, None, GROQ_FORMAT["type"])


def chat_vlm_once(url: str, key: str, model: str, data: bytes, prices, fmt: str) -> dict:
    """One photo to an OpenAI-compatible vision model (Qwen: Hugging Face or Groq)."""
    mime = "image/jpeg" if data[:3] == b"\xff\xd8\xff" else "image/png"
    response_format = ({"type": "json_schema", "json_schema": {"name": "leaf_diagnosis", "schema": QWEN_SCHEMA,
                                                                "strict": url == HF_URL or "huggingface" in url}}
                       if fmt == "json_schema" else {"type": "json_object"})
    body = {
        "model": model,
        "messages": [{"role": "user", "content": [
            {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{base64.b64encode(data).decode()}"}},
            {"type": "text", "text": QWEN_PROMPT}]}],
        "response_format": response_format,
        "max_tokens": 600,
        "temperature": 0,
    }
    for attempt in range(4):
        t0 = time.time()
        try:
            r = HTTP.post(url, headers={"Authorization": f"Bearer {key}"}, json=body, timeout=GEMINI_TIMEOUT)
        except httpx.TransportError as e:
            print(f"   {type(e).__name__} after {time.time() - t0:.0f} s, trying again")
            time.sleep(10)
            continue
        secs = time.time() - t0
        LIMITS_SEEN.update({k.lower(): v for k, v in r.headers.items() if k.lower().startswith("x-ratelimit-limit")})
        if r.status_code == 402:
            raise NoCredits()
        if (r.status_code == 400 and fmt == "json_schema"
                and ("json_schema" in r.text or "response_format" in r.text)):
            print(f"   a JSON schema is refused for this model: JSON mode instead ({r.text.replace(key, '<key>')[:160]})")
            fmt = "json_object"
            if "groq" in url or os.environ.get("GROQ_URL") == url:
                GROQ_FORMAT["type"] = fmt
            body["response_format"] = {"type": "json_object"}
            continue
        if r.status_code == 429 or r.status_code >= 500:
            wait = 20
            try:
                wait = int(float(r.headers.get("retry-after", "20"))) + 1
            except ValueError:
                pass
            print(f"   HTTP {r.status_code}, waiting {wait} s ({r.text.replace(key, '<key>')[:160]})")
            time.sleep(wait)
            continue
        if r.status_code != 200:
            return {"label": f"HTTP {r.status_code}", "shown": None, "conf": None, "secs": secs,
                    "error": r.text.replace(key, "<key>")[:300]}
        answer = r.json()
        usage = answer.get("usage") or {}
        price_in, price_out = prices or (None, None)
        cost = None if price_in is None else (
            usage.get("prompt_tokens", 0) * price_in + usage.get("completion_tokens", 0) * price_out) / 1e6
        tokens = [usage.get("prompt_tokens"), usage.get("completion_tokens"), None]
        try:
            text = (answer["choices"][0]["message"]["content"] or "").strip()
            if "</think>" in text:       # a model that thinks aloud first
                text = text.split("</think>")[-1].strip()
            if text.startswith("```"):   # ```json ... ``` around it
                text = text.strip("`").removeprefix("json").strip()
            out = json.loads(text)
            label, conf = out["label"], float(out["confidence"])
            if label not in LABELS:
                raise ValueError(label)
        except Exception:  # noqa: BLE001
            # The Edge Function says "unavailable" for this: counted as an answer.
            return {"label": "invalid", "shown": None, "conf": None, "secs": secs, "cost": cost, "tokens": tokens}
        return judged({"label": label, "conf": conf, "secs": secs, "cost": cost, "reason": out.get("reason"),
                       "plant": out.get("plant"), "boxes": out.get("boxes"), "tokens": tokens})
    return {"label": "no answer", "shown": None, "conf": None, "secs": None}


class DailyLimit(Exception):
    """The free tier's requests of the day are used up (per project, per model)."""


def wait_for_reset():
    """Google starts a new free-tier day at midnight Pacific time (09:00 in Tunisia in winter)."""
    from datetime import datetime, timedelta, timezone
    try:
        from zoneinfo import ZoneInfo
        pacific = ZoneInfo("America/Los_Angeles")
    except Exception:  # noqa: BLE001  (no time zone data on this computer)
        pacific = timezone(timedelta(hours=-8))
    now = datetime.now(pacific)
    reset = (now + timedelta(days=1)).replace(hour=0, minute=10, second=0, microsecond=0)
    print(f"   the free tier's limit of the DAY is reached: waiting until "
          f"{reset.astimezone():%d %b %H:%M} (this computer's time)", flush=True)
    time.sleep(max(60.0, (reset - now).total_seconds()))


def run_gemini(model: str, old_only: bool, runs: int, thinking: str, pause: float, fresh: bool,
               daily: bool, provider: str = "gemini"):
    """Saves after each photo; a new start goes on where it stopped (--fresh: from zero).
    Answers already saved are kept (also when there are more runs than asked); a call
    without an answer (busy, timeout) is tried again later. --daily: when the free
    tier's day is used up, waits for the next day and goes on until every photo has
    its answers. provider "qwen": Qwen3-VL through Hugging Face (HF_TOKEN); an answer
    that is not valid JSON counts ("invalid": the app would say "unavailable")."""
    if provider in ("qwen", "groq"):
        key, ask = (env_key("HF_TOKEN"), qwen_once) if provider == "qwen" else (env_key("GROQ_API_KEY"), groq_once)
        out = PHOTOS / f"eval_{provider}_{model.replace('/', '_').replace(':', '_')}.json"
        ok_labels = LABELS + ["invalid"]
    else:
        key, ask = env_key("GEMINI_VISION_API_KEY"), gemini_once
        out = PHOTOS / f"eval_gemini_{model}_{thinking.lower()}.json"
        ok_labels = LABELS
    saved = {} if fresh or not out.exists() else {
        r["file"]: r for r in json.loads(out.read_text(encoding="utf-8"))}
    items = load_set(old_only)
    order = {item["file"]: n for n, item in enumerate(items)}

    def valid(file: str) -> list[dict]:
        return [judged(a) if a["label"] in LABELS else a
                for a in saved.get(file, {}).get("answers", []) if a["label"] in ok_labels]

    def save():
        keep = sorted(saved.values(), key=lambda r: order.get(r["file"], len(order)))
        out.write_text(json.dumps(keep, indent=1, ensure_ascii=False), encoding="utf-8")

    while True:
        missing, day_over = 0, False
        for i, item in enumerate(items, 1):
            answers = valid(item["file"])
            if len(answers) >= runs:
                continue  # done (in this start or an earlier one)
            data = photo(item)
            try:
                while len(answers) < runs:
                    a = ask(key, model, data, thinking)
                    time.sleep(pause)
                    if a["label"] not in ok_labels:
                        print(f"   {item['file']}: {a['label']} - tried again later", flush=True)
                        break
                    answers.append(a)
            except DailyLimit:
                day_over = True
            except NoCredits:
                saved[item["file"]] = {"file": item["file"], "expected": item["expected"], "answers": answers}
                save()
                print("   Hugging Face: NO CREDITS left (HTTP 402): stopped. A free account has no monthly "
                      "credits (PRO: $2 a month); buy credits or use a PRO account.")
                return
            saved[item["file"]] = {"file": item["file"], "expected": item["expected"], "answers": answers}
            save()
            if len(answers) >= runs:
                a = answers[-1]
                print(f"[{i}/{len(items)}] {item['file']}: {[x['label'] for x in answers]} "
                      f"{a.get('conf')} {a.get('plant')} - {a.get('reason')}", flush=True)
            else:
                missing += 1
            if day_over:
                break
        if day_over:
            if not daily:
                done = sum(len(valid(it["file"])) >= runs for it in items)
                print(f"   the free tier's limit of the DAY is reached: {done} of {len(items)} photos "
                      f"done; start again after 09:00 (Tunisia time)")
                return
            wait_for_reset()
            continue
        if not missing:
            break
        if not daily:
            print(f"   {missing} photos without an answer (Google busy): start again later")
            return
        print(f"   {missing} photos without an answer (Google busy): trying again in 10 minutes", flush=True)
        time.sleep(600)
    rows = [finish_row(item, valid(item["file"])) for item in items]
    summary(f"{provider} {model} ({'' if provider != 'gemini' else f'thinking {thinking}, '}{runs} run(s) per new "
            f"photo, shown from {SHOWN_GEMINI}, L = على الأرجح, U = غير متأكد, N = لم نجد)", rows, old_only)
    invalid = sum(a["label"] == "invalid" for r in rows for a in r["runs"])
    if provider != "gemini":
        print(f"   answers that are not valid JSON (the app: \"unavailable\"): {invalid}")
        tok = [a["tokens"][0] for r in rows for a in r["runs"] if a.get("tokens") and a["tokens"][0]]
        if tok:
            print(f"   tokens in per photo: median {statistics.median(tok):.0f}, max {max(tok)}")
    if provider == "groq":
        print(f"   JSON: {GROQ_FORMAT['type']}; limits of the free tier (Groq's headers): {LIMITS_SEEN}")
    print(f"   answers saved: {out.name} (not in git)")


# ---------------------------------------------------------------------
# Roboflow (model or workflow)
# ---------------------------------------------------------------------
def run_roboflow(kind: str, target: str, old_only: bool):
    key = env_key("ROBOFLOW_API_KEY")
    auth = {"Authorization": f"Bearer {key}"}
    prompt_sets = PROMPTS if kind == "workflow" else {"": None}
    for label, prompts in prompt_sets.items():
        rows = []
        for item in load_set(old_only):
            data = base64.b64encode(photo(item)).decode()
            t0 = time.time()
            if kind == "model":
                # Like the Edge Function "diagnose": weak guesses from 0.25.
                r = HTTP.post(f"https://serverless.roboflow.com/{target}?confidence=0.25&overlap=0.3"
                              "&max_detections=100&disable_active_learning=true", content=data,
                              headers={**auth, "Content-Type": "application/x-www-form-urlencoded"})
            else:
                ws, wf = target.split("/", 1)
                r = HTTP.post(f"https://serverless.roboflow.com/infer/workflows/{ws}/{wf}", headers=auth,
                              json={"inputs": {"image": {"type": "base64", "value": data},
                                               "classes": ", ".join(prompts)}})
            secs = time.time() - t0
            if r.status_code != 200:
                print(f"{item['file']}: HTTP {r.status_code} {r.text[:150].replace(key, '<key>')}")
                continue
            found = {}
            for p in _predictions(r.json()):
                code = (prompts or {c: c for c in DISEASES}).get(str(p["class"]).strip())
                if code:
                    found[code] = max(found.get(code, 0.0), float(p["confidence"]))
            best = max(found.items(), key=lambda kv: kv[1]) if found else None
            shown = best[0] if best and best[1] >= SHOWN else None
            rows.append(finish_row(item, [{"label": best[0] if best else "none",
                                           "conf": best[1] if best else None, "shown": shown, "secs": secs}]))
        summary(f"{kind} {target}" + (f", prompts = {label}" if label else ""), rows, old_only)


def _predictions(obj):
    if isinstance(obj, dict):
        if "class" in obj and "confidence" in obj:
            yield obj
        for v in obj.values():
            yield from _predictions(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _predictions(v)


def option(name: str, default):
    if name in sys.argv:
        return type(default)(sys.argv[sys.argv.index(name) + 1])
    return default


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.path.insert(0, str(HERE.parent))
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    old_only = "--old" in sys.argv
    if args[:1] == ["download"]:
        download()
    elif len(args) >= 2 and args[0] == "gemini":
        run_gemini(args[1], old_only, option("--runs", 3), option("--thinking", "LOW").upper(),
                   option("--pause", 13.0), "--fresh" in sys.argv, "--daily" in sys.argv)
    elif args[:1] == ["qwen"]:
        run_gemini(args[1] if len(args) > 1 else QWEN_MODEL, old_only, option("--runs", 3), "",
                   option("--pause", 1.0), "--fresh" in sys.argv, False, provider="qwen")
    elif args[:1] == ["groq"]:
        run_gemini(args[1] if len(args) > 1 else GROQ_MODEL, old_only, option("--runs", 1), "",
                   option("--pause", 20.0), "--fresh" in sys.argv, False, provider="groq")
    elif len(args) >= 2 and args[0] in ("model", "workflow"):
        run_roboflow(args[0], args[1], old_only)
    else:
        sys.exit(__doc__)
