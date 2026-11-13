"""Phase B, "Utilisateurs": the list, one account, the expert badge, blocking."""
from tests.conftest import db_error

ADMIN_ID = "ad000000-0000-4000-8000-000000000001"
FARMER = "aa000000-0000-4000-8000-000000000001"   # a REAL farmer (paid)
EXPERT = "aa000000-0000-4000-8000-000000000002"   # a DEMO expert, not verified
FAKE = "aa000000-0000-4000-8000-000000000003"     # a fake person of the community
NEWBIE = "aa000000-0000-4000-8000-000000000004"   # a real account without a name yet


def profile(id, role, name, created, phone=None, zone="sfax", is_demo=False, demo_account=False, verified=False,
            first_name=None, last_name=None, organisation=None):
    return {"id": id, "role": role, "name": name, "first_name": first_name, "last_name": last_name, "phone": phone,
            "zone": zone, "language": "ar", "verified": verified, "speciality": None, "organisation": organisation,
            "is_demo": is_demo, "demo_account": demo_account, "created_at": created}


def tables():
    return {
        "profiles": [
            profile(ADMIN_ID, "admin", "Hajer", "2026-01-01T00:00:00+00:00", zone=None),
            profile(FARMER, "farmer", "Mounir", "2026-03-01T00:00:00+00:00", phone="+21655555555"),
            profile(EXPERT, "expert", "هالة", "2026-04-01T00:00:00+00:00", phone="+21622123458", zone="mahdia",
                    demo_account=True, organisation="CRDA"),
            profile(FAKE, "farmer", "سامي", "2026-02-01T00:00:00+00:00", is_demo=True),
            profile(NEWBIE, "farmer", "New user", "2026-05-01T00:00:00+00:00", phone="+21655555556",
                    first_name="Leila", last_name="Ben Ali"),
        ],
        "subscriptions": [
            {"user_id": FARMER, "plan": "paid", "status": "active", "ends_at": "2099-01-01T00:00:00+00:00", "nodes": 2},
            {"user_id": NEWBIE, "plan": "free", "status": "active", "ends_at": None, "nodes": None},
        ],
        "orchards": [{"farmer_id": FARMER, "status": "complete"}],
        "posts": [
            {"id": "b1000000-0000-4000-8000-000000000001", "author_id": FAKE, "type": "tip", "text": "نصيحة",
             "photo": None, "hidden": False, "date": "2026-10-01T10:00:00+00:00", "updated_at": None},
            {"id": "b1000000-0000-4000-8000-000000000002", "author_id": FARMER, "type": "question", "text": "Question",
             "photo": None, "hidden": True, "date": "2026-10-02T10:00:00+00:00", "updated_at": None},
        ],
        "comments": [
            {"id": "cc000000-0000-4000-8000-000000000001", "post_id": "b1000000-0000-4000-8000-000000000001",
             "author_id": EXPERT, "text": "جواب", "hidden": False, "created_at": "2026-10-01T11:00:00+00:00"},
        ],
        "content_reports": [],
        "admin_actions": [
            {"id": 7, "created_at": "2026-11-01T10:00:00+00:00", "admin_name": "Hajer", "action": "expert_verify",
             "target_type": "user", "target_id": EXPERT, "target_label": "هالة", "reason": None, "details": {},
             "is_demo": False},
        ],
    }


def auth_rpc(p_ids=None):
    rows = [
        {"id": ADMIN_ID, "email": "admin@example.com", "last_sign_in_at": "2026-11-12T09:00:00+00:00",
         "blocked": False, "demo_login": False, "created_at": "2026-01-01T00:00:00+00:00"},
        {"id": FARMER, "email": None, "last_sign_in_at": "2026-11-10T09:00:00+00:00", "blocked": True,
         "demo_login": False, "created_at": "2026-03-01T00:00:00+00:00"},
        {"id": EXPERT, "email": None, "last_sign_in_at": None, "blocked": False, "demo_login": True,
         "created_at": "2026-04-01T00:00:00+00:00"},
        {"id": NEWBIE, "email": None, "last_sign_in_at": None, "blocked": False, "demo_login": False,
         "created_at": "2026-05-01T00:00:00+00:00"},
    ]
    return [r for r in rows if p_ids is None or r["id"] in p_ids]


def test_users_list_every_account(client_with):
    client = client_with(tables(), {"admin_auth_users": auth_rpc})
    r = client.get("/api/users")
    assert r.status_code == 200, r.text
    users = r.json()["users"]
    assert [u["id"] for u in users] == [NEWBIE, EXPERT, FARMER, FAKE, ADMIN_ID]  # newest first
    by_id = {u["id"]: u for u in users}
    assert by_id[ADMIN_ID]["email"] == "admin@example.com" and by_id[FARMER]["email"] is None
    assert by_id[FARMER]["blocked"] is True and by_id[FARMER]["pack"]["active"] is True
    assert by_id[FARMER]["orchard_status"] == "complete" and by_id[FARMER]["posts"] == 1
    assert by_id[EXPERT]["demo"] is True and by_id[EXPERT]["fake"] is False and by_id[EXPERT]["demo_login"] is True
    assert by_id[EXPERT]["answers"] == 1 and by_id[EXPERT]["organisation"] == "CRDA"
    assert by_id[FAKE]["fake"] is True and by_id[FAKE]["demo"] is True
    assert by_id[NEWBIE]["name"] == "Leila Ben Ali"  # "New user" is never shown
    assert by_id[ADMIN_ID]["pack"]["plan"] == "free"  # only farmers have a pack


def test_demo_admin_sees_demo_accounts_only(client_with):
    client = client_with(tables(), {"admin_auth_users": auth_rpc}, demo=True)
    users = client.get("/api/users").json()["users"]
    assert {u["id"] for u in users} == {EXPERT, FAKE}
    assert client.get(f"/api/users/{FARMER}").status_code == 404
    assert client.get(f"/api/users/{EXPERT}").status_code == 200


def test_one_account(client_with):
    client = client_with(tables(), {"admin_auth_users": auth_rpc})
    r = client.get(f"/api/users/{FARMER}")
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["user"]["name"] == "Mounir" and d["user"]["blocked"] is True
    assert [p["text"] for p in d["posts"]] == ["Question"] and d["posts"][0]["hidden"] is True
    e = client.get(f"/api/users/{EXPERT}").json()
    assert [a["text"] for a in e["answers"]] == ["جواب"]
    assert [a["action"] for a in e["actions"]] == ["expert_verify"]
    assert client.db.rpc_calls[-1] == ("admin_auth_users", {"p_ids": [EXPERT]})


def test_unknown_account(client_with):
    client = client_with(tables(), {"admin_auth_users": auth_rpc})
    assert client.get("/api/users/aa000000-0000-4000-8000-000000000099").status_code == 404
    assert client.get("/api/users/not-a-uuid").status_code == 404


def test_verify_an_expert(client_with):
    seen = []

    def verify(p_user, p_verified, p_reason):
        seen.append((p_user, p_verified, p_reason))
        return {"id": p_user, "verified": p_verified}

    client = client_with(tables(), {"admin_set_expert_verified": verify})
    r = client.post(f"/api/users/{EXPERT}/verified", json={"verified": True, "reason": "  "})
    assert r.status_code == 200 and r.json()["status"] == "verified"
    r = client.post(f"/api/users/{EXPERT}/verified", json={"verified": False, "reason": "Diplôme non valable"})
    assert r.json()["status"] == "not_verified"
    assert seen == [(EXPERT, True, None), (EXPERT, False, "Diplôme non valable")]


def test_verify_refused_by_the_database(client_with):
    def refuse(**_):
        raise db_error("22023", "Only experts get the badge")

    def demo_refuse(**_):
        raise db_error("42501", "The demo admin acts only on demo accounts")

    client = client_with(tables(), {"admin_set_expert_verified": refuse})
    r = client.post(f"/api/users/{FARMER}/verified", json={"verified": True})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "not_expert"
    client = client_with(tables(), {"admin_set_expert_verified": demo_refuse}, demo=True)
    r = client.post(f"/api/users/{FARMER}/verified", json={"verified": True})
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_only"


def test_block_and_unblock(client_with):
    seen = []

    def block(p_user, p_blocked, p_reason):
        seen.append((p_user, p_blocked, p_reason))
        return "2999-12-31T00:00:00+00:00" if p_blocked else None

    client = client_with(tables(), {"admin_set_user_blocked": block})
    r = client.post(f"/api/users/{FARMER}/blocked", json={"blocked": True, "reason": " Publicité répétée "})
    assert r.status_code == 200 and r.json()["status"] == "blocked"
    r = client.post(f"/api/users/{FARMER}/blocked", json={"blocked": False, "reason": "Erreur"})
    assert r.json()["status"] == "active"
    assert seen == [(FARMER, True, "Publicité répétée"), (FARMER, False, "Erreur")]
    assert client.post(f"/api/users/{FARMER}/blocked", json={"blocked": True}).status_code == 422  # no reason


def test_block_refused_by_the_database(client_with):
    def admin_target(**_):
        raise db_error("42501", "An admin account cannot be blocked here")

    def demo(**_):
        raise db_error("42501", "Not with the demo admin account")

    client = client_with(tables(), {"admin_set_user_blocked": admin_target})
    r = client.post(f"/api/users/{ADMIN_ID}/blocked", json={"blocked": True, "reason": "Essai"})
    assert r.status_code == 403 and r.json()["detail"]["code"] == "admin_target"
    client = client_with(tables(), {"admin_set_user_blocked": demo}, demo=True)
    r = client.post(f"/api/users/{EXPERT}/blocked", json={"blocked": True, "reason": "Essai"})
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_not_allowed"
