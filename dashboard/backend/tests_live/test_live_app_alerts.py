"""LIVE test of the APP module "التنبيهات + Moi aussi + Signaler" (migration
015), against the REAL Supabase: the JURY SCENARIO, with "Connexion démo"
(the demo admin) like in front of the jury.

Scenario A (it CHANGES demo data, then ends what it made):
    the demo admin publishes a frost alert for Sfax -> 22 777 001 (Sfax)
    reads it in the app (Arabic AND French, "new"), 22 123 457 (Kairouan)
    does not -> 22 777 001 opens it and taps "أنا أيضًا" -> the dashboard
    shows 1 "Moi aussi", opened by 1 -> he taps "تمّ" -> "fait par 1" ->
    the admin ends it -> gone from the app; "أنا أيضًا" is refused.
Scenario B (it CHANGES demo data, then puts the post back):
    22 777 001 reports a demo post (a fake person of the community) ->
    a second report is refused -> it appears in "Signalements" -> the demo
    admin hides the post -> the report is "actioned", the post is gone
    from the app, it can't be reported any more -> the post is shown again
    (for the jury). The report stays in the history.
    (A user reports each post once, forever: each run uses a demo post he
    did not report yet; the test is skipped when there is none left.)

Needs the same .env lines as test_live_phase_a.py, the app's demo login on
and the "Connexion démo" switch on (skipped otherwise).
"""
from datetime import datetime, timedelta, timezone

import pytest

from tests_live.test_live_iot import admin_token, api  # noqa: F401
from tests_live.test_live_phase_a import demo_api  # noqa: F401
from tests_live.test_live_phase_b import app_get, app_login, app_rpc

SFAX_FARMER = "+21622777001"
KAIROUAN_FARMER = "+21622123457"

FROST = {
    "kind": "frost",
    "severity": "danger",
    "governorates": ["sfax"],
    "title_ar": "اختبار: صقيع الليلة في صفاقس",
    "title_fr": "Test : gel cette nuit à Sfax",
    "body_ar": "برد شديد بعد منتصف الليل. الأزهار في خطر.",
    "body_fr": "Froid fort après minuit. Les fleurs sont en danger.",
    "advice_ar": "غطّ الأشجار الصغيرة\nاسقِ قبل الليل",
    "advice_fr": "Couvrez les jeunes arbres\nArrosez avant la nuit",
    "starts_at": None,
    "ends_at": None,
}


@pytest.fixture(scope="module")
def sfax():
    return app_login(SFAX_FARMER)


@pytest.fixture(scope="module")
def kairouan():
    return app_login(KAIROUAN_FARMER)


def my_alerts(token: str) -> dict:
    """What the tab "التنبيهات" reads (my_regional_alerts), by id."""
    r = app_rpc(token, "my_regional_alerts", {})
    assert r.status_code == 200, r.text
    return {a["id"]: a for a in r.json()}


def dashboard_alert(client, aid: str) -> dict:
    r = client.get(f"/api/alerts/regional/{aid}")
    assert r.status_code == 200, r.text
    return r.json()["alert"]


def test_scenario_a_frost_alert_for_sfax(demo_api, api, sfax, kairouan):
    ends = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
    r = demo_api.post("/api/alerts/regional", json={**FROST, "ends_at": ends})
    assert r.status_code == 200, r.text
    aid = r.json()["id"]
    try:
        assert r.json()["is_demo"] is True and r.json()["status"] == "active"

        # 1. On 22 777 001's phone, in Arabic and French, new, nobody yet.
        a = my_alerts(sfax).get(aid)
        assert a is not None, "the demo alert is not in 22 777 001's list"
        assert (a["title_ar"], a["title_fr"]) == (FROST["title_ar"], FROST["title_fr"])
        assert a["advice_ar"].split("\n") == ["غطّ الأشجار الصغيرة", "اسقِ قبل الليل"]
        assert (a["is_new"], a["done"], a["me_too"], a["seen_count"]) == (True, False, False, 0)
        assert a["severity"] == "danger" and a["kind"] == "frost"
        assert aid not in my_alerts(kairouan)                                   # Kairouan: never

        # 2. He opens it, then taps "أنا أيضًا" (twice: still 1).
        assert app_rpc(sfax, "regional_alert_mark", {"p_alert": aid, "p_state": "read"}).status_code == 200
        assert my_alerts(sfax)[aid]["is_new"] is False
        r = app_rpc(sfax, "regional_alert_me_too", {"p_alert": aid, "p_on": True})
        assert r.status_code == 200 and r.json() == 1, r.text
        assert app_rpc(sfax, "regional_alert_me_too", {"p_alert": aid, "p_on": True}).json() == 1

        # 3. The dashboard: 1 "Moi aussi", opened by 1 (demo admin and real admin).
        d = dashboard_alert(demo_api, aid)
        assert (d["seen_count"], d["opened_count"], d["done_count"]) == (1, 1, 0), d
        listed = {x["id"]: x for x in demo_api.get("/api/alerts/regional").json()["alerts"]}
        assert listed[aid]["seen_count"] == 1 and listed[aid]["opened_count"] == 1
        assert dashboard_alert(api, aid)["seen_count"] == 1

        # 4. "تمّ" -> fait par 1; taken back -> 0; done again (for the record).
        assert app_rpc(sfax, "regional_alert_mark", {"p_alert": aid, "p_state": "done"}).status_code == 200
        assert my_alerts(sfax)[aid]["done"] is True
        assert dashboard_alert(demo_api, aid)["done_count"] == 1
        assert app_rpc(sfax, "regional_alert_mark", {"p_alert": aid, "p_state": "undone"}).status_code == 200
        assert dashboard_alert(demo_api, aid)["done_count"] == 0
        assert app_rpc(sfax, "regional_alert_mark", {"p_alert": aid, "p_state": "done"}).status_code == 200

        # 5. The admin ends it: gone from the app, the buttons are refused.
        r = demo_api.post(f"/api/alerts/regional/{aid}/end", json={"reason": "Test du module App : fin"})
        assert r.status_code == 200 and r.json()["status"] == "ended", r.text
        assert aid not in my_alerts(sfax)
        r = app_rpc(sfax, "regional_alert_me_too", {"p_alert": aid, "p_on": False})
        assert r.status_code != 200 and "P0002" in r.text, r.text
        # The counts stay in the dashboard's history.
        d = dashboard_alert(demo_api, aid)
        assert (d["status"], d["seen_count"], d["opened_count"], d["done_count"]) == ("ended", 1, 1, 1)
    finally:
        if dashboard_alert(demo_api, aid)["status"] != "ended":
            demo_api.post(f"/api/alerts/regional/{aid}/end", json={"reason": "Test du module App : fin"})


def test_the_app_cannot_write_reads_or_counts_by_hand(sfax):
    r = app_rpc(sfax, "regional_alert_reach", {"p_ids": []})
    assert r.status_code in (401, 403), r.text                                  # admins only
    from tests_live.test_live_iot import HTTP, PUBLIC_KEY, URL
    h = {"apikey": PUBLIC_KEY, "Authorization": f"Bearer {sfax}", "Content-Type": "application/json"}
    r = HTTP.post(f"{URL}/rest/v1/regional_alert_reads", headers=h,
                  json={"alert_id": "00000000-0000-4000-8000-000000000000", "user_id": "00000000-0000-4000-8000-000000000000"})
    assert r.status_code in (401, 403), r.text
    r = app_rpc(sfax, "regional_alert_mark", {"p_alert": "00000000-0000-4000-8000-000000000000", "p_state": "read"})
    assert "P0002" in r.text, r.text


def test_scenario_b_report_a_demo_post(demo_api, sfax):
    mine = {r["post_id"] for r in app_get(sfax, "content_reports?select=post_id") if r["post_id"]}
    posts = demo_api.get("/api/community").json()["posts"]
    candidates = [p for p in posts if p["author"]["fake"] and not p["hidden"] and p["id"] not in mine]
    if not candidates:
        pytest.skip("22 777 001 already reported every demo post (one report per post, forever)")
    pid = candidates[-1]["id"]   # the oldest one: the newest stay for the jury
    try:
        # 1. 22 777 001 reports it ("نصيحة خاطئة أو خطيرة"); once only.
        r = app_rpc(sfax, "report_content", {"p_type": "post", "p_id": pid, "p_reason": "wrong_advice"})
        assert r.status_code == 200 and r.json()["status"] == "open", r.text
        r = app_rpc(sfax, "report_content", {"p_type": "post", "p_id": pid, "p_reason": "spam"})
        assert r.status_code == 409 and "23505" in r.text, r.text
        assert pid in {x["post_id"] for x in app_get(sfax, "content_reports?select=post_id")}

        # 2. In "Signalements" (demo admin): open, the right reason.
        reports = [x for x in demo_api.get("/api/community").json()["reports"] if x["target_post_id"] == pid]
        assert any(x["status"] == "open" and x["reason"] == "wrong_advice" for x in reports), reports

        # 3. The demo admin hides it: the report is closed, gone from the app.
        r = demo_api.post(f"/api/community/posts/{pid}/moderate",
                          json={"action": "hide", "reason": "Signalé : conseil faux (test)"})
        assert r.status_code == 200 and r.json()["hidden"] is True, r.text
        reports = [x for x in demo_api.get("/api/community").json()["reports"] if x["target_post_id"] == pid]
        assert reports and all(x["status"] == "actioned" for x in reports), reports
        assert app_get(sfax, f"community_posts?select=id&id=eq.{pid}") == []
        r = app_rpc(sfax, "report_content", {"p_type": "post", "p_id": pid, "p_reason": "other"})
        assert r.status_code != 200 and "P0002" in r.text, r.text
    finally:
        if demo_api.get(f"/api/community/posts/{pid}").json()["post"]["hidden"]:
            r = demo_api.post(f"/api/community/posts/{pid}/moderate",
                              json={"action": "unhide", "reason": "Fin du test : remise en ligne"})
            assert r.status_code == 200, r.text
    assert app_get(sfax, f"community_posts?select=id&id=eq.{pid}") == [{"id": pid}]    # back for the jury


def test_a_user_cannot_report_his_own_text(sfax):
    me = app_get(sfax, "community_posts?select=id,author_id&limit=200")
    from tests_live.test_live_iot import HTTP, URL  # noqa: F401
    own = [p for p in me if p["author_id"] == _uid(sfax)]
    if not own:
        pytest.skip("22 777 001 has no post")
    r = app_rpc(sfax, "report_content", {"p_type": "post", "p_id": own[0]["id"], "p_reason": "spam"})
    assert r.status_code != 200 and "22023" in r.text, r.text


def _uid(token: str) -> str:
    import base64
    import json
    payload = token.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))["sub"]
