"""GET /api/overview: the numbers and the "À faire" lists of admin_overview()."""
from tests.conftest import db_error

OVERVIEW = {
    "farmers": {"total": 22, "paid": 5, "demo": 8},
    "experts": {"verified": 1, "waiting": 3},
    "orchards": {"complete": 3, "draft": 0},
    "boxes": {"total": 11, "waiting": 3, "installed": 4, "online": 3, "offline": 0, "sensor_problem": 1, "critical": 1},
    "regional_alerts": {"active": 0, "danger": 0},
    "community": {"posts_week": 2, "answers_week": 5, "hidden": 0, "reports_open": 0},
    "demo_payments_month": {"count": 9, "millimes": 414000},
    "visits_open": 1,
    "todo": {
        "experts": [{"id": "e1", "name": "Rim Test", "governorate": "nabeul", "created_at": "2026-11-01T10:00:00+00:00"}],
        "boxes_waiting": [{"node_id": "n9", "device_code": None, "zone_letter": "A", "farmer_id": "f1",
                           "farmer_name": "Karim", "refused_at": None}],
        "sensor_problems": [{"node_id": "n4", "device_code": "NODE-04", "zone_letter": "D", "farmer_id": "f2",
                             "farmer_name": "Demo IoT", "faults": None, "level": "sensor"}],
        "reports": [],
    },
}


def test_overview_numbers_and_todo(client_with):
    c = client_with({}, {"admin_overview": lambda: OVERVIEW})
    data = c.get("/api/overview").json()
    assert data["farmers"] == {"total": 22, "paid": 5, "demo": 8}
    assert data["boxes"]["critical"] == 1 and data["boxes"]["waiting"] == 3
    assert data["demo_payments_month"]["millimes"] == 414000
    assert data["todo"]["boxes_waiting"][0]["faults"] == []
    assert data["todo"]["sensor_problems"][0]["faults"] == []        # null -> []
    assert data["todo"]["experts"][0]["name"] == "Rim Test"
    assert "server_time" in data
    assert c.db.rpc_calls == [("admin_overview", {})]


def test_overview_refused_by_the_database(client_with):
    def refuse():
        raise db_error("42501", "Admins only")

    r = client_with({}, {"admin_overview": refuse}).get("/api/overview")
    assert r.status_code == 403 and r.json()["detail"]["code"] == "admin_only"
