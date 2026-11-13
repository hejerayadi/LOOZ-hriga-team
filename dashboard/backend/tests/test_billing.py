"""Phase D: "Vergers", "Abonnements" (bill, price), "Réglages", "Journal"."""
from tests.conftest import db_error

from app.billing import bill_for
from app.schemas import Price

DEMO = "aa000000-0000-4000-8000-000000000001"     # demo farmer, paid, complete orchard
REAL = "aa000000-0000-4000-8000-000000000002"     # real farmer, paid, big orchard
DRAFTER = "aa000000-0000-4000-8000-000000000003"  # real farmer with a draft
EXPERT = "aa000000-0000-4000-8000-000000000004"
O_DEMO = "0c000000-0000-4000-8000-000000000001"
O_REAL = "0c000000-0000-4000-8000-000000000002"
O_DRAFT = "0c000000-0000-4000-8000-000000000003"
SQUARE = [{"x": 0, "z": 0}, {"x": 40, "z": 0}, {"x": 40, "z": 30}, {"x": 0, "z": 30}]


def person(id, role, name, demo=False, phone=None):
    return {"id": id, "role": role, "name": name, "first_name": None, "last_name": None, "phone": phone, "zone": "sfax",
            "language": "ar", "created_at": "2026-01-01T00:00:00+00:00", "is_demo": False, "demo_account": demo}


def orchard(id, farmer, status, area, confirmed=None, design=None, is_demo=False):
    return {"id": id, "farmer_id": farmer, "status": status, "area": area, "confirmed_nodes": confirmed,
            "outline": SQUARE if status == "complete" else None, "design": design, "is_demo": is_demo,
            "completed_at": "2026-02-01T00:00:00+00:00" if status == "complete" else None}


def summary(id, farmer, status, area, zones, is_demo=False):
    return {"id": id, "farmer_id": farmer, "status": status, "area": area, "is_demo": is_demo, "draw_mode": "grid",
            "created_at": "2026-01-0%dT00:00:00+00:00" % (1 + zones % 8), "completed_at": None, "zones": zones,
            "trees": zones * 5, "boxes": zones, "boxes_accepted": zones}


def zone(id, orchard_id, letter):
    return {"id": id, "orchard_id": orchard_id, "letter": letter, "name": "", "color": "#2a78d6", "zone_type": "irrigated",
            "tree_count": 5, "cultivar": "Nonpareil", "planted_year": 2018, "boundary": SQUARE, "archived_at": None}


def tables():
    return {
        "profiles": [person(DEMO, "farmer", "Demo IoT", demo=True, phone="+21622777001"),
                     person(REAL, "farmer", "Mounir", phone="+21655555555"),
                     person(DRAFTER, "farmer", "Leila"), person(EXPERT, "expert", "Sami")],
        "subscriptions": [
            {"user_id": DEMO, "plan": "paid", "status": "active", "started_at": "2026-11-01T00:00:00+00:00",
             "ends_at": "2099-01-01T00:00:00+00:00", "nodes": 4},
            {"user_id": REAL, "plan": "paid", "status": "active", "started_at": "2026-11-01T00:00:00+00:00",
             "ends_at": "2099-01-01T00:00:00+00:00", "nodes": 32},
            {"user_id": DRAFTER, "plan": "free", "status": "active", "started_at": None, "ends_at": None, "nodes": None},
            {"user_id": EXPERT, "plan": "free", "status": "active", "started_at": None, "ends_at": None, "nodes": None},
        ],
        "orchard_summary": [summary(O_DEMO, DEMO, "complete", 0.12, 4, is_demo=True),
                            summary(O_REAL, REAL, "complete", 62.55, 3), summary(O_DRAFT, DRAFTER, "draft", None, 0)],
        "orchards": [
            orchard(O_DEMO, DEMO, "complete", 0.12, is_demo=True), orchard(O_REAL, REAL, "complete", 62.55),
            orchard(O_DRAFT, DRAFTER, "draft", None, design={
                "outline": SQUARE, "zones": [{"letter": "A", "name": "Nord", "type": "young_trees", "tree_count": 12,
                                              "boundary": SQUARE}]}),
        ],
        "zones": [zone("20000000-0000-4000-8000-00000000000%d" % i, O_DEMO, "ABCD"[i]) for i in range(4)]
        + [zone("21000000-0000-4000-8000-00000000000%d" % i, O_REAL, "ABC"[i]) for i in range(3)],
        "trees": [],
        "iot_node_status": [],
        "gateways": [],
        "kit_requests": [],
        "plan_prices": [{"plan": "paid", "price_millimes": 8000, "period_days": 30, "per_node": True,
                         "updated_at": "2026-11-08T20:54:02+00:00"}],
        "app_settings": [{"id": True, "demo_payments_enabled": True, "demo_login_enabled": True,
                          "iot_ingest_enabled": True, "demo_admin_login_enabled": False, "hectares_per_node": 2.0,
                          "iot_history_days": 30, "updated_at": "2026-11-12T09:00:00+00:00"}],
        "payments": [
            {"id": "pa1", "user_id": DEMO, "plan": "paid", "amount_millimes": 32000, "nodes": 4, "period_days": 30,
             "kind": "period", "provider": "demo", "status": "paid_demo", "created_at": "2026-11-02T00:00:00+00:00",
             "paid_at": "2026-11-02T00:00:00+00:00"},
            {"id": "pa2", "user_id": None, "plan": "paid", "amount_millimes": 8000, "nodes": 1, "period_days": 30,
             "kind": "period", "provider": "demo", "status": "failed_demo", "created_at": "2026-11-01T00:00:00+00:00",
             "paid_at": None},
            {"id": "pa3", "user_id": REAL, "plan": "paid", "amount_millimes": 256000, "nodes": 32, "period_days": 30,
             "kind": "period", "provider": "demo", "status": "paid_demo", "created_at": "2026-11-03T00:00:00+00:00",
             "paid_at": "2026-11-03T00:00:00+00:00"},
        ],
        "admin_actions": [
            line(1, "setting_change", "setting", "demo_login_enabled", False),
            line(2, "price_change", "price", "paid", False, {"before": 8000, "after": 9000}),
            line(3, "setting_change", "setting", "hectares_per_node", False),
            line(4, "node_accept", "node", "n1", True),
            line(5, "price_change", "price", "paid", False, {"before": 9000, "after": 8000}),
        ],
    }


def line(id, action, target_type, target_id, is_demo, details=None):
    return {"id": id, "created_at": "2026-11-12T10:00:00+00:00", "admin_name": "Hajer", "action": action,
            "target_type": target_type, "target_id": target_id, "target_label": target_id, "reason": "Essai",
            "details": details or {}, "is_demo": is_demo}


# ---------- The bill (same rule as orchard_quote_for) ----------

def test_bill_rule():
    price = Price(price_millimes=8000)
    assert bill_for(price, 2.0, 0.12, 4, None).billed_nodes == 4          # the zones
    b = bill_for(price, 2.0, 62.55, 3, None)
    assert (b.billed_nodes, b.min_nodes_by_area, b.amount_millimes) == (32, 32, 256000)  # 1 per 2 ha
    assert bill_for(price, 2.0, 62.55, 3, 5).billed_nodes == 5            # nodes confirmed by an admin
    assert bill_for(price, None, 62.55, 0, None).billed_nodes == 1        # never less than 1
    assert bill_for(Price(price_millimes=8000, per_node=False), 2.0, 10, 4, None).amount_millimes == 8000


# ---------- "Vergers" ----------

def test_orchards(client_with):
    client = client_with(tables())
    page = client.get("/api/orchards").json()
    assert {o["id"] for o in page["orchards"]} == {O_DEMO, O_REAL, O_DRAFT}
    by_id = {o["id"]: o for o in page["orchards"]}
    assert by_id[O_DEMO]["demo"] is True and by_id[O_REAL]["demo"] is False
    assert by_id[O_REAL]["farmer_name"] == "Mounir" and by_id[O_REAL]["pack"]["active"] is True
    demo = client_with(tables(), demo=True).get("/api/orchards").json()
    assert [o["id"] for o in demo["orchards"]] == [O_DEMO]


def test_one_orchard_built(client_with):
    client = client_with(tables())
    d = client.get(f"/api/orchards/{O_REAL}").json()
    assert [z["letter"] for z in d["zones"]] == ["A", "B", "C"] and len(d["outline"]) == 4
    assert d["bill"]["billed_nodes"] == 32 and d["bill"]["amount_millimes"] == 256000
    assert d["draft_zones"] == 0


def test_one_orchard_draft(client_with):
    client = client_with(tables())
    d = client.get(f"/api/orchards/{O_DRAFT}").json()
    assert d["draft_zones"] == 1 and d["zones"][0]["letter"] == "A" and d["zones"][0]["zone_type"] == "young_trees"
    assert d["bill"] is None


def test_orchard_not_found_or_not_demo(client_with):
    assert client_with(tables()).get("/api/orchards/0c000000-0000-4000-8000-000000000099").status_code == 404
    assert client_with(tables()).get("/api/orchards/nope").status_code == 404
    assert client_with(tables(), demo=True).get(f"/api/orchards/{O_REAL}").status_code == 404


# ---------- "Abonnements" ----------

def test_billing_page(client_with):
    page = client_with(tables()).get("/api/billing").json()
    assert page["price"]["price_millimes"] == 8000 and page["hectares_per_node"] == 2.0
    subs = {s["user_id"]: s for s in page["subscriptions"]}
    assert set(subs) == {DEMO, REAL, DRAFTER}                              # farmers only
    assert subs[DEMO]["bill"]["amount_millimes"] == 32000 and subs[REAL]["bill"]["billed_nodes"] == 32
    assert subs[DRAFTER]["bill"] is None and subs[DRAFTER]["orchard_status"] == "draft"
    assert [p["id"] for p in page["payments"]] == ["pa3", "pa1", "pa2"]    # newest first
    assert page["payments"][2]["user_id"] is None and all(p["demo"] for p in page["payments"])
    assert [a["id"] for a in page["actions"]] == [5, 3, 2]                 # price + hectares only


def test_demo_admin_billing(client_with):
    page = client_with(tables(), demo=True).get("/api/billing").json()
    assert [s["user_id"] for s in page["subscriptions"]] == [DEMO]
    assert [p["id"] for p in page["payments"]] == ["pa1"]
    assert page["actions"] == []


def test_change_the_price(client_with):
    seen = []

    def set_price(p_price_millimes, p_reason):
        seen.append((p_price_millimes, p_reason))
        return {"plan": "paid", "price_millimes": p_price_millimes}

    client = client_with(tables(), {"admin_set_price": set_price})
    r = client.post("/api/billing/price", json={"price_millimes": 9000, "reason": " Nouveau tarif "})
    assert r.status_code == 200 and r.json()["status"] == "9000"
    assert seen == [(9000, "Nouveau tarif")]
    assert client.post("/api/billing/price", json={"price_millimes": 0, "reason": "Essai"}).status_code == 422


def test_price_refused(client_with):
    def too_much(**_):
        raise db_error("22023", "Price: 1 to 1000 DT (1000 to 1000000 millimes)")

    def demo(**_):
        raise db_error("42501", "Not with the demo admin account")

    r = client_with(tables(), {"admin_set_price": too_much}).post("/api/billing/price",
                                                                   json={"price_millimes": 2_000_000, "reason": "Essai"})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "price"
    r = client_with(tables(), {"admin_set_price": demo}, demo=True).post("/api/billing/price",
                                                                          json={"price_millimes": 9000, "reason": "Essai"})
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_not_allowed"


# ---------- "Réglages" ----------

def test_settings(client_with):
    page = client_with(tables()).get("/api/settings").json()
    assert page["settings"]["demo_login_enabled"] is True and page["settings"]["iot_history_days"] == 30
    assert [a["id"] for a in page["actions"]] == [3, 1]


def test_change_a_setting(client_with):
    seen = []

    def set_setting(p_name, p_value, p_reason):
        seen.append((p_name, p_value, p_reason))
        return {"id": True, p_name: p_value == "true" if p_value in ("true", "false") else p_value}

    client = client_with(tables(), {"admin_set_setting": set_setting})
    r = client.post("/api/settings/demo_admin_login_enabled", json={"value": "false", "reason": "Fin de la démo"})
    assert r.status_code == 200 and r.json()["status"] == "false"
    r = client.post("/api/settings/hectares_per_node", json={"value": "", "reason": "Les zones seulement"})
    assert r.status_code == 200
    assert seen == [("demo_admin_login_enabled", "false", "Fin de la démo"), ("hectares_per_node", "", "Les zones seulement")]
    assert client.post("/api/settings/role", json={"value": "admin", "reason": "Essai"}).status_code == 422


def test_setting_refused(client_with):
    def bad(**_):
        raise db_error("22023", "hectares_per_node: 0.10 to 1000, or empty")

    r = client_with(tables(), {"admin_set_setting": bad}).post("/api/settings/hectares_per_node",
                                                                json={"value": "0", "reason": "Essai"})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "hectares"


# ---------- "Journal des actions" ----------

def test_journal(client_with):
    client = client_with(tables())
    page = client.get("/api/actions").json()
    assert [a["id"] for a in page["actions"]] == [5, 4, 3, 2, 1] and page["more"] is False
    assert [a["id"] for a in client.get("/api/actions?before=4").json()["actions"]] == [3, 2, 1]
    assert [a["id"] for a in client.get("/api/actions?actions=price_change").json()["actions"]] == [5, 2]
    assert client.get("/api/actions?actions=DROP TABLE").status_code == 422
    demo = client_with(tables(), demo=True).get("/api/actions").json()
    assert [a["id"] for a in demo["actions"]] == [4]


def test_journal_pages_of_100(client_with):
    t = tables()
    t["admin_actions"] = [line(i, "node_accept", "node", f"n{i}", False) for i in range(1, 106)]
    page = client_with(t).get("/api/actions").json()
    assert len(page["actions"]) == 100 and page["more"] is True and page["actions"][-1]["id"] == 6
    rest = client_with(t).get("/api/actions?before=6").json()
    assert [a["id"] for a in rest["actions"]] == [5, 4, 3, 2, 1] and rest["more"] is False
