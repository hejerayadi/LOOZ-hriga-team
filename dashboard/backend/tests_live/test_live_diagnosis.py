"""LIVE test of the PHOTO DIAGNOSIS (migration 016 + Edge Function "diagnose",
real Roboflow), against the REAL Supabase.

    pytest tests_live/test_live_diagnosis.py -v

Each photo sent uses ONE of the 10 photos of the day of +216 22 777 001 and a
very small part of the Roboflow credits (about 0.0002 credit).
  1. Not logged in -> 401; a Free farmer (22 123 457) -> not_paid.
  2. 22 777 001 sends a small green picture (no leaf): the real model finds
     none of the 3 diseases -> "nothing"; the diagnosis is in the table, he
     reads it (and only he), his photo is in his private folder.
  3. Optional, with REAL leaf photos (paths in backend/.env, never in git):
       LIVE_LEAF_PHOTO=C:/.../shot_hole.jpg      a sick almond leaf
       LIVE_OTHER_PHOTO=C:/.../olive.jpg          an olive leaf / healthy leaf
     -> the codes of the model, the boxes inside the photo, printed.
Needs the app's demo login on (to log in as the app users).
"""
import base64
import os

import pytest

from tests_live.test_live_iot import ENV, HTTP, PUBLIC_KEY, URL
from tests_live.test_live_phase_b import app_get, app_login, headers

FARMER = "+21622777001"      # paid (IoT demo farmer)
FREE_FARMER = "+21622123457"  # Free
FUNCTION = f"{URL}/functions/v1/diagnose"

# A 64 x 48 green JPEG (no leaf).
GREEN = base64.b64decode(
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8t"
    "MC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAAR"
    "CAAwAEADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEG"
    "E1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWG"
    "h4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEB"
    "AQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYk"
    "NOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0"
    "tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDvKKKK/PzxgooooAKKKKACiiigAooooAKK"
    "KKACiiigAooooAKKKKACiiigAooooAKKKKAP/9k="
)


@pytest.fixture(scope="module")
def farmer():
    return app_login(FARMER)


@pytest.fixture(scope="module")
def free_farmer():
    return app_login(FREE_FARMER)


def diagnose(token: str | None, photo: bytes):
    h = {"apikey": PUBLIC_KEY, "Content-Type": "application/json"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    r = HTTP.post(FUNCTION, headers=h, json={"image": base64.b64encode(photo).decode()}, timeout=90)
    if r.status_code == 404:
        pytest.fail('the Edge Function "diagnose" is not deployed')
    return r.status_code, r.json()


def check_answer(a: dict):
    assert a["verdict"] in {"likely", "unsure", "nothing"}, a
    assert a["top_class"] in {None, "shot_hole", "leaf_curl", "leaf_spot"}, a
    for box in a["marked"]:
        assert len(box) == 4 and 0 <= box[0] < box[2] <= 1 and 0 <= box[1] < box[3] <= 1, box
    assert set(a) == {"id", "verdict", "top_class", "top_confidence", "marked", "photo_path", "used_today",
                      "per_day", "created_at"}, sorted(a)


def test_not_logged_in_and_free_farmer(free_farmer):
    h = {"apikey": PUBLIC_KEY, "Content-Type": "application/json"}
    r = HTTP.post(FUNCTION, headers=h, json={"image": base64.b64encode(GREEN).decode()}, timeout=60)
    assert r.status_code == 401, r.text                       # Verify JWT ON (or the function itself)
    status, a = diagnose(free_farmer, GREEN)
    assert (status, a.get("error")) == (200, "not_paid"), a


def test_a_picture_without_a_leaf_finds_nothing(farmer, free_farmer):
    status, a = diagnose(farmer, GREEN)
    if a.get("error") == "limit_day":
        pytest.skip("22 777 001 used his 10 photos today")
    assert status == 200 and "error" not in a, a
    check_answer(a)
    assert a["verdict"] == "nothing" and a["marked"] == [], a
    # In the table, read by him (RLS), not by another farmer.
    rows = app_get(farmer, f"photo_diagnoses?select=id,status,verdict,model&id=eq.{a['id']}")
    assert rows and rows[0]["status"] == "done" and rows[0]["model"] == "roboflow:almond-diseases-detection-l7tfx/2", rows
    assert app_get(free_farmer, f"photo_diagnoses?select=id&id=eq.{a['id']}") == []
    # His photo, in his private folder: he can download it, the other farmer can't.
    path = a["photo_path"]
    assert path.startswith(path.split("/")[0] + "/") and path.endswith(f"/{a['id']}.jpg")
    mine = HTTP.get(f"{URL}/storage/v1/object/authenticated/diagnoses/{path}", headers=headers(farmer))
    assert mine.status_code == 200 and mine.content == GREEN
    other = HTTP.get(f"{URL}/storage/v1/object/authenticated/diagnoses/{path}", headers=headers(free_farmer))
    assert other.status_code in (400, 403, 404), other.status_code
    # The quota of the app: one more used.
    q = HTTP.post(f"{URL}/rest/v1/rpc/my_diagnosis_quota", headers=headers(farmer), json={}).json()
    assert q["paid"] is True and q["used_today"] >= 1 and q["per_day"] == a["per_day"]


@pytest.mark.parametrize("name", ["LIVE_LEAF_PHOTO", "LIVE_OTHER_PHOTO"])
def test_real_photos(farmer, name):
    path = ENV.get(name) or os.environ.get(name)
    if not path:
        pytest.skip(f"{name} not in backend/.env")
    status, a = diagnose(farmer, open(path, "rb").read())
    if a.get("error") == "limit_day":
        pytest.skip("22 777 001 used his 10 photos today")
    assert status == 200 and "error" not in a, a
    check_answer(a)
    print(f"\n{name}: {a['verdict']} {a['top_class']} {a['top_confidence']} marked={len(a['marked'])}")
