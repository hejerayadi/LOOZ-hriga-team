"""LIVE test of Phase A of the admin dashboard, against the REAL Supabase,
with the Node-RED of iot/node-red running (a batch every LOOZ_BATCH_SECONDS).

Milestone A (it CHANGES data, then puts it back):
    NODE-04 "Retirer" -> its readings are refused -> "Accepter" -> they are
    received again; both actions are in the admin action log.
The rest only reads, or checks that something is REFUSED (nothing changes).

Needs in dashboard/backend/.env (never printed): LIVE_ADMIN_EMAIL,
LIVE_ADMIN_PASSWORD; for "Connexion démo" also DEMO_ADMIN_PASSWORD and the
switch app_settings.demo_admin_login_enabled on (otherwise those tests are
skipped).
    cd dashboard\\backend
    .venv\\Scripts\\Activate.ps1
    pytest tests_live -v
"""
import time
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from tests_live.test_live_iot import HTTP, PUBLIC_KEY, URL, admin_token, api, demo, farmer_token  # noqa: F401

DEMO_PHONES = {"+21622777001", "+21622123456", "+21622123457", "+21622123458", "+21622999001", "+21622999003"}
WAIT_SECONDS = 200  # more than 3 batches of 60 s


def now() -> datetime:
    return datetime.now(timezone.utc)


def when(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value.replace("Z", "+00:00")) if value else None


def node04(api, farmer_id):
    d = api.get(f"/api/farmers/{farmer_id}").json()
    box = next(b for b in d["boxes"] if b["device_code"] == "NODE-04")
    return box, d["gateways"][0]


def wait_for(check, what):
    end = time.monotonic() + WAIT_SECONDS
    while time.monotonic() < end:
        result = check()
        if result:
            return result
        time.sleep(5)
    pytest.fail(f"waited {WAIT_SECONDS} s: {what}")


# ---------- Reading ----------

def test_overview_live(api):
    r = api.get("/api/overview")
    assert r.status_code == 200, r.text
    o = r.json()
    assert o["farmers"]["total"] >= 6 and o["boxes"]["total"] >= 8
    assert set(o["todo"]) == {"experts", "boxes_waiting", "sensor_problems", "reports"}


def test_sensors_page_live(api):
    r = api.get("/api/sensors")
    assert r.status_code == 200, r.text
    page = r.json()
    codes = {b["device_code"] for b in page["boxes"]}
    assert {"NODE-01", "NODE-02", "NODE-03", "NODE-04"} <= codes
    assert [g["code"] for g in page["gateways"] if g["code"] == "GW-01"] == ["GW-01"]
    assert "key_hash" not in r.text and "lgw_" not in r.text
    statuses = [b["status"] for b in page["boxes"]]
    assert statuses == sorted(statuses, key=["waiting", "sensor_problem", "offline", "installed", "online"].index)


def test_history_live(api, demo):
    r = api.get(f"/api/farmers/{demo['id']}/history")
    assert r.status_code == 200, r.text
    h = r.json()
    assert [s["device_code"] for s in h["series"]] == ["NODE-01", "NODE-02", "NODE-03", "NODE-04"]
    assert all(len(s["points"]) >= 10 for s in h["series"]), [len(s["points"]) for s in h["series"]]
    assert h["time_mode"] == "demo" and h["window_end"] and h["window_start"]
    span = when(h["window_end"]) - when(h["window_start"])
    assert span.total_seconds() == 72 * 3600
    for s in h["series"]:
        times = [p["t"] for p in s["points"]]
        assert times == sorted(times)
        assert all(when(h["window_start"]) <= when(t) <= when(h["window_end"]) for t in times)


# ---------- Milestone A: NODE-04 Retirer -> refused -> Accepter -> received ----------

def test_milestone_a_node04_remove_then_accept(api, demo):
    box, gw = node04(api, demo["id"])
    assert box["installed_at"], "NODE-04 must be accepted before the test"
    assert box["status"] in ("online", "sensor_problem"), f"Node-RED not sending? NODE-04 is {box['status']}"
    started = now()
    try:
        # 1) Retirer (reason required: without one the database refuses)
        r = api.post(f"/api/nodes/{box['node_id']}/unaccept", json={"reason": "a"})
        assert r.status_code == 422 and r.json()["detail"]["code"] == "reason"
        r = api.post(f"/api/nodes/{box['node_id']}/unaccept", json={"reason": "Jalon A : test du retrait"})
        assert r.status_code == 200 and r.json()["installed_at"] is None, r.text
        removed_at = now()

        # 2) The next batch of Node-RED: NODE-04 refused ("not installed"), the others received
        def refused():
            b, g = node04(api, demo["id"])
            refused_at = when(b["last_refused_at"])
            if b["status"] == "waiting" and refused_at and refused_at > removed_at:
                return b, g
            return None

        b, g = wait_for(refused, "the readings of NODE-04 refused")
        assert b["last_refused_reason"] == "not_installed"
        assert g["last_result"]["refused_devices"].get("NODE-04") == "not_installed", g["last_result"]
        assert g["last_result"]["accepted"] >= 1                     # the 3 other boxes still received
    finally:
        # 3) Accepter (always, so the demo is never left broken)
        r = api.post(f"/api/nodes/{box['node_id']}/accept", json={"reason": "Jalon A : remis en service"})
        assert r.status_code == 200 and r.json()["installed_at"] and r.json()["device_code"] == "NODE-04", r.text
        accepted_at = now()

    # 4) The next batch: NODE-04 received again
    def received():
        b, g = node04(api, demo["id"])
        got = when(b["received_at"])
        return (b, g) if got and got > accepted_at and b["status"] in ("online", "sensor_problem") else None

    b, g = wait_for(received, "NODE-04 received again")
    assert "NODE-04" not in (g["last_result"].get("refused_devices") or {})

    # 5) Both actions in the admin action log (newest first), with their reasons
    actions = api.get(f"/api/farmers/{demo['id']}/history").json()["actions"]
    mine = [a for a in actions if a["target_id"] == box["node_id"] and when(a["created_at"]) >= started]
    assert [(a["action"], a["reason"], a["target_label"]) for a in mine[:2]] == [
        ("node_accept", "Jalon A : remis en service", "NODE-04"),
        ("node_unaccept", "Jalon A : test du retrait", "NODE-04"),
    ], mine
    assert all(a["admin_name"] and not a["is_demo"] for a in mine[:2])
    log = api.get("/api/sensors").json()["actions"]
    assert {"node_accept", "node_unaccept"} <= {a["action"] for a in log if a["target_id"] == box["node_id"]}


# ---------- Refused: nothing changes ----------

def test_a_farmer_cannot_call_the_admin_functions(farmer_token, demo):
    h = {"apikey": PUBLIC_KEY, "Authorization": f"Bearer {farmer_token}"}
    r = HTTP.post(f"{URL}/rest/v1/rpc/iot_gateway_new_key", headers=h, json={"p_code": "GW-01"})
    assert r.status_code in (401, 403) and r.json()["message"] == "Admins only", r.text
    r = HTTP.post(f"{URL}/rest/v1/rpc/admin_overview", headers=h, json={})
    assert r.status_code in (401, 403)
    r = HTTP.get(f"{URL}/rest/v1/admin_actions?select=id", headers=h)
    assert r.status_code == 200 and r.json() == []                   # the log: admins only


def test_the_api_refuses_a_direct_admin_write(admin_token):
    """Migration 013: even an admin writes only through the checked functions."""
    h = {"apikey": PUBLIC_KEY, "Authorization": f"Bearer {admin_token}", "Prefer": "return=minimal"}
    # A filter that matches no box: even if the rule were missing, nothing would change.
    r = HTTP.patch(f"{URL}/rest/v1/nodes?hardware_id=eq.NO-SUCH-BOX", headers=h, json={"installed_at": None})
    assert r.status_code in (401, 403), r.text


# ---------- "Connexion démo" (skipped while its switch is off) ----------

@pytest.fixture(scope="module")
def demo_api():
    from app.main import app
    local = TestClient(app, client=("127.0.0.1", 50000))
    if not local.get("/api/demo-login").json()["enabled"]:
        pytest.skip("Connexion démo off (switch in Supabase, or DEMO_ADMIN_PASSWORD missing in backend/.env)")
    r = local.post("/api/demo-login", headers={"Origin": "http://127.0.0.1:3000"})
    assert r.status_code == 200, r.text
    assert "password" not in r.text.lower()
    client = TestClient(app)
    client.headers["Authorization"] = f"Bearer {r.json()['access_token']}"
    return client


def test_demo_login_from_another_computer_refused():
    from app.main import app
    r = TestClient(app, client=("192.168.1.50", 50000)).post("/api/demo-login")
    assert r.status_code == 403


def test_demo_admin_sees_demo_accounts_only(demo_api, api):
    me = demo_api.get("/api/me").json()
    assert me["role"] == "admin" and me["demo_admin"] is True and me["email"] == "admin-demo@looz-demo.invalid"
    farmers = demo_api.get("/api/farmers").json()["farmers"]
    assert farmers and all(f["phone"] in DEMO_PHONES or f["phone"] is None for f in farmers), [f["phone"] for f in farmers]
    assert "+21622777001" in {f["phone"] for f in farmers}   # the IoT demo farmer (its name may change)
    real = [f for f in api.get("/api/farmers").json()["farmers"] if f["phone"] not in DEMO_PHONES]
    if real:
        assert demo_api.get(f"/api/farmers/{real[0]['id']}").status_code == 404
    page = demo_api.get("/api/sensors").json()
    assert page["boxes"] and all(b["demo"] for b in page["boxes"])
    assert all(v["demo"] for v in page["visits"]) and all(g["demo"] for g in page["gateways"])


def test_demo_admin_refused_where_it_must_be(demo_api, api):
    r = demo_api.post("/api/gateways/GW-01/new-key")
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_not_allowed"
    r = demo_api.post("/api/gateways/GW-01/enabled", json={"enabled": False, "reason": "Essai démo"})
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_not_allowed"
    real_boxes = [b for b in api.get("/api/sensors").json()["boxes"] if not b["demo"]]
    if real_boxes:
        r = demo_api.post(f"/api/nodes/{real_boxes[0]['node_id']}/unaccept", json={"reason": "Essai démo"})
        assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_only"
