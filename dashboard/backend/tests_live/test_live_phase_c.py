"""LIVE test of Phase C of the admin dashboard (Alertes), against the REAL
Supabase.

Milestone C (it CHANGES data, then ends what it made):
    a heat alert for Sfax -> 22 777 001 (Sfax) can read it in the app,
    22 123 457 (Kairouan) cannot -> it is changed (gravity "danger") ->
    it is ended -> 22 777 001 no longer sees it. Create, change and end are
    in the admin action log. (An ended alert stays in the history: alerts
    are never deleted through the API.)
The rest only reads, or checks that something is REFUSED.

Needs the same .env lines as test_live_phase_a.py, and the app's demo login
on (to log in as the app users).
"""
import pytest

from tests_live.test_live_iot import admin_token, api  # noqa: F401
from tests_live.test_live_phase_a import demo_api  # noqa: F401
from tests_live.test_live_phase_b import app_get, app_login, app_rpc

SFAX_FARMER = "+21622777001"
KAIROUAN_FARMER = "+21622123457"

ALERT = {
    "kind": "heat",
    "severity": "warning",
    "governorates": ["sfax"],
    "title_ar": "اختبار: موجة حرّ في صفاقس",
    "title_fr": "Jalon C : vague de chaleur à Sfax",
    "body_ar": "الحرارة توصل 44 درجة غدوة بعد الظهر.",
    "body_fr": "Jusqu'à 44 °C demain après-midi.",
    "advice_ar": "اسقوا في الليل وما تخدموش في القايلة.",
    "advice_fr": "Arrosez la nuit, ne travaillez pas aux heures chaudes.",
    "starts_at": None,
    "ends_at": None,
}


@pytest.fixture(scope="module")
def sfax():
    return app_login(SFAX_FARMER)


@pytest.fixture(scope="module")
def kairouan():
    return app_login(KAIROUAN_FARMER)


def seen_by(token: str, alert_id: str) -> list:
    return app_get(token, f"regional_alerts?select=id,severity,title_ar,title_fr&id=eq.{alert_id}")


def test_milestone_c_heat_alert_for_sfax(api, sfax, kairouan):
    r = api.post("/api/alerts/regional", json=ALERT)
    assert r.status_code == 200, r.text
    a = r.json()
    aid = a["id"]
    try:
        assert a["status"] == "active" and a["governorates"] == ["sfax"] and a["is_demo"] is False
        rows = seen_by(sfax, aid)
        assert len(rows) == 1 and rows[0]["title_ar"] == ALERT["title_ar"]      # Sfax: yes
        assert seen_by(kairouan, aid) == []                                      # Kairouan: no

        r = api.post(f"/api/alerts/regional/{aid}", json={**ALERT, "severity": "danger"})
        assert r.status_code == 200 and r.json()["severity"] == "danger", r.text
        assert seen_by(sfax, aid)[0]["severity"] == "danger"

        r = api.post(f"/api/alerts/regional/{aid}/end", json={"reason": "Jalon C : fin du test"})
        assert r.status_code == 200 and r.json()["status"] == "ended", r.text
        assert seen_by(sfax, aid) == []                                          # gone from the app
    finally:
        if api.get(f"/api/alerts/regional/{aid}").json()["alert"]["status"] != "ended":
            api.post(f"/api/alerts/regional/{aid}/end", json={"reason": "Jalon C : fin du test"})
    lines = api.get(f"/api/alerts/regional/{aid}").json()["actions"]
    assert {x["action"] for x in lines} == {"alert_create", "alert_update", "alert_end"}
    assert any(x["action"] == "alert_end" and x["reason"] == "Jalon C : fin du test" for x in lines)
    # Ended: it can no longer change.
    r = api.post(f"/api/alerts/regional/{aid}", json=ALERT)
    assert r.status_code == 409 and r.json()["detail"]["code"] == "alert_ended"


def test_the_database_checks_the_alert(api):
    r = api.post("/api/alerts/regional", json={**ALERT, "title_ar": "Pas en arabe"})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "alert_title_ar"
    r = api.post("/api/alerts/regional", json={**ALERT, "advice_fr": None})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "alert_advice"
    r = api.post("/api/alerts/regional", json={**ALERT, "governorates": ["atlantis"]})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "alert_governorates"


def test_a_farmer_cannot_write_alerts(sfax):
    r = app_rpc(sfax, "admin_save_regional_alert", {"p": ALERT})
    assert r.status_code in (401, 403), r.text


def test_sensor_alerts_live(api, demo_api):
    page = api.get("/api/alerts/sensors", params={"days": 7}).json()
    assert page["events"], "no sensor alert in 7 days: is the LOOZ Node-RED running?"
    assert any(e["device_code"] in {"NODE-01", "NODE-02", "NODE-03", "NODE-04"} for e in page["events"])
    ids = [e["id"] for e in page["events"]]
    assert ids == sorted(ids, reverse=True)
    demo = demo_api.get("/api/alerts/sensors", params={"days": 7}).json()
    assert all(e["demo"] for e in demo["events"])


def test_demo_admin_sees_its_demo_alerts_only(demo_api):
    alerts = demo_api.get("/api/alerts/regional").json()["alerts"]
    assert all(a["is_demo"] for a in alerts)
