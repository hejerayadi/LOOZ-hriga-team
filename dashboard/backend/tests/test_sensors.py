"""GET /api/sensors and the actions on boxes, gateways and installation
visits: each one calls ONE checked function of migration 013 (fake database:
the functions' refusals are copied from the real ones)."""
from datetime import datetime, timedelta, timezone

import pytest

from tests.conftest import db_error
from tests.test_farmers import DEMO, DEMO_ORCHARD, EXPIRED, VISIT, box, tables  # noqa: F401

NOW = datetime.now(timezone.utc)
REAL_ORCHARD = "0c000000-0000-4000-8000-000000000003"
REAL_VISIT = "71000000-0000-4000-8000-000000000002"
NODE = "4e000000-0000-4000-8000-000000000004"


@pytest.fixture
def sensor_tables(tables):  # noqa: F811
    t = dict(tables)
    t["orchards"] = tables["orchards"] + [
        {"id": REAL_ORCHARD, "farmer_id": EXPIRED, "status": "complete", "area": 1.0, "outline": [],
         "is_demo": False, "completed_at": NOW.isoformat()},
    ]
    t["iot_node_status"] = tables["iot_node_status"] + [
        box("r1", "zz", "A", None, "waiting", None, orchard_id=REAL_ORCHARD, farmer_id=EXPIRED, installed_at=None,
            received_at=None, measured_at=None, reasons=None, faults=None, time_mode=None),
    ]
    t["kit_requests"] = [
        {"id": VISIT, "user_id": DEMO, "phone": "+21622777001", "governorate": "sfax", "status": "installed",
         "nodes": 4, "almond_trees": 18, "orchard_area_ha": 0.12, "admin_note": None, "orchard_id": DEMO_ORCHARD,
         "created_at": (NOW - timedelta(hours=3)).isoformat(), "updated_at": NOW.isoformat(),
         "installed_at": NOW.isoformat()},
        {"id": REAL_VISIT, "user_id": EXPIRED, "phone": "+21650000004", "governorate": "gafsa", "status": "new",
         "nodes": 1, "almond_trees": 160, "orchard_area_ha": 2.0, "admin_note": "Appeler le matin",
         "orchard_id": REAL_ORCHARD, "created_at": (NOW - timedelta(days=1)).isoformat(),
         "updated_at": NOW.isoformat(), "installed_at": None},
    ]
    t["gateways"] = [dict(g, created_at=NOW.isoformat()) for g in tables["gateways"]]
    t["admin_actions"] = [
        {"id": 1, "created_at": NOW.isoformat(), "admin_name": "Hajer", "action": "visit_update", "target_type": "visit",
         "target_id": REAL_VISIT, "target_label": "+21650000004", "reason": None, "details": {}, "is_demo": False},
        {"id": 2, "created_at": NOW.isoformat(), "admin_name": "Hajer", "action": "node_unaccept", "target_type": "node",
         "target_id": "n4", "target_label": "NODE-04", "reason": "Essai", "details": {}, "is_demo": False},
        {"id": 3, "created_at": NOW.isoformat(), "admin_name": "Hajer", "action": "price_change", "target_type": "price",
         "target_id": "paid", "target_label": "Prix", "reason": "Test", "details": {}, "is_demo": False},
    ]
    return t


# ---------- Reading ----------

def test_every_box_waiting_first_with_its_farmer(client_with, sensor_tables):
    page = client_with(sensor_tables).get("/api/sensors").json()
    assert [b["status"] for b in page["boxes"]][:3] == ["waiting", "sensor_problem", "offline"]
    first = page["boxes"][0]
    assert (first["farmer_name"], first["farmer_phone"], first["governorate"], first["demo"]) == (
        "Karim", "+21650000004", None, False)
    assert first["faults"] == []
    assert {b["device_code"] for b in page["boxes"]} >= {"NODE-01", "NODE-04", "DEMO-A"}


def test_visits_to_plan_first_with_their_boxes(client_with, sensor_tables):
    visits = client_with(sensor_tables).get("/api/sensors").json()["visits"]
    assert [(v["status"], v["farmer_name"]) for v in visits] == [("new", "Karim"), ("installed", "Demo IoT")]
    assert (visits[1]["boxes_total"], visits[1]["boxes_accepted"]) == (4, 4)
    assert (visits[0]["boxes_total"], visits[0]["boxes_accepted"]) == (1, 0)


def test_gateways_without_their_key(client_with, sensor_tables):
    page = client_with(sensor_tables).get("/api/sensors")
    gw = page.json()["gateways"]
    assert [(g["code"], g["farmer_name"], g["demo"]) for g in gw] == [("GW-01", "Demo IoT", True)]
    assert "key_hash" not in page.text and "ffffffff" not in page.text


def test_latest_actions_on_boxes_gateways_visits_only(client_with, sensor_tables):
    actions = client_with(sensor_tables).get("/api/sensors").json()["actions"]
    assert [a["action"] for a in actions] == ["node_unaccept", "visit_update"]       # not the price


def test_the_demo_admin_sees_demo_things_only(client_with, sensor_tables):
    page = client_with(sensor_tables, demo=True).get("/api/sensors").json()
    assert all(b["demo"] for b in page["boxes"]) and "Karim" not in str(page)
    assert "+21650000004" not in str(page)
    assert [v["farmer_name"] for v in page["visits"]] == ["Demo IoT"]
    assert [(a["action"], a["admin_name"]) for a in page["actions"]] == [("node_unaccept", "Administrateur")]


# ---------- Actions: one checked database function each ----------

def accepted(**params):
    return {"id": params["p_node"], "hardware_id": params["p_device_code"] or "NODE-04",
            "installed_at": NOW.isoformat()}


def test_accept_calls_the_checked_function(client_with):
    c = client_with({}, {"iot_accept_node": accepted})
    r = c.post(f"/api/nodes/{NODE}/accept", json={"device_code": "  ", "reason": "  Visite faite  "})
    assert r.status_code == 200
    assert r.json()["device_code"] == "NODE-04" and r.json()["installed_at"]
    assert c.db.rpc_calls == [("iot_accept_node", {"p_node": NODE, "p_device_code": None, "p_reason": "Visite faite"})]
    c.post(f"/api/nodes/{NODE}/accept", json={})
    assert c.db.rpc_calls[-1][1] == {"p_node": NODE, "p_device_code": None, "p_reason": None}


@pytest.mark.parametrize("pgcode, message, status, code", [
    ("22023", "Reason: 3 to 300 letters", 422, "reason"),
    ("22023", "Device code: 2 to 40 capital letters, digits, - or _", 422, "device_code"),
    ("23505", "The device code NODE-01 is already used by another box", 409, "device_code_taken"),
    ("22023", "Give the device code of the box", 422, "device_code_missing"),
    ("42501", "The demo admin acts only on demo accounts", 403, "demo_only"),
    ("P0002", "Unknown box (or its zone was removed)", 404, "box_zone_removed"),
    ("42501", "Admins only", 403, "admin_only"),
    ("XX000", "something new", 502, "database"),
])
def test_accept_refusals_become_codes(client_with, pgcode, message, status, code):
    def refuse(**params):
        raise db_error(pgcode, message)

    r = client_with({}, {"iot_accept_node": refuse}).post(f"/api/nodes/{NODE}/accept", json={"device_code": "x"})
    assert r.status_code == status
    assert r.json()["detail"] == {"code": code, "message": message}


def test_unaccept_needs_a_reason(client_with):
    c = client_with({}, {"iot_unaccept_node": lambda **p: [{"id": p["p_node"], "hardware_id": "NODE-04",
                                                             "installed_at": None}]})
    assert c.post(f"/api/nodes/{NODE}/unaccept", json={}).status_code == 422
    r = c.post(f"/api/nodes/{NODE}/unaccept", json={"reason": " Boîtier déplacé "})
    assert r.status_code == 200 and r.json()["installed_at"] is None and r.json()["device_code"] == "NODE-04"
    assert c.db.rpc_calls == [("iot_unaccept_node", {"p_node": NODE, "p_reason": "Boîtier déplacé"})]


def test_unknown_ids_are_404_without_asking_the_database(client_with):
    c = client_with({}, {})
    assert c.post("/api/nodes/abc/accept", json={}).status_code == 404
    assert c.post("/api/nodes/abc/unaccept", json={"reason": "abc"}).status_code == 404
    assert c.post("/api/visits/abc", json={"status": "contacted"}).status_code == 404
    assert c.db.rpc_calls == []


def test_new_gateway_key_shown_once_never_cached(client_with):
    c = client_with({}, {"iot_gateway_new_key": lambda p_code: "lgw_" + "a" * 64})
    r = c.post("/api/gateways/gw-01/new-key")
    assert r.status_code == 200
    assert r.json() == {"code": "GW-01", "key": "lgw_" + "a" * 64}
    assert r.headers["cache-control"] == "no-store"
    assert c.db.rpc_calls == [("iot_gateway_new_key", {"p_code": "GW-01"})]


def test_new_gateway_key_refused_to_the_demo_admin(client_with):
    def refuse(p_code):
        raise db_error("42501", "Not with the demo admin account")

    r = client_with({}, {"iot_gateway_new_key": refuse}, demo=True).post("/api/gateways/GW-01/new-key")
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_not_allowed"


def test_bad_gateway_code_is_refused_before_the_database(client_with):
    c = client_with({}, {})
    assert c.post("/api/gateways/GW 01/new-key").status_code in (404, 422)
    assert c.post("/api/gateways/-x/enabled", json={"enabled": False, "reason": "abc"}).status_code == 422
    assert c.db.rpc_calls == []


def test_gateway_on_off(client_with):
    c = client_with({}, {"admin_set_gateway_enabled": lambda **p: {"code": "GW-01", "enabled": p["p_enabled"]}})
    r = c.post("/api/gateways/GW-01/enabled", json={"enabled": False, "reason": "Maintenance"})
    assert r.json()["enabled"] is False
    assert c.db.rpc_calls == [("admin_set_gateway_enabled", {"p_code": "GW-01", "p_enabled": False,
                                                              "p_reason": "Maintenance"})]


def test_visit_status_and_note(client_with):
    c = client_with({}, {"admin_update_visit": lambda **p: {"id": p["p_visit"], "status": p["p_status"] or "new"}})
    r = c.post(f"/api/visits/{REAL_VISIT}", json={"status": "contacted", "note": "Rendez-vous lundi"})
    assert r.json()["status"] == "contacted"
    assert c.db.rpc_calls == [("admin_update_visit", {"p_visit": REAL_VISIT, "p_status": "contacted",
                                                       "p_note": "Rendez-vous lundi"})]

    def closed(**p):
        raise db_error("22023", "This visit is closed (installed)")

    r = client_with({}, {"admin_update_visit": closed}).post(f"/api/visits/{REAL_VISIT}", json={"status": "new"})
    assert r.status_code == 409 and r.json()["detail"]["code"] == "visit_closed"


def test_actions_need_an_admin(client):
    for path, body in [(f"/api/nodes/{NODE}/accept", {}), (f"/api/nodes/{NODE}/unaccept", {"reason": "abc"}),
                       ("/api/gateways/GW-01/new-key", None), ("/api/gateways/GW-01/enabled", {"enabled": True, "reason": "abc"}),
                       (f"/api/visits/{REAL_VISIT}", {}), ("/api/sensors", None), ("/api/overview", None)]:
        r = client.get(path) if path in ("/api/sensors", "/api/overview") else client.post(path, json=body)
        assert r.status_code == 401, path
