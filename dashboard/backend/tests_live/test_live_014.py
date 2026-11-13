"""LIVE test of migration 014 (the DATABASE keeps the demo admin on demo
data), against the REAL Supabase. Only reads: nothing changes.

With its own login token, straight through the Supabase API (not the
dashboard backend), the demo admin ("Connexion démo") reads demo rows only;
"Vue d'ensemble" counts what its lists show; real admins still read
everything. Skipped while 014 is not run.
"""
import pytest

from tests_live.test_live_iot import HTTP, PUBLIC_KEY, URL, admin_token, api  # noqa: F401
from tests_live.test_live_phase_a import DEMO_PHONES, demo_api  # noqa: F401


@pytest.fixture(scope="module")
def demo_token(demo_api):
    return demo_api.headers["Authorization"].split(" ", 1)[1]


def rest(token: str, path: str) -> list:
    r = HTTP.get(f"{URL}/rest/v1/{path}", headers={"apikey": PUBLIC_KEY, "Authorization": f"Bearer {token}"}, timeout=30)
    assert r.status_code == 200, r.text
    return r.json()


def rpc(token: str, name: str, params: dict | None = None):
    return HTTP.post(f"{URL}/rest/v1/rpc/{name}", headers={"apikey": PUBLIC_KEY, "Authorization": f"Bearer {token}"},
                     json=params or {}, timeout=30)


@pytest.fixture(scope="module", autouse=True)
def migration_014(admin_token):
    if rpc(admin_token, "admin_sees_all").status_code == 404:
        pytest.skip("migration 014 is not run yet")


def test_demo_admin_reads_demo_rows_only_through_the_api(demo_token, admin_token):
    people = rest(demo_token, "profiles?select=id,phone,is_demo,demo_account")
    assert people and all(p["is_demo"] or p["demo_account"] for p in people)
    assert all(p["phone"] in DEMO_PHONES or p["phone"] is None for p in people)
    assert len(rest(admin_token, "profiles?select=id")) > len(people)            # real people exist
    ids = {p["id"] for p in people}
    for table in ("subscriptions", "payments", "kit_requests"):
        rows = rest(demo_token, f"{table}?select=user_id")
        assert all(r["user_id"] in ids for r in rows), table
    assert all(a["is_demo"] for a in rest(demo_token, "admin_actions?select=is_demo"))
    assert {a["admin_name"] for a in rest(demo_token, "admin_actions?select=admin_name")} <= {"Démo Admin"}
    assert all(a["is_demo"] for a in rest(demo_token, "regional_alerts?select=is_demo"))
    assert all(p["author_id"] in ids for p in rest(demo_token, "posts?select=author_id"))
    assert all(c["author_id"] in ids for c in rest(demo_token, "comments?select=author_id"))


def test_demo_admin_boxes_and_readings(demo_token, admin_token):
    demo_orchards = {o["id"] for o in rest(demo_token, "orchards?select=id,is_demo,farmer_id")}
    all_orchards = {o["id"] for o in rest(admin_token, "orchards?select=id")}
    assert demo_orchards and demo_orchards < all_orchards
    boxes = rest(demo_token, "iot_node_status?select=node_id,orchard_id,device_code")
    assert boxes and all(b["orchard_id"] in demo_orchards for b in boxes)
    assert {"NODE-01", "NODE-02", "NODE-03", "NODE-04"} <= {b["device_code"] for b in boxes}
    node_ids = {b["node_id"] for b in boxes}
    for table in ("node_latest", "node_readings", "node_alert_events", "node_fault_days"):
        rows = rest(demo_token, f"{table}?select=node_id&limit=500")
        assert all(r["node_id"] in node_ids for r in rows), table
    assert rest(demo_token, "node_readings?select=node_id&limit=1"), "the demo boxes have readings"
    for table in ("sensors", "alerts", "answers", "tree_photos"):
        assert rest(demo_token, f"{table}?select=id&limit=1") == [], table


def test_the_api_functions_give_demo_only(demo_token):
    rows = rpc(demo_token, "admin_auth_users").json()
    people = {p["id"] for p in rest(demo_token, "profiles?select=id")}
    assert rows and {r["id"] for r in rows} <= people


def test_overview_numbers_match_the_lists(demo_api):
    """Fix 1: in "Connexion démo", every number counts demo data only."""
    o = demo_api.get("/api/overview").json()
    farmers = demo_api.get("/api/farmers").json()["farmers"]
    users = demo_api.get("/api/users").json()["users"]
    boxes = demo_api.get("/api/sensors").json()["boxes"]
    orchards = demo_api.get("/api/orchards").json()["orchards"]
    assert o["farmers"]["total"] == len(farmers) == o["farmers"]["demo"]
    experts = [u for u in users if u["role"] == "expert"]
    assert o["experts"]["verified"] + o["experts"]["waiting"] == len(experts)
    assert o["experts"]["waiting"] == len([u for u in experts if not u["verified"]]) == len(o["todo"]["experts"])
    assert o["boxes"]["total"] == len(boxes)
    assert o["orchards"]["complete"] + o["orchards"]["draft"] == len(orchards)
    paid = [s for s in demo_api.get("/api/billing").json()["subscriptions"] if s["active"] and s["plan"] != "free"]
    assert o["farmers"]["paid"] == len(paid)


def test_real_admin_still_reads_everything(api):
    o = api.get("/api/overview").json()
    assert o["farmers"]["total"] == len(api.get("/api/farmers").json()["farmers"])
    assert o["farmers"]["total"] > o["farmers"]["demo"]
