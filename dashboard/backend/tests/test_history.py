"""GET /api/farmers/{id}/history (3-day charts, alert log, sensor problems,
admin actions) and what the DEMO ADMIN sees of the farmers (fake tables)."""
from datetime import datetime, timedelta, timezone

import pytest

from tests.test_farmers import DEMO, DEMO_ORCHARD, EXPIRED, FREE, OLD_DEMO, OLD_ORCHARD, VISIT, tables  # noqa: F401

# measured_at of the boxes of the demo orchard in the fixture (simulated time).
LATEST = datetime(2026, 6, 15, 9, 0, tzinfo=timezone.utc)


def reading(node, hours_before, **values):
    row = {"node_id": node, "measured_at": (LATEST - timedelta(hours=hours_before)).isoformat(),
           "soil_moisture_pct": 30.0, "air_temp_c": 25.0, "water_stress": 10, "heat_stress": 5,
           "battery_pct": 90.0, "level": "ok", "faults": []}
    row.update(values)
    return row


def event(id_, node, code, letter, orchard=DEMO_ORCHARD, **values):
    row = {"id": id_, "orchard_id": orchard, "node_id": node, "device_code": code, "zone_letter": letter,
           "measured_at": LATEST.isoformat(), "received_at": LATEST.isoformat(), "level": "warning",
           "previous_level": "watch", "reasons": ["water_stress"], "cause": "water", "confidence": 0.7,
           "water_stress": 66, "heat_stress": 10, "soil_moisture_pct": 18.2, "air_temp_c": 31.0, "faults": []}
    row.update(values)
    return row


def action(id_, act, target_type, target_id, admin_name, is_demo=False, reason=None):
    return {"id": id_, "created_at": (LATEST - timedelta(minutes=10 - id_)).isoformat(), "admin_name": admin_name,
            "action": act, "target_type": target_type, "target_id": target_id, "target_label": target_id,
            "reason": reason, "details": {}, "is_demo": is_demo}


@pytest.fixture
def history_tables(tables):  # noqa: F811
    t = dict(tables)
    t["node_readings"] = (
        [reading("n1", h) for h in (73, 2, 0, 71.5, 1)]          # 73 h before the latest: not shown
        + [reading("n2", 0.5, level="warning", water_stress=66)]
        + [reading("n4", 0.25, soil_moisture_pct=0.0, level="sensor", faults=["soil_probe_disconnected"]),
           reading("n4", 0.5, battery_pct=250.0, faults=["battery_out_of_range"])]
        + [reading("o1", 1)]                                       # another orchard
    )
    t["iot_alert_log"] = [
        event(1, "n2", "NODE-02", "B"),
        event(2, "n4", "NODE-04", "D", level="sensor", reasons=None, cause="sensor", faults=None),
        event(3, "o1", "DEMO-A", "A", orchard=OLD_ORCHARD),
        event(4, "n3", "NODE-03", "C", measured_at=(LATEST - timedelta(hours=2)).isoformat()),  # received last
    ]
    t["node_fault_days"] = [
        {"node_id": "n4", "day": "2026-06-14", "code": "soil_moisture_out_of_range", "count": 5,
         "first_at": "2026-06-14T10:00:00+00:00", "last_at": "2026-06-14T20:00:00+00:00"},
        {"node_id": "n4", "day": "2026-06-15", "code": "soil_moisture_out_of_range", "count": 3,
         "first_at": "2026-06-15T01:00:00+00:00", "last_at": "2026-06-15T08:45:00+00:00"},
        {"node_id": "n4", "day": "2026-05-01", "code": "battery_low", "count": 9,              # older than 14 days
         "first_at": "2026-05-01T01:00:00+00:00", "last_at": "2026-05-01T02:00:00+00:00"},
        {"node_id": "o1", "day": "2026-06-15", "code": "battery_low", "count": 1,              # another orchard
         "first_at": "2026-06-15T01:00:00+00:00", "last_at": "2026-06-15T01:00:00+00:00"},
    ]
    t["admin_actions"] = [
        action(1, "node_unaccept", "node", "n4", "Hajer", reason="Essai"),
        action(2, "node_accept", "node", "n4", "Démo Admin", is_demo=True),
        action(3, "gateway_new_key", "gateway", "GW-01", "SQL Editor"),
        action(4, "node_accept", "node", "zz", "Hajer"),                                     # another box
    ]
    return t


def test_charts_show_the_3_days_before_the_latest_measure(client_with, history_tables):
    h = client_with(history_tables).get(f"/api/farmers/{DEMO}/history").json()
    assert h["window_end"].startswith("2026-06-15T09:00:00")
    assert h["window_start"].startswith("2026-06-12T09:00:00")
    assert h["time_mode"] == "demo"
    assert [(s["zone_letter"], s["device_code"]) for s in h["series"]] == [
        ("A", "NODE-01"), ("B", "NODE-02"), ("C", "NODE-03"), ("D", "NODE-04")]
    n1 = h["series"][0]["points"]
    assert len(n1) == 4                                            # 73 h before: not shown
    assert [p["t"] for p in n1] == sorted(p["t"] for p in n1)      # oldest first
    assert n1[-1] == {"t": n1[-1]["t"], "soil": 30.0, "air": 25.0, "water": 10, "heat": 5, "battery": 90.0, "level": "ok"}
    assert h["series"][1]["points"][0]["water"] == 66
    assert h["series"][2]["points"] == []


def test_alert_log_of_this_orchard_only_newest_first(client_with, history_tables):
    alerts = client_with(history_tables).get(f"/api/farmers/{DEMO}/history").json()["alerts"]
    assert [a["id"] for a in alerts] == [2, 1, 4]                     # by time of measure, newest first
    assert alerts[0]["reasons"] == [] and alerts[0]["faults"] == []     # null lists of the view -> []


def test_sensor_problems_grouped_over_14_days(client_with, history_tables):
    faults = client_with(history_tables).get(f"/api/farmers/{DEMO}/history").json()["faults"]
    assert len(faults) == 1
    f = faults[0]
    assert (f["device_code"], f["zone_letter"], f["code"], f["days"], f["count"]) == (
        "NODE-04", "D", "soil_moisture_out_of_range", 2, 8)
    assert f["first_at"].startswith("2026-06-14T10:00") and f["last_at"].startswith("2026-06-15T08:45")


def test_admin_actions_on_the_boxes_gateway_and_visit(client_with, history_tables):
    actions = client_with(history_tables).get(f"/api/farmers/{DEMO}/history").json()["actions"]
    assert [(a["action"], a["admin_name"]) for a in actions] == [
        ("gateway_new_key", "SQL Editor"), ("node_accept", "Démo Admin"), ("node_unaccept", "Hajer")]
    assert actions[2]["reason"] == "Essai"


def test_the_demo_admin_never_sees_the_name_of_a_real_admin(client_with, history_tables):
    actions = client_with(history_tables, demo=True).get(f"/api/farmers/{DEMO}/history").json()["actions"]
    assert [a["admin_name"] for a in actions] == ["SQL Editor", "Démo Admin", "Administrateur"]


def test_farmer_without_orchard(client_with, history_tables):
    h = client_with(history_tables).get(f"/api/farmers/{FREE}/history").json()
    assert h["series"] == [] and h["alerts"] == [] and h["window_end"] is None


def test_history_404_for_unknown_or_not_a_farmer(client_with, history_tables):
    c = client_with(history_tables)
    assert c.get("/api/farmers/not-a-uuid/history").status_code == 404
    assert c.get("/api/farmers/ee000000-0000-4000-8000-000000000099/history").status_code == 404


def test_the_demo_admin_sees_demo_accounts_only(client_with, history_tables):
    c = client_with(history_tables, demo=True)
    names = {f["name"] for f in c.get("/api/farmers").json()["farmers"]}
    assert names == {"Demo IoT", "Salim Test"}          # not Mounir, not Karim (real accounts)
    assert c.get(f"/api/farmers/{EXPIRED}").status_code == 404
    assert c.get(f"/api/farmers/{EXPIRED}/history").status_code == 404
    assert c.get(f"/api/farmers/{OLD_DEMO}").status_code == 200
    # The real admin sees everybody.
    assert len(client_with(history_tables).get("/api/farmers").json()["farmers"]) == 4


def test_visit_of_the_farmer_page_has_its_id(client_with, history_tables):
    visit = client_with(history_tables).get(f"/api/farmers/{DEMO}").json()["visit"]
    assert visit["id"] == VISIT and visit["status"] == "installed"


def test_a_value_the_box_flags_as_wrong_is_not_drawn(client_with, history_tables):
    n4 = client_with(history_tables).get(f"/api/farmers/{DEMO}/history").json()["series"][3]["points"]
    probe_off, battery_bad = n4[1], n4[0]        # oldest first: 0.5 h before, then 0.25 h before
    assert probe_off["soil"] is None and probe_off["water"] is None       # 0 % of a disconnected probe
    assert probe_off["air"] == 25.0 and probe_off["level"] == "sensor"    # the other values stay
    assert battery_bad["battery"] is None and battery_bad["soil"] == 30.0
