"""What the dashboard reads for "Vergers", "Abonnements", "Réglages" and the
"Journal des actions" (migrations 008 to 013).

Every query runs with the ADMIN's token (admin.db): the database rules
(RLS) apply. demo_only = the demo admin ("Connexion démo"): only demo
accounts, their orchards and payments, and its own log lines.
"""
import math
from datetime import datetime, timezone
from typing import Any

from supabase import Client

from .admin_data import ACTION_COLUMNS, ACTIONS_SHOWN, action_lines
from .iot import _all, _points, _time, farmer_detail, is_demo_person, make_pack
from .people import display_name
from .schemas import (
    ActionsPage,
    Bill,
    BillingPage,
    OrchardDetail,
    OrchardRow,
    OrchardsPage,
    PaymentRow,
    Price,
    Settings,
    SettingsPage,
    SubscriptionRow,
    Zone,
)

JOURNAL_PAGE = 100
PAYMENTS_SHOWN = 200
SETTING_NAMES = ("demo_payments_enabled", "demo_login_enabled", "iot_ingest_enabled", "demo_admin_login_enabled",
                 "hectares_per_node", "iot_history_days")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _owners(db: Client) -> dict[str, dict]:
    return {p["id"]: p for p in _all(lambda a, b: db.table("profiles")
                                     .select("id, role, name, first_name, last_name, phone, zone, is_demo, demo_account")
                                     .range(a, b))}


def _subs(db: Client) -> dict[str, dict]:
    return {s["user_id"]: s for s in _all(lambda a, b: db.table("subscriptions")
                                          .select("user_id, plan, status, started_at, ends_at, nodes").range(a, b))}


def price_of(db: Client) -> Price:
    rows = db.table("plan_prices").select("price_millimes, period_days, per_node, updated_at").eq("plan", "paid") \
        .limit(1).execute().data
    return Price(**rows[0]) if rows else Price(price_millimes=0)


def settings_of(db: Client) -> dict[str, Any]:
    rows = db.table("app_settings").select("*").limit(1).execute().data
    return rows[0] if rows else {}


def bill_for(price: Price, hectares_per_node: float | None, area: float | None, zones: int,
             confirmed_nodes: int | None) -> Bill:
    """Billed nodes = the zones, at least 1 per hectares_per_node hectares (or
    the nodes an admin confirmed), never less than 1 (orchard_quote_for)."""
    min_area = math.ceil(float(area) / float(hectares_per_node)) if hectares_per_node and area else 0
    billed = max(zones, confirmed_nodes if confirmed_nodes is not None else min_area, 1)
    amount = price.price_millimes * (billed if price.per_node else 1)
    return Bill(billed_nodes=billed, min_nodes_by_area=min_area, price_millimes=price.price_millimes,
                period_days=price.period_days, amount_millimes=amount)


def _zone_counts(db: Client) -> dict[str, int]:
    counts: dict[str, int] = {}
    for z in _all(lambda a, b: db.table("zones").select("orchard_id").is_("archived_at", "null").range(a, b)):
        counts[z["orchard_id"]] = counts.get(z["orchard_id"], 0) + 1
    return counts


# ---------- "Vergers" ----------


def _orchard_row(o: dict, owner: dict | None, sub: dict | None, now: datetime) -> OrchardRow:
    owner = owner or {}
    return OrchardRow(
        id=o["id"], farmer_id=o["farmer_id"], farmer_name=display_name(owner), farmer_phone=owner.get("phone"),
        governorate=owner.get("zone"), status=o["status"], draw_mode=o.get("draw_mode"), area_ha=o.get("area"),
        zones=o.get("zones") or 0, trees=o.get("trees") or 0, boxes=o.get("boxes") or 0,
        boxes_accepted=o.get("boxes_accepted") or 0, pack=make_pack(sub, now), created_at=_time(o.get("created_at")),
        completed_at=_time(o.get("completed_at")), demo=bool(o.get("is_demo")) or is_demo_person(owner),
    )


SUMMARY_COLUMNS = "id, farmer_id, status, area, is_demo, draw_mode, created_at, completed_at, zones, trees, boxes, boxes_accepted"


def orchards_page(db: Client, demo_only: bool) -> OrchardsPage:
    """Every orchard (newest first), with its owner and pack."""
    now = _now()
    rows = _all(lambda a, b: db.table("orchard_summary").select(SUMMARY_COLUMNS).order("created_at", desc=True).range(a, b))
    owners, subs = _owners(db), _subs(db)
    page = OrchardsPage(server_time=now)
    for o in rows:
        row = _orchard_row(o, owners.get(o["farmer_id"]), subs.get(o["farmer_id"]), now)
        if demo_only and not row.demo:
            continue
        page.orchards.append(row)
    return page


def orchard_detail(db: Client, orchard_id: str, demo_only: bool) -> OrchardDetail | None:
    """One orchard and its plan. None: no such orchard (or not a demo one for
    the demo admin)."""
    now = _now()
    rows = db.table("orchard_summary").select(SUMMARY_COLUMNS).eq("id", orchard_id).limit(1).execute().data
    if not rows:
        return None
    o = rows[0]
    owner = _owners(db).get(o["farmer_id"])
    subs = db.table("subscriptions").select("user_id, plan, status, started_at, ends_at, nodes") \
        .eq("user_id", o["farmer_id"]).execute().data
    row = _orchard_row(o, owner, subs[0] if subs else None, now)
    if demo_only and not row.demo:
        return None
    detail = OrchardDetail(orchard=row, server_time=now)
    full = db.table("orchards").select("id, outline, design, area, confirmed_nodes").eq("id", orchard_id).limit(1) \
        .execute().data
    extra = full[0] if full else {}

    farmer = farmer_detail(db, o["farmer_id"], demo_only) if (owner or {}).get("role") == "farmer" else None
    if farmer and farmer.orchard and farmer.orchard.id == orchard_id:
        detail.outline, detail.zones, detail.trees, detail.boxes = (farmer.orchard.outline, farmer.zones, farmer.trees,
                                                                     farmer.boxes)
    design = extra.get("design") if isinstance(extra.get("design"), dict) else None
    if design and not detail.zones:
        # A draft: the plan of its drawing (zones not built yet).
        detail.outline = _points(design.get("outline"))
        drawn = [z for z in design.get("zones") or [] if isinstance(z, dict)]
        detail.zones = [
            Zone(id=f"dessin-{z.get('letter') or i}", letter=z.get("letter"), name=z.get("name") or "",
                 zone_type=z.get("type"), tree_count=z.get("tree_count"), boundary=_points(z.get("boundary")))
            for i, z in enumerate(drawn)
        ]
        detail.draft_zones = len(drawn)
    if row.status == "complete":
        s = settings_of(db)
        detail.bill = bill_for(price_of(db), s.get("hectares_per_node"), extra.get("area", row.area_ha), row.zones,
                               extra.get("confirmed_nodes"))
    return detail


# ---------- "Abonnements" ----------


def billing_page(db: Client, demo_only: bool) -> BillingPage:
    """The price, hectares_per_node, every farmer's subscription (with the
    bill of one period at the current price), the payments (newest first)
    and the log of the price changes."""
    now = _now()
    price = price_of(db)
    s = settings_of(db)
    per_ha = s.get("hectares_per_node")
    owners, subs = _owners(db), _subs(db)
    orchards = {o["farmer_id"]: o for o in _all(lambda a, b: db.table("orchards")
                                                .select("id, farmer_id, status, area, confirmed_nodes").range(a, b))}
    zones = _zone_counts(db)
    page = BillingPage(price=price, hectares_per_node=per_ha, server_time=now)

    for uid, p in owners.items():
        if p.get("role") != "farmer" or (demo_only and not is_demo_person(p)):
            continue
        sub = subs.get(uid) or {}
        pack = make_pack(sub or None, now)
        o = orchards.get(uid)
        bill = None
        if o and o["status"] == "complete":
            bill = bill_for(price, per_ha, o.get("area"), zones.get(o["id"], 0), o.get("confirmed_nodes"))
        page.subscriptions.append(SubscriptionRow(
            user_id=uid, farmer_name=display_name(p), farmer_phone=p.get("phone"), governorate=p.get("zone"),
            plan=sub.get("plan") or "free", status=sub.get("status"), active=pack.active, nodes=sub.get("nodes"),
            started_at=_time(sub.get("started_at")), ends_at=_time(sub.get("ends_at")),
            orchard_status=o["status"] if o else None, bill=bill, demo=is_demo_person(p),
        ))
    rank = {True: 0, False: 1}
    page.subscriptions.sort(key=lambda x: (rank[x.active], x.plan == "free", x.farmer_name.lower()))

    payments = (
        db.table("payments")
        .select("id, user_id, plan, amount_millimes, nodes, period_days, kind, provider, status, created_at, paid_at")
        .order("created_at", desc=True).limit(PAYMENTS_SHOWN).execute().data
    )
    for pay in payments:
        p = owners.get(pay.get("user_id") or "")
        if demo_only and not is_demo_person(p):
            continue
        page.payments.append(PaymentRow(
            **{k: v for k, v in pay.items() if k in PaymentRow.model_fields},
            farmer_name=display_name(p), demo=pay.get("provider") == "demo" or str(pay.get("status", "")).endswith("_demo"),
        ))

    lines = (
        db.table("admin_actions").select(ACTION_COLUMNS).in_("target_type", ["price", "setting"])
        .order("id", desc=True).limit(ACTIONS_SHOWN * 3).execute().data
    )
    lines = [x for x in lines if x["target_type"] == "price" or x.get("target_id") == "hectares_per_node"]
    if demo_only:
        lines = [x for x in lines if x.get("is_demo")]
    page.actions = action_lines(lines[:ACTIONS_SHOWN], demo_only)
    return page


# ---------- "Réglages" ----------


def settings_page(db: Client, demo_only: bool) -> SettingsPage:
    now = _now()
    s = settings_of(db)
    lines = (
        db.table("admin_actions").select(ACTION_COLUMNS).eq("target_type", "setting")
        .order("id", desc=True).limit(ACTIONS_SHOWN).execute().data
    )
    if demo_only:
        lines = [x for x in lines if x.get("is_demo")]
    return SettingsPage(
        settings=Settings(**{k: s.get(k) for k in (*SETTING_NAMES, "updated_at") if k in s}),
        actions=action_lines(lines, demo_only),
        server_time=now,
    )


# ---------- "Journal des actions" ----------


def journal(db: Client, demo_only: bool, before: int | None = None, actions: list[str] | None = None) -> ActionsPage:
    """Every admin action, newest first, JOURNAL_PAGE at a time (before = the
    id of the last line already shown). The demo admin: its own lines."""
    query = db.table("admin_actions").select(ACTION_COLUMNS)
    if before is not None:
        query = query.lt("id", before)
    if actions:
        query = query.in_("action", actions)
    if demo_only:
        query = query.eq("is_demo", True)
    rows = query.order("id", desc=True).limit(JOURNAL_PAGE + 1).execute().data or []
    return ActionsPage(actions=action_lines(rows[:JOURNAL_PAGE], demo_only), more=len(rows) > JOURNAL_PAGE,
                       server_time=_now())
