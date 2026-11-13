"""Phase C, "Alertes": regional alerts (list, create, change, end) and the
sensor alerts of every orchard (filters, demo admin)."""
from datetime import datetime, timedelta, timezone

from tests.conftest import ADMIN, db_error

NOW = datetime.now(timezone.utc)
A_ACTIVE = "a1000000-0000-4000-8000-000000000001"
A_PLANNED = "a1000000-0000-4000-8000-000000000002"
A_EXPIRED = "a1000000-0000-4000-8000-000000000003"
A_ENDED = "a1000000-0000-4000-8000-000000000004"
A_NEW = "a1000000-0000-4000-8000-000000000009"
REAL = "aa000000-0000-4000-8000-000000000001"
DEMO = "aa000000-0000-4000-8000-000000000002"


def iso(delta_hours: float) -> str:
    return (NOW + timedelta(hours=delta_hours)).isoformat()


def alert(id, starts, ends=None, ended=None, is_demo=False, kind="heat", governorates=("sfax",)):
    return {"id": id, "kind": kind, "severity": "warning", "governorates": list(governorates),
            "title_ar": "موجة حرّ", "title_fr": "Vague de chaleur", "body_ar": "اسقوا في الليل",
            "body_fr": "Arrosez la nuit", "advice_ar": None, "advice_fr": None, "starts_at": starts, "ends_at": ends,
            "ended_at": ended, "created_at": starts, "updated_at": starts, "created_by": ADMIN.id,
            "ended_by": ADMIN.id if ended else None, "is_demo": is_demo}


def tables():
    return {
        "regional_alerts": [
            alert(A_ACTIVE, iso(-2), iso(24)),
            alert(A_PLANNED, iso(5), is_demo=True, kind="frost"),
            alert(A_EXPIRED, iso(-48), iso(-1)),
            alert(A_ENDED, iso(-30), ended=iso(-20)),
        ],
        "regional_alert_reports": [{"alert_id": A_ACTIVE}, {"alert_id": A_ACTIVE}, {"alert_id": A_ENDED}],
        "profiles": [{"id": ADMIN.id, "name": "Hajer", "first_name": None, "last_name": None}],
        "admin_actions": [
            {"id": 9, "created_at": iso(-2), "admin_name": "Hajer", "action": "alert_create",
             "target_type": "regional_alert", "target_id": A_ACTIVE, "target_label": "Vague de chaleur", "reason": None,
             "details": {}, "is_demo": False},
        ],
    }


BODY = {"kind": "heat", "severity": "danger", "governorates": ["sfax"], "title_ar": "موجة حرّ في صفاقس",
        "title_fr": "Vague de chaleur à Sfax", "body_ar": "الحرارة توصل 44 درجة.", "body_fr": "Jusqu'à 44 °C.",
        "advice_ar": " ", "advice_fr": "", "starts_at": None, "ends_at": None}


def saving(t, seen):
    """A fake admin_save_regional_alert: keeps the payload, writes the row."""
    def save(p):
        seen.append(p)
        row = alert(p.get("id") or A_NEW, iso(0), p.get("ends_at"), kind=p["kind"])
        t["regional_alerts"] = [r for r in t["regional_alerts"] if r["id"] != row["id"]] + [row]
        return row
    return save


def test_regional_alerts_with_their_state(client_with):
    client = client_with(tables())
    r = client.get("/api/alerts/regional")
    assert r.status_code == 200, r.text
    page = r.json()
    states = {a["id"]: a["status"] for a in page["alerts"]}
    assert states == {A_ACTIVE: "active", A_PLANNED: "scheduled", A_EXPIRED: "expired", A_ENDED: "ended"}
    by_id = {a["id"]: a for a in page["alerts"]}
    assert by_id[A_ACTIVE]["seen_count"] == 2 and by_id[A_ENDED]["seen_count"] == 1
    assert by_id[A_ENDED]["ended_by_name"] == "Hajer" and by_id[A_ACTIVE]["created_by_name"] == "Hajer"
    assert [a["id"] for a in page["actions"]] == [9]


def test_demo_admin_sees_its_demo_alerts_only(client_with):
    client = client_with(tables(), demo=True)
    page = client.get("/api/alerts/regional").json()
    assert [a["id"] for a in page["alerts"]] == [A_PLANNED]
    assert page["actions"] == []
    assert client.get(f"/api/alerts/regional/{A_ACTIVE}").status_code == 404
    assert client.get(f"/api/alerts/regional/{A_PLANNED}").status_code == 200


def test_one_alert(client_with):
    client = client_with(tables())
    d = client.get(f"/api/alerts/regional/{A_ACTIVE}").json()
    assert d["alert"]["title_fr"] == "Vague de chaleur" and [a["action"] for a in d["actions"]] == ["alert_create"]
    assert client.get("/api/alerts/regional/a1000000-0000-4000-8000-000000000099").status_code == 404
    assert client.get("/api/alerts/regional/nope").status_code == 404


def test_create_an_alert(client_with):
    t, seen = tables(), []
    client = client_with(t, {"admin_save_regional_alert": saving(t, seen)})
    r = client.post("/api/alerts/regional", json=BODY)
    assert r.status_code == 200, r.text
    assert r.json()["id"] == A_NEW and r.json()["status"] == "active"
    p = seen[0]
    assert "id" not in p and "starts_at" not in p                  # a new alert starts now
    assert p["advice_ar"] is None and p["advice_fr"] is None and p["ends_at"] is None
    assert p["governorates"] == ["sfax"] and p["title_fr"] == "Vague de chaleur à Sfax"


def test_whole_tunisia_and_dates(client_with):
    t, seen = tables(), []
    client = client_with(t, {"admin_save_regional_alert": saving(t, seen)})
    body = {**BODY, "governorates": ["all"], "starts_at": "2026-12-01T08:00:00.000Z", "ends_at": "2026-12-02T08:00:00.000Z",
            "advice_ar": "اسقوا في الليل", "advice_fr": "Arrosez la nuit"}
    assert client.post("/api/alerts/regional", json=body).status_code == 200
    assert seen[0]["governorates"] == "all" and seen[0]["starts_at"] == "2026-12-01T08:00:00.000Z"
    assert seen[0]["ends_at"] == "2026-12-02T08:00:00.000Z" and seen[0]["advice_fr"] == "Arrosez la nuit"


def test_change_an_alert(client_with):
    t, seen = tables(), []
    client = client_with(t, {"admin_save_regional_alert": saving(t, seen)})
    r = client.post(f"/api/alerts/regional/{A_ACTIVE}", json={**BODY, "kind": "drought"})
    assert r.status_code == 200 and r.json()["kind"] == "drought"
    assert seen[0]["id"] == A_ACTIVE


def test_alert_refused_by_the_database(client_with):
    def wrong(p):
        raise db_error("22023", "Wrong alert: title_ar: 1 to 80 letters, in Arabic")

    def ended(p):
        raise db_error("22023", "This alert is ended")

    def demo(p):
        raise db_error("42501", "The demo admin acts only on demo accounts")

    r = client_with(tables(), {"admin_save_regional_alert": wrong}).post("/api/alerts/regional", json=BODY)
    assert r.status_code == 422 and r.json()["detail"]["code"] == "alert_title_ar"
    r = client_with(tables(), {"admin_save_regional_alert": ended}).post(f"/api/alerts/regional/{A_ENDED}", json=BODY)
    assert r.status_code == 409 and r.json()["detail"]["code"] == "alert_ended"
    r = client_with(tables(), {"admin_save_regional_alert": demo}, demo=True).post(f"/api/alerts/regional/{A_ACTIVE}", json=BODY)
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_only"
    client = client_with(tables())
    assert client.post("/api/alerts/regional", json={**BODY, "governorates": []}).status_code == 422


def test_end_an_alert(client_with):
    t, seen = tables(), []

    def end(p_id, p_reason):
        seen.append((p_id, p_reason))
        row = next(r for r in t["regional_alerts"] if r["id"] == p_id)
        row["ended_at"], row["ended_by"] = iso(0), ADMIN.id
        return row

    client = client_with(t, {"admin_end_regional_alert": end})
    r = client.post(f"/api/alerts/regional/{A_ACTIVE}/end", json={"reason": " La chaleur est passée "})
    assert r.status_code == 200 and r.json()["status"] == "ended"
    assert seen == [(A_ACTIVE, "La chaleur est passée")]
    assert client.post(f"/api/alerts/regional/{A_ACTIVE}/end", json={}).status_code == 422


# ---------- Sensor alerts ----------

def event(id, farmer, level, governorate, demo_orchard=False, received=-1.0):
    return {"id": id, "node_id": "n0000000-0000-4000-8000-000000000001", "device_code": f"NODE-{id:02d}",
            "zone_letter": "A", "measured_at": iso(received), "received_at": iso(received), "level": level,
            "previous_level": "ok", "reasons": None, "cause": None, "confidence": None, "water_stress": 70,
            "heat_stress": 20, "soil_moisture_pct": 12.5, "air_temp_c": 31.0, "faults": None,
            "orchard_id": "0c000000-0000-4000-8000-000000000001", "farmer_id": farmer, "demo_orchard": demo_orchard,
            "farmer_name": "x", "governorate": governorate}


def sensor_tables():
    return {
        "profiles": [
            {"id": REAL, "role": "farmer", "name": "Mounir", "first_name": None, "last_name": None, "is_demo": False,
             "demo_account": False},
            {"id": DEMO, "role": "farmer", "name": "Demo IoT", "first_name": None, "last_name": None, "is_demo": False,
             "demo_account": True},
        ],
        "iot_alert_log": [event(1, REAL, "warning", "gafsa"), event(2, DEMO, "critical", "sfax"),
                          event(3, DEMO, "watch", "sfax", received=-24 * 10)],
        "orchards": [{"farmer_id": REAL}, {"farmer_id": DEMO}],
    }


def test_sensor_alerts_newest_first(client_with):
    client = client_with(sensor_tables())
    r = client.get("/api/alerts/sensors")
    assert r.status_code == 200, r.text
    page = r.json()
    assert [e["id"] for e in page["events"]] == [2, 1]                  # the 10-day-old one is not in 7 days
    assert page["events"][0]["farmer_name"] == "Demo IoT" and page["events"][0]["demo"] is True
    assert page["events"][0]["reasons"] == [] and page["limit"] == 300
    assert [f["name"] for f in page["farmers"]] == ["Demo IoT", "Mounir"]
    assert [e["id"] for e in client.get("/api/alerts/sensors?days=30").json()["events"]] == [3, 2, 1]


def test_sensor_alerts_filters(client_with):
    client = client_with(sensor_tables())
    assert [e["id"] for e in client.get("/api/alerts/sensors?level=warning").json()["events"]] == [1]
    assert [e["id"] for e in client.get("/api/alerts/sensors?governorate=sfax").json()["events"]] == [2]
    assert [e["id"] for e in client.get(f"/api/alerts/sensors?farmer_id={REAL}").json()["events"]] == [1]
    assert client.get("/api/alerts/sensors?level=nope").status_code == 422
    assert client.get("/api/alerts/sensors?days=0").status_code == 422
    assert client.get("/api/alerts/sensors?governorate=Sfax;drop").status_code == 422
    assert client.get("/api/alerts/sensors?farmer_id=nope").status_code == 404


def test_demo_admin_sensor_alerts(client_with):
    client = client_with(sensor_tables(), demo=True)
    page = client.get("/api/alerts/sensors?days=30").json()
    assert [e["id"] for e in page["events"]] == [3, 2]
    assert [f["name"] for f in page["farmers"]] == ["Demo IoT"]
