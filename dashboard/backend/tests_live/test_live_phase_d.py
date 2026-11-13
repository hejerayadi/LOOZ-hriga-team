"""LIVE test of Phase D of the admin dashboard (Vergers, Abonnements,
Réglages, Journal des actions), against the REAL Supabase.

Milestone D (it CHANGES the price, then puts it back):
    the price of a box goes from 8 DT to 9 DT -> the bill changes in the app
    (orchard_quote() of 22 777 001, as the app reads it) and in the dashboard
    -> the log line says 8 DT -> 9 DT with its reason -> the price goes back
    to 8 DT (always, even if a check fails) -> the bill is back.
The rest only reads, or checks that something is REFUSED (nothing changes).

Needs the same .env lines as test_live_phase_a.py, and the app's demo login
on (to log in as 22 777 001).
"""
import pytest

from tests_live.test_live_iot import admin_token, api  # noqa: F401
from tests_live.test_live_phase_a import demo_api  # noqa: F401
from tests_live.test_live_phase_b import app_login, app_rpc

FARMER_PHONE = "+21622777001"
TEST_PRICE = 9000


@pytest.fixture(scope="module")
def farmer():
    return app_login(FARMER_PHONE)


def app_bill(token: str) -> dict:
    """The bill of the farmer, as the app's review step reads it."""
    r = app_rpc(token, "orchard_quote", {})
    assert r.status_code == 200, r.text
    return r.json()[0]


def dashboard_bill(api) -> dict:
    page = api.get("/api/billing").json()
    sub = next(s for s in page["subscriptions"] if s["farmer_phone"] == FARMER_PHONE)
    return sub["bill"]


def test_milestone_d_price_bill_log_and_back(api, farmer):
    before = api.get("/api/billing").json()["price"]["price_millimes"]
    assert before != TEST_PRICE, "the price is already 9 DT: put it back to its normal value first"
    quote = app_bill(farmer)
    billed = quote["billed_nodes"]
    assert quote["price_per_node"] == before and quote["monthly_millimes"] == billed * before
    assert dashboard_bill(api)["amount_millimes"] == billed * before
    try:
        r = api.post("/api/billing/price", json={"price_millimes": TEST_PRICE, "reason": "Jalon D : test du prix"})
        assert r.status_code == 200 and r.json()["status"] == str(TEST_PRICE), r.text
        quote = app_bill(farmer)
        assert quote["price_per_node"] == TEST_PRICE and quote["monthly_millimes"] == billed * TEST_PRICE   # the app
        assert dashboard_bill(api)["amount_millimes"] == billed * TEST_PRICE                              # the dashboard
        line = api.get("/api/billing").json()["actions"][0]
        assert line["action"] == "price_change" and line["reason"] == "Jalon D : test du prix"
        assert line["details"] == {"before": before, "after": TEST_PRICE}
    finally:
        r = api.post("/api/billing/price", json={"price_millimes": before, "reason": "Jalon D : prix remis"})
        assert r.status_code == 200, r.text
    quote = app_bill(farmer)
    assert quote["price_per_node"] == before and quote["monthly_millimes"] == billed * before
    line = api.get("/api/billing").json()["actions"][0]
    assert line["details"] == {"before": TEST_PRICE, "after": before} and line["reason"] == "Jalon D : prix remis"
    journal = api.get("/api/actions", params={"actions": "price_change"}).json()["actions"]
    assert [x["reason"] for x in journal[:2]] == ["Jalon D : prix remis", "Jalon D : test du prix"]


# ---------- Reading ----------

def test_orchards_live(api):
    orchards = api.get("/api/orchards").json()["orchards"]
    assert orchards
    demo = next(o for o in orchards if o["farmer_phone"] == FARMER_PHONE)
    d = api.get(f"/api/orchards/{demo['id']}").json()
    assert [z["letter"] for z in d["zones"]] == ["A", "B", "C", "D"] and len(d["trees"]) == 18
    assert {b["device_code"] for b in d["boxes"]} == {"NODE-01", "NODE-02", "NODE-03", "NODE-04"}
    assert d["bill"]["billed_nodes"] == 4


def test_settings_live(api):
    s = api.get("/api/settings").json()["settings"]
    assert {"demo_payments_enabled", "demo_login_enabled", "iot_ingest_enabled", "demo_admin_login_enabled"} <= set(s)


# ---------- Refused (nothing changes) ----------

def test_the_database_checks_the_values(api):
    r = api.post("/api/settings/iot_history_days", json={"value": "0", "reason": "Essai de valeur"})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "history_days"
    r = api.post("/api/settings/hectares_per_node", json={"value": "0.01", "reason": "Essai de valeur"})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "hectares"
    r = api.post("/api/billing/price", json={"price_millimes": 2_000_000, "reason": "Essai de valeur"})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "price"
    r = api.post("/api/settings/iot_ingest_enabled", json={"value": "false", "reason": "a"})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "reason"


def test_a_farmer_cannot_change_price_or_settings(farmer):
    r = app_rpc(farmer, "admin_set_price", {"p_price_millimes": 1000, "p_reason": "Essai"})
    assert r.status_code in (401, 403), r.text
    r = app_rpc(farmer, "admin_set_setting", {"p_name": "demo_login_enabled", "p_value": "false", "p_reason": "Essai"})
    assert r.status_code in (401, 403), r.text


def test_demo_admin_phase_d(demo_api):
    r = demo_api.post("/api/billing/price", json={"price_millimes": 9000, "reason": "Essai démo"})
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_not_allowed"
    r = demo_api.post("/api/settings/demo_login_enabled", json={"value": "false", "reason": "Essai démo"})
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_not_allowed"
    assert all(o["demo"] for o in demo_api.get("/api/orchards").json()["orchards"])
    page = demo_api.get("/api/billing").json()
    assert all(s["demo"] for s in page["subscriptions"]) and page["actions"] == []
    assert all(a["is_demo"] for a in demo_api.get("/api/actions").json()["actions"])
