"""The pages "Prédictions IA", "Assistant vocal", "Diagnostics photo", the trends of
"Vue d'ensemble" and a farmer's whole activity (fake tables, no internet)."""
from datetime import datetime, timedelta, timezone

NOW = datetime.now(timezone.utc)
T = lambda **kw: (NOW - timedelta(**kw)).isoformat()   # noqa: E731
DEMO = "dd000000-0000-4000-8000-000000000001"
REAL = "aa000000-0000-4000-8000-000000000002"
NODE_D, NODE_R = "11111111-0000-4000-8000-000000000001", "11111111-0000-4000-8000-000000000002"
ZONE_D, ZONE_R = "22222222-0000-4000-8000-000000000001", "22222222-0000-4000-8000-000000000002"


def profile(pid, name, demo, **kw):
    return {"id": pid, "role": "farmer", "name": name, "first_name": None, "last_name": None, "phone": "+216",
            "zone": "sfax", "is_demo": False, "demo_account": demo, "created_at": T(days=2), **kw}


def latest(node, zone, farmer, model, state, status="ok"):
    return {"node_id": node, "model": model, "zone_id": zone, "orchard_id": "o", "farmer_id": farmer,
            "measured_at": T(minutes=10), "predicted_at": T(minutes=9), "status": status, "state": state,
            "confidence": 0.91, "certainty": "likely", "probabilities": {}, "threshold": None,
            "factors": [{"code": "soil_water", "level": "low", "share": 0.7, "feature": "rew_predawn"}],
            "readings": {"air_temp_c": 33}, "explanation_ar": "الشجر عطشان.", "explanation_fr": "Les arbres ont soif.",
            "action_ar": "اسقي.", "action_fr": "Arrosez.", "explanation_source": "groq:qwen/qwen3.8-27b",
            "model_version": "stress-lgbm-skl1.6.1", "state_since": T(hours=2)}


def tables():
    return {
        "profiles": [profile(DEMO, "Demo IoT", True), profile(REAL, "Vrai Fermier", False)],
        "zones": [{"id": ZONE_D, "letter": "B", "name": "", "orchard_id": "o"},
                  {"id": ZONE_R, "letter": "A", "name": "Nord", "orchard_id": "o2"}],
        "nodes": [{"id": NODE_D, "hardware_id": "NODE-02", "zone_id": ZONE_D},
                  {"id": NODE_R, "hardware_id": "R-1", "zone_id": ZONE_R}],
        "ml_latest": [latest(NODE_D, ZONE_D, DEMO, "stress", "water_deficit"),
                      latest(NODE_D, ZONE_D, DEMO, "frost", "no_frost"),
                      latest(NODE_R, ZONE_R, REAL, "stress", None, status="sensor_problem")],
        "ml_notifications": [
            {"id": "n1", "farmer_id": DEMO, "node_id": NODE_D, "zone_id": ZONE_D, "model": "stress", "state": "water_deficit",
             "severity": "warning", "confidence": 0.9, "certainty": "likely", "measured_at": T(minutes=10),
             "created_at": T(minutes=9), "read_at": None, "resolved_at": None},
            {"id": "n2", "farmer_id": REAL, "node_id": NODE_R, "zone_id": ZONE_R, "model": "frost", "state": "frost_risk",
             "severity": "danger", "confidence": 0.9, "certainty": "likely", "measured_at": T(days=1),
             "created_at": T(days=1), "read_at": T(hours=20), "resolved_at": T(hours=10)}],
        "ml_workers": [{"code": "ML-01", "enabled": True, "last_seen_at": T(seconds=20),
                        "last_result": {"saved": 8, "notified": 1}}],
        "ml_history": [{"node_id": NODE_D, "model": "stress", "measured_at": T(hours=h), "status": "ok",
                        "state": "none" if h > 2 else "water_deficit", "confidence": 0.8, "certainty": "likely",
                        "factors": [], "explanation_fr": None, "changed": h == 2} for h in (5, 4, 3, 2, 1)],
        "voice_sessions": [
            {"id": "v1", "user_id": DEMO, "model": "gemini-3.8-live", "started_at": T(hours=3), "ended_at": T(hours=3),
             "charged_seconds": 90, "end_reason": "user", "questions": 3, "tool_calls": 1, "community_posts": 0,
             "tokens_in": 1000, "tokens_out": 2000},
            {"id": "v2", "user_id": REAL, "model": "gemini-3.8-live", "started_at": T(days=1), "ended_at": T(days=1),
             "charged_seconds": 180, "end_reason": "time", "questions": 5, "tool_calls": 2, "community_posts": 0,
             "tokens_in": 1, "tokens_out": 1}],
        "photo_diagnoses": [
            {"id": "d1", "user_id": DEMO, "zone_id": None, "status": "done", "model": "gemini:gemini-3.6-flash",
             "verdict": "likely", "top_class": "shot_hole", "top_confidence": 0.93, "plant": "almond", "error": None,
             "post_id": None, "created_at": T(hours=5), "finished_at": T(hours=5)}],
        "payments": [{"id": "p1", "user_id": DEMO, "plan": "paid", "kind": "new", "amount_millimes": 32000,
                      "status": "paid_demo", "nodes": 4, "period_days": 30, "created_at": T(days=1), "paid_at": T(days=1)}],
        "subscriptions": [{"id": "s1", "user_id": DEMO, "plan": "paid", "status": "active", "started_at": T(days=20),
                           "ends_at": T(days=-70), "nodes": 4}],
        "posts": [{"id": "po1", "author_id": DEMO, "text": "سؤال", "hidden": False, "date": T(hours=6), "photo": None}],
        "comments": [{"id": "c1", "post_id": "x", "author_id": DEMO, "text": "جواب", "hidden": False, "created_at": T(hours=4)}],
        "content_reports": [{"id": "r1", "post_id": "x", "comment_id": None, "reporter_id": DEMO, "reason": "spam",
                             "status": "open", "created_at": T(hours=2)}],
        "regional_alert_reports": [{"alert_id": "a1", "user_id": DEMO, "created_at": T(hours=1)}],
        "admin_actions": [{"id": 1, "created_at": T(hours=1), "admin_name": "Hajer", "action": "verify_expert",
                           "target_type": "user", "target_id": DEMO, "target_label": "Demo", "reason": None, "is_demo": False}],
    }


def test_admins_only(client):
    assert client.get("/api/insights/ml").status_code == 401
    assert client.get("/api/insights/voice").status_code == 401
    assert client.get(f"/api/insights/farmers/{DEMO}/activity").status_code == 401


def test_ml_page(client_with):
    c = client_with(tables())
    data = c.get("/api/insights/ml").json()
    assert len(data["predictions"]) == 3 and len(data["notifications"]) == 2
    p = next(p for p in data["predictions"] if p["state"] == "water_deficit")
    assert p["farmer"]["name"] == "Demo IoT" and p["zone"]["letter"] == "B" and p["device_code"] == "NODE-02"
    assert p["factors"][0]["code"] == "soil_water" and p["explanation_fr"] == "Les arbres ont soif."
    assert {"model": "stress", "state": "sensor_problem", "count": 1} in data["counts"]
    assert data["open_problems"] == 1 and data["worker"]["code"] == "ML-01"


def test_ml_page_demo_admin_sees_demo_only(client_with):
    c = client_with(tables(), demo=True)
    data = c.get("/api/insights/ml").json()
    assert {p["farmer"]["name"] for p in data["predictions"]} == {"Demo IoT"}
    assert [n["id"] for n in data["notifications"]] == ["n1"]
    assert data["worker"] is None                       # the worker's line is for real admins


def test_ml_history(client_with):
    c = client_with(tables())
    pts = c.get(f"/api/insights/ml/history/{NODE_D}").json()["points"]
    assert [p["state"] for p in pts] == ["none", "none", "none", "water_deficit", "water_deficit"]
    assert c.get("/api/insights/ml/history/not-a-uuid").status_code == 404
    demo = client_with(tables(), demo=True)
    assert demo.get(f"/api/insights/ml/history/{NODE_R}").json()["points"] == []


def test_voice_page_counts_minutes_never_words(client_with):
    c = client_with(tables())
    data = c.get("/api/insights/voice").json()
    assert data["totals"] == {"sessions": 2, "minutes": 4.5, "questions": 8, "tool_calls": 3}
    assert data["by_farmer"][0]["farmer"]["name"] == "Vrai Fermier"      # most minutes first
    assert len(data["days"]) == 30 and sum(d["sessions"] for d in data["days"]) == 2
    assert all("text" not in s and "transcript" not in s for s in data["sessions"])
    demo = client_with(tables(), demo=True).get("/api/insights/voice").json()
    assert demo["totals"]["sessions"] == 1


def test_diagnoses_page(client_with):
    data = client_with(tables()).get("/api/insights/diagnoses").json()
    assert data["by_verdict"] == {"likely": 1} and data["by_class"] == {"shot_hole": 1}
    assert data["by_model"] == {"gemini": 1} and "photo_path" not in data["diagnoses"][0]


def test_trends(client_with):
    data = client_with(tables()).get("/api/insights/trends?days=7").json()
    assert len(data["days"]) == 7
    s = data["series"]
    assert sum(s["signups"]) == 2 and sum(s["payments_dt"]) == 32.0 and sum(s["problems"]) == 2
    assert sum(s["diagnoses"]) == 1 and sum(s["voice_minutes"]) == 4.5 and sum(s["posts"]) == 1
    demo = client_with(tables(), demo=True).get("/api/insights/trends?days=7").json()["series"]
    assert sum(demo["signups"]) == 1 and sum(demo["problems"]) == 1


def test_farmer_activity_has_everything(client_with):
    data = client_with(tables()).get(f"/api/insights/farmers/{DEMO}/activity").json()
    assert data["farmer"]["name"] == "Demo IoT" and data["subscriptions"][0]["nodes"] == 4
    assert data["payments"][0]["amount_millimes"] == 32000
    assert len(data["ml"]["predictions"]) == 2 and data["ml"]["notifications"][0]["id"] == "n1"
    assert data["diagnoses"]["diagnoses"][0]["top_class"] == "shot_hole"
    assert data["voice"]["totals"]["sessions"] == 1
    assert data["community"]["me_too"] == 1 and len(data["community"]["reports"]) == 1
    assert data["admin_actions"][0]["action"] == "verify_expert"
    kinds = {e["kind"] for e in data["timeline"]}
    assert kinds == {"payment", "notification", "diagnosis", "voice", "post", "answer", "report", "me_too"}
    times = [e["at"] for e in data["timeline"]]
    assert times == sorted(times, reverse=True)


def test_farmer_activity_demo_admin_and_unknown(client_with):
    demo = client_with(tables(), demo=True)
    assert demo.get(f"/api/insights/farmers/{REAL}/activity").status_code == 404
    assert demo.get(f"/api/insights/farmers/{DEMO}/activity").status_code == 200
    c = client_with(tables())
    assert c.get("/api/insights/farmers/xyz/activity").status_code == 404
    assert c.get("/api/insights/farmers/33333333-0000-4000-8000-000000000009/activity").status_code == 404


def test_zone_context(client_with):
    ctx = {"soil_type": "sand", "node_position": "low", "defaults": ["theta"]}
    c = client_with(tables(), rpcs={"admin_zone_context": lambda p_zone: ctx})
    assert c.get(f"/api/insights/zones/{ZONE_D}/context").json() == ctx
    assert c.db.rpc_calls == [("admin_zone_context", {"p_zone": ZONE_D})]
