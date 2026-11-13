"""LIVE test of Phase B of the admin dashboard (Utilisateurs + Communauté),
against the REAL Supabase.

Milestone B (it CHANGES demo data, then puts it back):
  1. The demo expert +216 22 123 458 (if already verified: "Retirer la
     vérification" first -> the app no longer shows her badge), then
     "Vérifier" -> the app shows "◆ خبير موثّق": public_profile(), and an
     answer she writes on a demo post (community_comments, as the app reads
     it). Her answer is then deleted. She STAYS verified (for the jury).
  2. A demo post: "Masquer" -> it disappears from the app (community_posts,
     read as 22 777 001) -> "Afficher de nouveau" -> it is back.
  Each action is in the admin action log with its reason.
The rest only reads, or checks that something is REFUSED.

Needs the same .env lines as test_live_phase_a.py, and the app's demo login
on (app_settings.demo_login_enabled) to log in as the app users.
"""
import pytest

from tests_live.test_live_iot import HTTP, PUBLIC_KEY, URL, admin_token, api  # noqa: F401
from tests_live.test_live_phase_a import DEMO_PHONES, demo_api  # noqa: F401

EXPERT_PHONE = "+21622123458"
FARMER_PHONE = "+21622777001"


def app_login(phone: str) -> str:
    """An app user, logged in like the app (demo login: any code)."""
    fn = f"{URL}/functions/v1/demo-auth"
    h = {"apikey": PUBLIC_KEY, "Authorization": f"Bearer {PUBLIC_KEY}"}
    r = HTTP.post(fn, headers=h, json={"action": "start", "phone": phone, "signUp": False})
    assert r.json().get("demo") is True, f"demo login off? {r.status_code}"
    r = HTTP.post(fn, headers=h, json={"action": "verify", "phone": phone, "code": "135790", "signUp": False,
                                        "language": "ar"})
    refresh = r.json()["refresh_token"]
    r = HTTP.post(f"{URL}/auth/v1/token?grant_type=refresh_token", headers={"apikey": PUBLIC_KEY},
                  json={"refresh_token": refresh})
    return r.json()["access_token"]


def headers(token: str) -> dict:
    return {"apikey": PUBLIC_KEY, "Authorization": f"Bearer {token}"}


def app_get(token: str, path: str):
    r = HTTP.get(f"{URL}/rest/v1/{path}", headers=headers(token), timeout=30)
    assert r.status_code == 200, r.text
    return r.json()


def app_rpc(token: str, name: str, params: dict):
    return HTTP.post(f"{URL}/rest/v1/rpc/{name}", headers=headers(token), json=params, timeout=30)


@pytest.fixture(scope="module")
def farmer():
    return app_login(FARMER_PHONE)


@pytest.fixture(scope="module")
def expert(api):
    users = api.get("/api/users").json()["users"]
    match = [u for u in users if u["phone"] == EXPERT_PHONE]
    assert len(match) == 1, "the demo expert +216 22 123 458 has no account"
    return match[0]


def badge_in_app(farmer_token: str, expert_id: str) -> bool:
    r = app_rpc(farmer_token, "public_profile", {"p_user": expert_id})
    assert r.status_code == 200, r.text
    rows = r.json()
    return bool(rows and rows[0]["verified_expert"])


# ---------- Reading ----------

def test_users_list_live(api):
    r = api.get("/api/users")
    assert r.status_code == 200, r.text
    users = r.json()["users"]
    assert {"farmer", "expert", "admin"} <= {u["role"] for u in users}
    assert all(u["email"] is None for u in users if u["role"] != "admin")      # e-mails: admins only
    assert any(u["fake"] for u in users) and any(u["demo"] and not u["fake"] for u in users)


def test_community_live(api):
    r = api.get("/api/community")
    assert r.status_code == 200, r.text
    page = r.json()
    assert page["posts"], "no post at all"
    dates = [p["created_at"] for p in page["posts"]]
    assert dates == sorted(dates, reverse=True)
    one = api.get(f"/api/community/posts/{page['posts'][0]['id']}")
    assert one.status_code == 200, one.text


# ---------- Milestone B ----------

def test_milestone_b_expert_badge_in_the_app(api, farmer, expert):
    eid = expert["id"]
    if expert["verified"]:
        r = api.post(f"/api/users/{eid}/verified", json={"verified": False, "reason": "Jalon B : test du retrait du badge"})
        assert r.status_code == 200, r.text
        assert badge_in_app(farmer, eid) is False
    r = api.post(f"/api/users/{eid}/verified", json={"verified": True, "reason": "Jalon B : badge vérifié"})
    assert r.status_code == 200 and r.json()["status"] == "verified", r.text
    assert badge_in_app(farmer, eid) is True

    # The badge next to her answer, as the app reads the community.
    expert_token = app_login(EXPERT_PHONE)
    posts = app_get(farmer, "community_posts?select=id,author_id&order=created_at.desc&limit=20")
    users = {u["id"]: u for u in api.get("/api/users").json()["users"]}
    target = next(p for p in posts if users.get(p["author_id"], {}).get("fake"))
    r = HTTP.post(f"{URL}/rest/v1/comments", headers={**headers(expert_token), "Prefer": "return=representation"},
                  json={"post_id": target["id"], "text": "جربوا السقي في الليل، هكا الماء ما يتبخرش."}, timeout=30)
    assert r.status_code == 201, r.text
    comment_id = r.json()[0]["id"]
    try:
        rows = app_get(farmer, f"community_comments?select=id,author_verified_expert&id=eq.{comment_id}")
        assert rows == [{"id": comment_id, "author_verified_expert": True}]
        rows = app_get(farmer, f"community_posts?select=has_expert_answer&id=eq.{target['id']}")
        assert rows == [{"has_expert_answer": True}]
    finally:
        r = HTTP.delete(f"{URL}/rest/v1/comments?id=eq.{comment_id}", headers=headers(expert_token), timeout=30)
        assert r.status_code in (200, 204), r.text
    assert app_get(farmer, f"community_comments?select=id&id=eq.{comment_id}") == []

    lines = api.get(f"/api/users/{eid}").json()["actions"]
    assert any(a["action"] == "expert_verify" and a["reason"] == "Jalon B : badge vérifié" for a in lines)
    assert api.get(f"/api/users/{eid}").json()["user"]["verified"] is True   # stays verified (jury)


def test_milestone_b_hide_a_demo_post_then_show_it_again(api, farmer):
    page = api.get("/api/community").json()
    target = next(p for p in page["posts"] if p["author"]["fake"] and not p["hidden"])
    pid = target["id"]
    assert app_get(farmer, f"community_posts?select=id&id=eq.{pid}") == [{"id": pid}]
    try:
        r = api.post(f"/api/community/posts/{pid}/moderate", json={"action": "hide", "reason": "Jalon B : masquée pour le test"})
        assert r.status_code == 200 and r.json()["hidden"] is True, r.text
        assert app_get(farmer, f"community_posts?select=id&id=eq.{pid}") == []          # gone from the app
        assert api.get(f"/api/community/posts/{pid}").json()["post"]["hidden"] is True  # the admin still sees it
    finally:
        if api.get(f"/api/community/posts/{pid}").json()["post"]["hidden"]:
            r = api.post(f"/api/community/posts/{pid}/moderate",
                         json={"action": "unhide", "reason": "Jalon B : remise en ligne"})
            assert r.status_code == 200, r.text
    assert app_get(farmer, f"community_posts?select=id&id=eq.{pid}") == [{"id": pid}]  # back in the app
    lines = api.get(f"/api/community/posts/{pid}").json()["actions"]
    reasons = {(a["action"], a["reason"]) for a in lines}
    assert ("post_hide", "Jalon B : masquée pour le test") in reasons
    assert ("post_unhide", "Jalon B : remise en ligne") in reasons


# ---------- Refused ----------

def test_a_farmer_cannot_moderate_or_verify(farmer, expert):
    r = app_rpc(farmer, "admin_set_expert_verified", {"p_user": expert["id"], "p_verified": False, "p_reason": "Essai"})
    assert r.status_code in (401, 403), r.text
    r = app_rpc(farmer, "admin_moderate_content", {"p_type": "post", "p_id": expert["id"], "p_action": "hide",
                                                   "p_reason": "Essai"})
    assert r.status_code in (401, 403), r.text
    r = app_rpc(farmer, "admin_auth_users", {})
    assert r.status_code in (401, 403), r.text


def test_demo_admin_phase_b(demo_api, api, expert):
    users = demo_api.get("/api/users").json()["users"]
    assert users and all(u["demo"] for u in users)
    assert all(u["phone"] in DEMO_PHONES or u["phone"] is None for u in users)
    posts = demo_api.get("/api/community").json()["posts"]
    assert all(p["demo"] for p in posts)
    # Blocking: never with the demo admin (even a demo account).
    r = demo_api.post(f"/api/users/{expert['id']}/blocked", json={"blocked": True, "reason": "Essai démo"})
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_not_allowed"
    real = [u for u in api.get("/api/users").json()["users"] if not u["demo"] and u["role"] == "farmer"]
    if real:
        assert demo_api.get(f"/api/users/{real[0]['id']}").status_code == 404
