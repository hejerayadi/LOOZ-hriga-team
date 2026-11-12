"""GET /api/farmers and /api/farmers/{id}: the farmers, their pack, orchard,
zones, trees and sensor boxes, read with the admin's token (fake tables)."""
from datetime import datetime, timedelta, timezone

import pytest

NOW = datetime.now(timezone.utc)
DEMO = "ee000000-0000-4000-8000-000000000010"      # +216 22 777 001, the IoT demo farmer
OLD_DEMO = "ee000000-0000-4000-8000-000000000003"  # +216 22 123 456
FREE = "ee000000-0000-4000-8000-000000000008"
EXPIRED = "ee000000-0000-4000-8000-000000000009"
EXPERT = "ee000000-0000-4000-8000-000000000002"
ADMIN_ID = "ee000000-0000-4000-8000-000000000001"
DEMO_ORCHARD, OLD_ORCHARD = "0c000000-0000-4000-8000-000000000001", "0c000000-0000-4000-8000-000000000002"
VISIT = "71000000-0000-4000-8000-000000000001"


def iso(dt):
    return dt.isoformat()


def square(x0, size=14):
    return [{"x": x0, "z": -10.5}, {"x": x0 + size, "z": -10.5}, {"x": x0 + size, "z": 10.5}, {"x": x0, "z": 10.5}]


def box(node, zone, letter, code, status, level=None, **values):
    row = {
        "node_id": node, "zone_id": zone, "orchard_id": DEMO_ORCHARD, "farmer_id": DEMO,
        "zone_letter": letter, "zone_name": "", "zone_color": "#8BC34A", "zone_type": "irrigated",
        "tree_count": 5, "cultivar": "Nonpareil", "planted_year": 2018, "device_code": code,
        "position_x": 0, "position_z": 0, "installed_at": iso(NOW - timedelta(hours=2)), "installed_by": None,
        "received_at": iso(NOW - timedelta(seconds=40)), "last_refused_at": None, "last_refused_reason": None,
        "gateway_id": "9a000000-0000-4000-8000-000000000001", "gateway_code": "GW-01", "time_mode": "demo",
        "measured_at": "2026-06-15T09:00:00+00:00", "soil_moisture_pct": 30.0, "soil_temp_c": 24.0,
        "air_temp_c": 31.0, "humidity_pct": 55.0, "light_par": 1500.0, "vpd_kpa": 2.0, "battery_pct": 90.5,
        "rssi_dbm": -82, "water_stress": 20, "heat_stress": 10, "anomaly": None, "drying_rate_pct_h": 0.3,
        "hours_above_35c": 0.0, "level": level, "reasons": [], "cause": None, "confidence": 0.5, "faults": [],
        "packets_lost": 0, "firmware": "1.2.0", "status": status,
    }
    row.update(values)
    return row


@pytest.fixture
def tables():
    zones = [
        {"id": f"20000000-0000-4000-8000-00000000000{i}", "orchard_id": DEMO_ORCHARD, "letter": letter, "name": "",
         "color": color, "zone_type": "irrigated", "tree_count": n, "cultivar": cultivar, "planted_year": year,
         "boundary": square(-28 + 14 * (i - 1)), "archived_at": None}
        for i, letter, color, n, cultivar, year in [
            (1, "A", "#8BC34A", 5, "Nonpareil", 2018), (2, "B", "#4FC3F7", 4, "Nonpareil", 2016),
            (3, "C", "#FFB74D", 5, "Tuono", 2014), (4, "D", "#BA68C8", 4, "Ferraduel", 2022)]
    ]
    old_zone = {"id": "21000000-0000-4000-8000-000000000001", "orchard_id": OLD_ORCHARD, "letter": "A", "name": "",
                "color": "#8BC34A", "zone_type": "young_trees", "tree_count": 160, "cultivar": None,
                "planted_year": None, "boundary": square(0, 50), "archived_at": None}
    archived_zone = dict(old_zone, id="21000000-0000-4000-8000-000000000009", letter=None,
                         archived_at=iso(NOW - timedelta(days=3)))
    codes = {"A": ["TREE-012", "TREE-013", "TREE-014", "TREE-027", "TREE-028"],
             "B": ["TREE-042", "TREE-043", "TREE-044", "TREE-058"],
             "C": ["TREE-073", "TREE-074", "TREE-075", "TREE-076", "TREE-077"],
             "D": ["TREE-089", "TREE-090", "TREE-091", "TREE-092"]}
    trees = [{"code": c, "orchard_id": DEMO_ORCHARD, "zone_id": z["id"], "pos_x": 1.5, "pos_z": -7.0, "archived_at": None}
             for z in zones for c in codes[z["letter"]]]
    trees += [{"code": str(n), "orchard_id": OLD_ORCHARD, "zone_id": old_zone["id"], "pos_x": 1.0, "pos_z": 1.0,
               "archived_at": None} for n in range(1, 161)]
    z = {zz["letter"]: zz["id"] for zz in zones}
    return {
        "profiles": [
            {"id": DEMO, "role": "farmer", "name": "Demo IoT", "phone": "+21622777001", "zone": "sfax", "language": "ar",
             "created_at": iso(NOW - timedelta(hours=3)), "is_demo": False, "demo_account": True},
            {"id": OLD_DEMO, "role": "farmer", "name": "Salim Test", "phone": "+21622123456", "zone": "kairouan",
             "language": "ar", "created_at": iso(NOW - timedelta(days=20)), "is_demo": False, "demo_account": True},
            {"id": FREE, "role": "farmer", "name": "Mounir", "phone": "+21622123457", "zone": "gafsa", "language": "fr",
             "created_at": iso(NOW - timedelta(days=5)), "is_demo": False, "demo_account": False},
            {"id": EXPIRED, "role": "farmer", "name": "Karim", "phone": "+21650000004", "zone": None, "language": "ar",
             "created_at": iso(NOW - timedelta(days=40)), "is_demo": False, "demo_account": False},
            {"id": EXPERT, "role": "expert", "name": "Sami Expert", "phone": "+21622123458", "zone": "sfax",
             "language": "ar", "created_at": iso(NOW - timedelta(days=9)), "is_demo": False, "demo_account": True},
            {"id": ADMIN_ID, "role": "admin", "name": "Hajer", "phone": None, "zone": None, "language": "fr",
             "created_at": iso(NOW - timedelta(days=60)), "is_demo": False, "demo_account": False},
        ],
        "subscriptions": [
            {"user_id": DEMO, "plan": "paid", "status": "active", "ends_at": iso(NOW + timedelta(days=90)), "nodes": 4},
            {"user_id": OLD_DEMO, "plan": "paid", "status": "active", "ends_at": iso(NOW + timedelta(days=20)), "nodes": 4},
            {"user_id": FREE, "plan": "free", "status": "active", "ends_at": None, "nodes": None},
            {"user_id": EXPIRED, "plan": "paid", "status": "active", "ends_at": iso(NOW - timedelta(days=1)), "nodes": 1},
        ],
        "orchards": [
            {"id": DEMO_ORCHARD, "farmer_id": DEMO, "status": "complete", "area": 0.1176,
             "outline": [{"x": -28, "z": -10.5}, {"x": 28, "z": -10.5}, {"x": 28, "z": 10.5}, {"x": -28, "z": 10.5}],
             "is_demo": True, "completed_at": iso(NOW - timedelta(hours=2))},
            {"id": OLD_ORCHARD, "farmer_id": OLD_DEMO, "status": "complete", "area": 2.37, "outline": square(0, 50),
             "is_demo": True, "completed_at": iso(NOW - timedelta(days=2))},
        ],
        "zones": zones + [old_zone, archived_zone],
        "trees": trees,
        "iot_node_status": [
            box("n1", z["A"], "A", "NODE-01", "online", "ok"),
            box("n2", z["B"], "B", "NODE-02", "online", "warning", soil_moisture_pct=18.2, water_stress=66,
                reasons=["water_stress"], cause="water"),
            box("n3", z["C"], "C", "NODE-03", "offline", "watch", received_at=iso(NOW - timedelta(minutes=9))),
            box("n4", z["D"], "D", "NODE-04", "sensor_problem", "sensor", faults=["soil_moisture_out_of_range"]),
            # Like the real view for a box without any reading: every reading column null, lists too.
            box("o1", old_zone["id"], "A", "DEMO-A", "installed", None, orchard_id=OLD_ORCHARD, farmer_id=OLD_DEMO,
                received_at=iso(NOW - timedelta(days=1)), measured_at=None, time_mode=None, gateway_code=None,
                reasons=None, faults=None, soil_moisture_pct=None, battery_pct=None, rssi_dbm=None,
                water_stress=None, heat_stress=None, confidence=None, packets_lost=None, firmware=None),
        ],
        "gateways": [
            {"code": "GW-01", "orchard_id": DEMO_ORCHARD, "key_hash": "f" * 64, "time_mode": "demo", "enabled": True,
             "last_seen_at": iso(NOW - timedelta(seconds=40)), "history_minutes": 60, "offline_after_minutes": 5,
             "last_result": {"accepted": 48, "old": 0, "refused": {}, "refused_devices": {}}},
        ],
        "kit_requests": [
            {"id": VISIT, "orchard_id": DEMO_ORCHARD, "status": "installed", "nodes": 4, "admin_note": None,
             "created_at": iso(NOW - timedelta(hours=2)), "updated_at": iso(NOW - timedelta(hours=2)),
             "installed_at": iso(NOW - timedelta(hours=2))},
        ],
    }


def test_list_shows_only_farmers_most_recent_data_first(client_with, tables):
    data = client_with(tables).get("/api/farmers").json()
    names = [f["name"] for f in data["farmers"]]
    assert names[0] == "Demo IoT"
    assert set(names) == {"Demo IoT", "Salim Test", "Mounir", "Karim"}   # no expert, no admin
    assert "server_time" in data


def test_list_demo_farmer_pack_boxes_and_worst_level(client_with, tables):
    demo = client_with(tables).get("/api/farmers").json()["farmers"][0]
    assert demo["phone"] == "+21622777001" and demo["governorate"] == "sfax"
    assert demo["pack"]["plan"] == "paid" and demo["pack"]["active"] is True and demo["pack"]["nodes"] == 4
    assert demo["orchard_status"] == "complete" and demo["zones"] == 4
    assert demo["boxes"] == {"total": 4, "waiting": 0, "installed": 0, "online": 2, "offline": 1, "sensor_problem": 1}
    assert demo["worst_level"] == "warning"
    assert demo["demo_time"] is True
    assert demo["last_received_at"] is not None


def test_list_other_farmers(client_with, tables):
    by_name = {f["name"]: f for f in client_with(tables).get("/api/farmers").json()["farmers"]}
    assert by_name["Salim Test"]["boxes"]["installed"] == 1 and by_name["Salim Test"]["worst_level"] is None
    # Its box never sent a reading: no "last data" (its last_seen was written by the old seed).
    assert by_name["Salim Test"]["last_received_at"] is None
    assert by_name["Salim Test"]["zones"] == 1   # the archived zone does not count
    assert by_name["Mounir"]["pack"] == {"plan": "free", "active": False, "ends_at": None, "nodes": None}
    assert by_name["Mounir"]["orchard_status"] is None and by_name["Mounir"]["boxes"]["total"] == 0
    assert by_name["Karim"]["pack"]["plan"] == "paid" and by_name["Karim"]["pack"]["active"] is False


@pytest.mark.parametrize("q, expected", [
    ("demo", {"Demo IoT"}), ("DEMO iot", {"Demo IoT"}), ("777", {"Demo IoT"}), ("22 123", {"Salim Test", "Mounir"}),
    ("zzz", set()), ("", {"Demo IoT", "Salim Test", "Mounir", "Karim"})])
def test_list_search_by_name_or_phone(client_with, tables, q, expected):
    found = client_with(tables).get("/api/farmers", params={"q": q}).json()["farmers"]
    assert {f["name"] for f in found} == expected


def test_detail_of_the_demo_farmer(client_with, tables):
    d = client_with(tables).get(f"/api/farmers/{DEMO}").json()
    assert d["farmer"]["name"] == "Demo IoT" and d["farmer"]["governorate"] == "sfax"
    assert d["pack"]["active"] is True
    assert d["orchard"]["area_ha"] == 0.1176 and d["orchard"]["is_demo"] is True and len(d["orchard"]["outline"]) == 4
    assert [(z["letter"], z["cultivar"], z["planted_year"]) for z in d["zones"]] == [
        ("A", "Nonpareil", 2018), ("B", "Nonpareil", 2016), ("C", "Tuono", 2014), ("D", "Ferraduel", 2022)]
    assert d["zones"][0]["tree_codes"] == ["TREE-012", "TREE-013", "TREE-014", "TREE-027", "TREE-028"]
    assert d["zones"][1]["tree_codes"] == ["TREE-042", "TREE-043", "TREE-044", "TREE-058"]
    assert len(d["trees"]) == 18
    assert [(b["zone_letter"], b["device_code"], b["status"]) for b in d["boxes"]] == [
        ("A", "NODE-01", "online"), ("B", "NODE-02", "online"), ("C", "NODE-03", "offline"),
        ("D", "NODE-04", "sensor_problem")]
    b2 = d["boxes"][1]
    assert b2["level"] == "warning" and b2["reasons"] == ["water_stress"] and b2["water_stress"] == 66
    assert d["boxes"][3]["faults"] == ["soil_moisture_out_of_range"]
    assert d["gateways"][0]["code"] == "GW-01" and d["gateways"][0]["time_mode"] == "demo"
    assert d["gateways"][0]["last_result"]["accepted"] == 48
    assert d["visit"]["status"] == "installed" and d["visit"]["nodes"] == 4


def test_detail_never_sends_the_gateway_key_hash(client_with, tables):
    text = client_with(tables).get(f"/api/farmers/{DEMO}").text
    assert "key_hash" not in text and "f" * 64 not in text


def test_detail_big_zone_has_no_code_list_but_trees_for_the_plan(client_with, tables):
    d = client_with(tables).get(f"/api/farmers/{OLD_DEMO}").json()
    assert [z["letter"] for z in d["zones"]] == ["A"]          # archived zone left out
    assert d["zones"][0]["tree_codes"] == []                    # 160 trees: no list
    assert len(d["trees"]) == 160
    assert d["boxes"][0]["status"] == "installed" and d["gateways"] == [] and d["visit"] is None
    assert d["boxes"][0]["received_at"] is None
    assert d["boxes"][0]["reasons"] == [] and d["boxes"][0]["faults"] == []   # null in the view


def test_detail_reads_every_tree_page(client_with, tables):
    zone = tables["zones"][4]["id"]
    tables["trees"] += [{"code": f"{n}", "orchard_id": OLD_ORCHARD, "zone_id": zone, "pos_x": 0, "pos_z": 0,
                         "archived_at": None} for n in range(1000, 3500)]
    d = client_with(tables).get(f"/api/farmers/{OLD_DEMO}").json()
    assert len(d["trees"]) == 2660                              # 160 + 2500, read 1000 at a time


def test_detail_farmer_without_orchard(client_with, tables):
    d = client_with(tables).get(f"/api/farmers/{FREE}").json()
    assert d["orchard"] is None and d["boxes"] == [] and d["zones"] == [] and d["pack"]["plan"] == "free"


@pytest.mark.parametrize("farmer_id", [EXPERT, ADMIN_ID, "ee000000-0000-4000-8000-000000000099", "not-a-uuid"])
def test_detail_404_for_anyone_else(client_with, tables, farmer_id):
    assert client_with(tables).get(f"/api/farmers/{farmer_id}").status_code == 404
