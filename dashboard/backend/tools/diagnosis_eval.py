"""Compares photo diagnosis models on ONE fixed test set of 9 photos.

Run from dashboard/backend, venv active (ROBOFLOW_API_KEY in backend/.env:
read here, NEVER printed; delete the line after use):

    python tools/diagnosis_eval.py model almond-diseases-detection-l7tfx/2
    python tools/diagnosis_eval.py model looz-almond-leaves/1        (our own model, Milestone 3)
    python tools/diagnosis_eval.py workflow hajer-ayadi-obltz/general-segmentation-api-2

The 7 leaf photos (Wikimedia Commons, free licences) are in tools/test_photos/ (ignored by
git; CREDITS.md there gives each page to download it again); the app's almond-blossom
picture and a plain green picture are the "not a leaf" photos.

The jury rule (15 Nov 2026): at least 3 of the 4 diseases found as SOME disease, and at
most 1 false alarm on the 5 "none" photos. A result counts from 0.40 (the "غير متأكد"
threshold of the app, app_settings.diagnosis_unsure).
"""
import base64
import statistics
import sys
import time
from pathlib import Path

import httpx
from dotenv import dotenv_values

HERE = Path(__file__).resolve().parent
PHOTOS = HERE / "test_photos"
BLOSSOMS = HERE.parent.parent.parent / "mobile_app" / "assets" / "images" / "almond_blossoms.jpg"
SHOWN = 0.40
CLASSES = ["shot_hole", "leaf_curl", "leaf_spot"]
# Prompt sets of the workflow (SAM 3 is prompted with words): prompt -> our code.
PROMPTS = {
    "the 3 class names": {"leaf_curl": "leaf_curl", "leaf_spot": "leaf_spot", "shot_hole": "shot_hole"},
    "plain words": {"curled red leaf": "leaf_curl", "brown spots on leaf": "leaf_spot", "holes in leaf": "shot_hole"},
}
# The fixed test set: (name, photo, the right answer). The 7 leaf photos are in
# tools/test_photos/ (Wikimedia Commons, see CREDITS.md there; not in git).
TEST_SET = [
    ("shot-hole leaf", "shot_hole_1.jpg", "shot_hole"),
    ("shot-hole close-up 1", "shot_hole_2.jpg", "shot_hole"),
    ("shot-hole close-up 2", "shot_hole_3.jpg", "shot_hole"),
    ("leaf curl", "leaf_curl_1.jpg", "leaf_curl"),
    ("healthy almond", "almond_healthy_2.jpg", None),
    ("autumn almond leaves", "almond_healthy_1.jpg", None),
    ("olive leaf", "olive_1.jpg", None),
    ("not a leaf: blossoms", BLOSSOMS, None),
    ("not a leaf: green picture", "GREEN", None),
]
HTTP = httpx.Client(timeout=120, transport=httpx.HTTPTransport(local_address="0.0.0.0"))


def green_jpeg() -> bytes:
    """A 64 x 48 green JPEG (no leaf), the same as tests_live/test_live_diagnosis.py."""
    from tests_live.test_live_diagnosis import GREEN
    return GREEN


def photo(src) -> bytes:
    if src == "GREEN":
        return green_jpeg()
    path = src if isinstance(src, Path) else PHOTOS / src
    if not path.exists():
        sys.exit(f"{path.name} is missing: download it from its page in tools/test_photos/CREDITS.md")
    return path.read_bytes()


def score(found: dict, expected) -> str:
    shown = {c: v for c, v in found.items() if v >= SHOWN}
    if expected is None:
        return "false alarm" if shown else "correct"
    if expected in shown:
        return "correct"
    return "wrong disease" if shown else "missed"


def report(title: str, rows: list):
    print(f"\n== {title}")
    print(f"{'photo':28} {'expected':10} {'found (>= 0.40; weaker in brackets)':44} {'result':14} time")
    for name, expected, found, result, secs in rows:
        txt = ", ".join(f"{c} {v:.2f}" if v >= SHOWN else f"({c} {v:.2f})"
                        for c, v in sorted(found.items(), key=lambda kv: -kv[1])) or "-"
        print(f"{name:28} {expected or 'none':10} {txt:44} {result:14} {secs:.1f} s")
    sick = [r for r in rows if r[1]]
    none = [r for r in rows if not r[1]]
    found_any = sum(r[3] in ("correct", "wrong disease") for r in sick)
    alarms = sum(r[3] == "false alarm" for r in none)
    print(f"   diseases found: {found_any}/{len(sick)} (right name: {sum(r[3] == 'correct' for r in sick)}), "
          f"false alarms: {alarms}/{len(none)}, median {statistics.median(r[4] for r in rows):.1f} s per photo")
    passed = found_any >= 3 and alarms <= 1
    print(f"   JURY RULE (>= 3/4 found, <= 1 false alarm): {'PASS' if passed else 'FAIL'}")


def run(kind: str, target: str):
    key = (dotenv_values(".env").get("ROBOFLOW_API_KEY") or "").strip()
    if not key:
        sys.exit("ROBOFLOW_API_KEY is not in dashboard/backend/.env")
    auth = {"Authorization": f"Bearer {key}"}
    prompt_sets = PROMPTS if kind == "workflow" else {"": None}
    for label, prompts in prompt_sets.items():
        rows = []
        for name, src, expected in TEST_SET:
            data = base64.b64encode(photo(src)).decode()
            t0 = time.time()
            if kind == "model":
                # Like the Edge Function "diagnose": weak guesses from 0.25 shown in brackets.
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
                print(f"{name}: HTTP {r.status_code} {r.text[:150].replace(key, '<key>')}")
                continue
            found = {}
            for p in _predictions(r.json()):
                code = (prompts or {c: c for c in CLASSES}).get(str(p["class"]).strip())
                if code:
                    found[code] = max(found.get(code, 0.0), float(p["confidence"]))
            rows.append((name, expected, found, score(found, expected), secs))
        report(f"{kind} {target}" + (f", prompts = {label}" if label else ""), rows)


def _predictions(obj):
    if isinstance(obj, dict):
        if "class" in obj and "confidence" in obj:
            yield obj
        for v in obj.values():
            yield from _predictions(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _predictions(v)


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("model", "workflow"):
        sys.exit(__doc__)
    sys.path.insert(0, str(HERE.parent))
    run(sys.argv[1], sys.argv[2])
