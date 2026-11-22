"""LIVE test against the REAL Supabase (read only), with Node-RED running.

What it needs, in dashboard/backend/.env (never in git, never printed):
    SUPABASE_URL, SUPABASE_ANON_KEY            (already there)
    LIVE_ADMIN_EMAIL, LIVE_ADMIN_PASSWORD      (the admin login of the dashboard)
Run (Node-RED of iot/node-red running, with its key in iot/node-red/.env):
    cd dashboard\\backend
    .venv\\Scripts\\Activate.ps1
    pytest tests_live -v
Without LIVE_ADMIN_* the tests are skipped.

It also logs in as the IoT demo farmer +216 22 777 001 with the demo login
(the normal app login: any code), to check what a farmer may read.
"""
import os
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
import pytest
from dotenv import dotenv_values
from fastapi.testclient import TestClient

ENV = {**dotenv_values(Path(__file__).resolve().parent.parent / ".env"), **os.environ}
URL = (ENV.get("SUPABASE_URL") or "").rstrip("/")
PUBLIC_KEY = ENV.get("SUPABASE_ANON_KEY") or ""
EMAIL, PASSWORD = ENV.get("LIVE_ADMIN_EMAIL"), ENV.get("LIVE_ADMIN_PASSWORD")
DEMO_PHONE = "+21622777001"
# Same as the API: SUPABASE_IPV4_ONLY=true -> IPv4 only (a network with a broken IPv6).
HTTP = httpx.Client(timeout=60, transport=httpx.HTTPTransport(local_address="0.0.0.0")
                    if str(ENV.get("SUPABASE_IPV4_ONLY", "")).lower() == "true" else None)
pytestmark = pytest.mark.skipif(not (URL and PUBLIC_KEY and EMAIL and PASSWORD),
                                reason="LIVE_ADMIN_EMAIL / LIVE_ADMIN_PASSWORD not in dashboard/backend/.env")


def ago(value: str | None) -> timedelta:
    return datetime.now(timezone.utc) - datetime.fromisoformat(value.replace("Z", "+00:00"))


@pytest.fixture(scope="module")
def admin_token():
    r = HTTP.post(f"{URL}/auth/v1/token?grant_type=password", headers={"apikey": PUBLIC_KEY},
                   json={"email": EMAIL, "password": PASSWORD})
    assert r.status_code == 200, f"admin login failed ({r.status_code})"
    return r.json()["access_token"]


@pytest.fixture(scope="module")
def api(admin_token):
    from app.main import app   # the REAL API, with the real settings of .env
    client = TestClient(app)
    client.headers["Authorization"] = f"Bearer {admin_token}"
    return client


@pytest.fixture(scope="module")
def demo(api):
    farmers = api.get("/api/farmers", params={"q": "22777001"}).json()["farmers"]
    assert len(farmers) == 1, farmers
    return farmers[0]


@pytest.fixture(scope="module")
def farmer_token():
    """The demo farmer, logged in like the app does (demo login, any code)."""
    fn = f"{URL}/functions/v1/demo-auth"
    h = {"apikey": PUBLIC_KEY, "Authorization": f"Bearer {PUBLIC_KEY}"}
    r = HTTP.post(fn, headers=h, json={"action": "start", "phone": DEMO_PHONE, "signUp": False})
    assert r.json().get("demo") is True, r.text
    r = HTTP.post(fn, headers=h, json={"action": "verify", "phone": DEMO_PHONE, "code": "135790",
                                        "signUp": False, "language": "ar"})
    refresh = r.json()["refresh_token"]
    r = HTTP.post(f"{URL}/auth/v1/token?grant_type=refresh_token", headers={"apikey": PUBLIC_KEY},
                   json={"refresh_token": refresh})
    return r.json()["access_token"]


def rest(token, path):
    r = HTTP.get(f"{URL}/rest/v1/{path}", headers={"apikey": PUBLIC_KEY, "Authorization": f"Bearer {token}"},
                  timeout=30)
    return r.status_code, r.json()


# ---------- the admin dashboard API ----------

def test_admin_is_admin(api):
    me = api.get("/api/me").json()
    assert me["role"] == "admin"


def test_demo_farmer_in_the_list(demo):
    # The name may change (demo video: "عادل البقلوطي", supabase/seed/demo_recording_setup.sql).
    assert demo["name"] and demo["phone"] == DEMO_PHONE and demo["governorate"] == "sfax"
    assert demo["pack"]["plan"] == "paid" and demo["pack"]["active"] and demo["pack"]["nodes"] == 4
    assert demo["orchard_status"] == "complete" and demo["zones"] == 4 and demo["boxes"]["total"] == 4
    assert demo["demo_time"] is True


def test_demo_orchard_matches_node_red(api, demo):
    d = api.get(f"/api/farmers/{demo['id']}").json()
    assert [(z["letter"], z["cultivar"], 2026 - z["planted_year"]) for z in d["zones"]] == [
        ("A", "Nonpareil", 8), ("B", "Nonpareil", 10), ("C", "Tuono", 12), ("D", "Ferraduel", 4)]
    assert [z["tree_codes"] for z in d["zones"]] == [
        ["TREE-012", "TREE-013", "TREE-014", "TREE-027", "TREE-028"],
        ["TREE-042", "TREE-043", "TREE-044", "TREE-058"],
        ["TREE-073", "TREE-074", "TREE-075", "TREE-076", "TREE-077"],
        ["TREE-089", "TREE-090", "TREE-091", "TREE-092"]]
    assert [(b["zone_letter"], b["device_code"]) for b in d["boxes"]] == [
        ("A", "NODE-01"), ("B", "NODE-02"), ("C", "NODE-03"), ("D", "NODE-04")]
    assert all(b["installed_at"] for b in d["boxes"])
    gw = d["gateways"]
    assert [(g["code"], g["time_mode"], g["enabled"]) for g in gw] == [("GW-01", "demo", True)]
    assert "key_hash" not in str(gw)


def test_node_red_data_arrives_live(api, demo):
    """Node-RED must be running: a batch every minute, nothing refused."""
    d1 = api.get(f"/api/farmers/{demo['id']}").json()
    gw = d1["gateways"][0]
    assert gw["last_seen_at"] and ago(gw["last_seen_at"]) < timedelta(minutes=3), "Node-RED is not sending"
    assert gw["last_result"]["refused"] == {}, gw["last_result"]
    for b in d1["boxes"]:
        assert b["status"] in ("online", "sensor_problem"), (b["device_code"], b["status"])
        assert ago(b["received_at"]) < timedelta(minutes=3)
        assert b["level"] in ("ok", "info", "watch", "warning", "critical", "sensor")
    # One more batch: the simulated clock has moved (12 ticks of 15 min per minute).
    time.sleep(75)
    d2 = api.get(f"/api/farmers/{demo['id']}").json()
    for b1, b2 in zip(d1["boxes"], d2["boxes"]):
        assert b2["measured_at"] > b1["measured_at"], b1["device_code"]


def test_old_demo_orchard_untouched(api):
    farmers = api.get("/api/farmers", params={"q": "22123456"}).json()["farmers"]
    assert len(farmers) == 1
    d = api.get(f"/api/farmers/{farmers[0]['id']}").json()
    assert [b["device_code"] for b in d["boxes"]] == ["DEMO-A", "DEMO-B", "DEMO-C", "DEMO-D"]
    assert {b["status"] for b in d["boxes"]} == {"installed"}       # accepted, never sent data
    assert d["gateways"] == []


# ---------- what the farmer himself may read (database rules) ----------

def test_farmer_reads_only_his_own_boxes(farmer_token):
    st, latest = rest(farmer_token, "node_latest?select=node_id,level")
    assert st == 200 and len(latest) == 4
    st, status = rest(farmer_token, "iot_node_status?select=device_code,status")
    assert st == 200 and sorted(s["device_code"] for s in status) == ["NODE-01", "NODE-02", "NODE-03", "NODE-04"]
    st, gateways = rest(farmer_token, "gateways?select=code")
    assert st == 200 and gateways == []          # never the gateways


def test_visitor_reads_nothing():
    st, _ = rest(PUBLIC_KEY, "node_latest?select=node_id")
    assert st in (401, 403)


# ---------- the Edge Function refuses strangers ----------

def test_ingest_refuses_without_a_good_key():
    fn = f"{URL}/functions/v1/iot-ingest"
    assert HTTP.get(fn).status_code == 405
    assert HTTP.post(fn, json={"gateway": "GW-01", "readings": []}).status_code == 401
    r = HTTP.post(fn, json={"gateway": "GW-01", "readings": []},
                   headers={"x-looz-gateway-key": "lgw_" + "0" * 64})
    assert r.status_code == 401 and r.json() == {"error": "bad_key"}
