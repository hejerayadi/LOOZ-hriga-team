"""Farmers, their orchard and their sensor boxes (migration 012).

Every query runs with the ADMIN's token (admin.db): the database rules
(RLS) apply, no secret key is used. The functions only read; they return
codes (statuses, levels, faults): the dashboard writes the texts in French.
"""
from datetime import datetime, timezone
from typing import Any

from supabase import Client

from .schemas import (
    Box,
    BoxCounts,
    FarmerDetail,
    FarmerInfo,
    FarmerSummary,
    Gateway,
    Orchard,
    Pack,
    Point,
    Tree,
    Visit,
    Zone,
)

# How serious a level is (same as iot_level_rank in the database).
LEVEL_RANK = {"ok": 0, "info": 1, "sensor": 1, "watch": 2, "warning": 3, "critical": 4}
BOX_STATUSES = ("waiting", "installed", "online", "offline", "sensor_problem")
# A zone lists its tree codes (TREE-012...) when it has this many trees or fewer.
MAX_TREE_CODES = 30
# Trees sent for the plan of the orchard (more: the plan shows the zones only).
MAX_TREES = 3000
PAGE = 1000  # Supabase sends at most 1000 rows per query


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _time(value: Any) -> datetime | None:
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    return datetime.fromisoformat(str(value).replace("Z", "+00:00"))


def _all(query_for_range) -> list[dict]:
    """Every row of a query, PAGE rows at a time."""
    rows: list[dict] = []
    start = 0
    while True:
        page = query_for_range(start, start + PAGE - 1).execute().data or []
        rows.extend(page)
        if len(page) < PAGE:
            return rows
        start += PAGE


def make_pack(sub: dict | None, now: datetime) -> Pack:
    if not sub:
        return Pack()
    ends_at = _time(sub.get("ends_at"))
    active = (
        sub.get("plan") in ("paid", "essential", "connected")
        and sub.get("status") == "active"
        and (ends_at is None or ends_at > now)
    )
    return Pack(plan=sub.get("plan") or "free", active=active, ends_at=ends_at, nodes=sub.get("nodes"))


def clean_box(row: dict) -> dict:
    """A box that never sent a reading has no latest reading: the view gives
    null for its lists (reasons, faults) and the old nodes.last_seen (the demo
    seed of 22 123 456 wrote a fake one): no reception time then."""
    row = {**row, "reasons": row.get("reasons") or [], "faults": row.get("faults") or []}
    if row.get("measured_at") is None:
        row["received_at"] = None
    return row


def count_boxes(boxes: list[dict]) -> BoxCounts:
    counts = BoxCounts(total=len(boxes))
    for b in boxes:
        if b.get("status") in BOX_STATUSES:
            setattr(counts, b["status"], getattr(counts, b["status"]) + 1)
    return counts


def worst_level(boxes: list[dict]) -> str | None:
    """The most serious level among the boxes that send data (not waiting)."""
    levels = [b.get("level") for b in boxes if b.get("status") != "waiting" and b.get("level") in LEVEL_RANK]
    return max(levels, key=lambda lv: LEVEL_RANK[lv]) if levels else None


def _matches(q: str, row: dict) -> bool:
    q = q.strip().lower()
    if not q:
        return True
    digits = "".join(c for c in q if c.isdigit())
    name = (row.get("name") or "").lower()
    phone = row.get("phone") or ""
    return q in name or (len(digits) >= 3 and digits in phone)


def is_demo_person(profile: dict | None) -> bool:
    """A demo account (same as is_demo_person() of migration 013): the fake
    people of the community (is_demo) or the demo accounts (demo_account)."""
    return bool(profile and (profile.get("is_demo") or profile.get("demo_account")))


def list_farmers(db: Client, q: str = "", demo_only: bool = False) -> list[FarmerSummary]:
    """Every farmer, with his pack, his orchard and the state of his boxes.
    Farmers whose boxes sent data most recently come first.
    demo_only = the demo admin: the demo accounts only."""
    now = _now()
    profiles = _all(
        lambda a, b: db.table("profiles")
        .select("id, name, phone, zone, created_at, is_demo, demo_account")
        .eq("role", "farmer")
        .order("created_at", desc=True)
        .range(a, b)
    )
    profiles = [p for p in profiles if _matches(q, p) and (not demo_only or is_demo_person(p))]
    if not profiles:
        return []
    subs = {
        s["user_id"]: s
        for s in _all(lambda a, b: db.table("subscriptions").select("user_id, plan, status, ends_at, nodes").range(a, b))
    }
    orchards = {
        o["farmer_id"]: o
        for o in _all(lambda a, b: db.table("orchards").select("id, farmer_id, status").range(a, b))
    }
    zone_count: dict[str, int] = {}
    for z in _all(
        lambda a, b: db.table("zones").select("orchard_id").is_("archived_at", "null").range(a, b)
    ):
        zone_count[z["orchard_id"]] = zone_count.get(z["orchard_id"], 0) + 1
    boxes_of: dict[str, list[dict]] = {}
    for b in _all(
        lambda a, b: db.table("iot_node_status")
        .select("node_id, farmer_id, status, level, received_at, measured_at, time_mode")
        .range(a, b)
    ):
        boxes_of.setdefault(b["farmer_id"], []).append(clean_box(b))

    result = []
    for p in profiles:
        orchard = orchards.get(p["id"])
        boxes = boxes_of.get(p["id"], [])
        received = [_time(b.get("received_at")) for b in boxes if b.get("received_at")]
        result.append(
            FarmerSummary(
                id=p["id"],
                name=p.get("name") or "",
                phone=p.get("phone"),
                governorate=p.get("zone"),
                created_at=_time(p.get("created_at")),
                pack=make_pack(subs.get(p["id"]), now),
                orchard_status=orchard["status"] if orchard else None,
                zones=zone_count.get(orchard["id"], 0) if orchard else 0,
                boxes=count_boxes(boxes),
                worst_level=worst_level(boxes),
                last_received_at=max(received) if received else None,
                demo_time=any(b.get("time_mode") == "demo" for b in boxes),
            )
        )
    epoch = datetime.min.replace(tzinfo=timezone.utc)
    result.sort(
        key=lambda f: (f.last_received_at or epoch, f.boxes.total, f.created_at or epoch),
        reverse=True,
    )
    return result


def _points(value: Any) -> list[Point]:
    if not isinstance(value, list):
        return []
    return [Point(x=float(p["x"]), z=float(p["z"])) for p in value if isinstance(p, dict) and "x" in p and "z" in p]


def farmer_detail(db: Client, farmer_id: str, demo_only: bool = False) -> FarmerDetail | None:
    """One farmer: pack, orchard, zones, trees, boxes, gateway, visit.
    None if there is no farmer with this id (or, for the demo admin, if he
    is not a demo account)."""
    now = _now()
    rows = (
        db.table("profiles")
        .select("id, name, phone, zone, language, created_at, is_demo, demo_account")
        .eq("id", farmer_id)
        .eq("role", "farmer")
        .limit(1)
        .execute()
        .data
    )
    if not rows or (demo_only and not is_demo_person(rows[0])):
        return None
    p = rows[0]
    subs = db.table("subscriptions").select("user_id, plan, status, ends_at, nodes").eq("user_id", farmer_id).execute().data
    detail = FarmerDetail(
        farmer=FarmerInfo(
            id=p["id"],
            name=p.get("name") or "",
            phone=p.get("phone"),
            governorate=p.get("zone"),
            language=p.get("language"),
            created_at=_time(p.get("created_at")),
        ),
        pack=make_pack(subs[0] if subs else None, now),
        server_time=now,
    )

    orchards = (
        db.table("orchards")
        .select("id, status, area, outline, is_demo, completed_at")
        .eq("farmer_id", farmer_id)
        .limit(1)
        .execute()
        .data
    )
    if not orchards:
        return detail
    o = orchards[0]
    detail.orchard = Orchard(
        id=o["id"],
        status=o["status"],
        area_ha=o.get("area"),
        outline=_points(o.get("outline")),
        is_demo=bool(o.get("is_demo")),
        completed_at=_time(o.get("completed_at")),
    )

    zones = (
        db.table("zones")
        .select("id, letter, name, color, zone_type, tree_count, cultivar, planted_year, boundary")
        .eq("orchard_id", o["id"])
        .is_("archived_at", "null")
        .order("letter")
        .execute()
        .data
    )
    trees = _all(
        lambda a, b: db.table("trees")
        .select("code, zone_id, pos_x, pos_z")
        .eq("orchard_id", o["id"])
        .is_("archived_at", "null")
        .order("code")
        .range(a, b)
    )
    codes: dict[str, list[str]] = {}
    for t in trees:
        codes.setdefault(t.get("zone_id"), []).append(t["code"])
    detail.zones = [
        Zone(
            id=z["id"],
            letter=z.get("letter"),
            name=z.get("name") or "",
            color=z.get("color"),
            zone_type=z.get("zone_type"),
            tree_count=z.get("tree_count"),
            cultivar=z.get("cultivar"),
            planted_year=z.get("planted_year"),
            boundary=_points(z.get("boundary")),
            tree_codes=codes.get(z["id"], []) if len(codes.get(z["id"], [])) <= MAX_TREE_CODES else [],
        )
        for z in zones
    ]
    if len(trees) <= MAX_TREES:
        detail.trees = [
            Tree(code=t["code"], zone_id=t.get("zone_id"), x=float(t.get("pos_x") or 0), z=float(t.get("pos_z") or 0))
            for t in trees
        ]

    boxes = db.table("iot_node_status").select("*").eq("orchard_id", o["id"]).execute().data
    boxes.sort(key=lambda b: (b.get("zone_letter") or "", b.get("device_code") or ""))
    detail.boxes = [Box(**{k: v for k, v in clean_box(b).items() if k in Box.model_fields}) for b in boxes]

    detail.gateways = [
        Gateway(**g)
        for g in db.table("gateways")
        .select("code, time_mode, enabled, last_seen_at, last_result, history_minutes, offline_after_minutes")
        .eq("orchard_id", o["id"])
        .order("code")
        .execute()
        .data
    ]
    visits = (
        db.table("kit_requests")
        .select("id, status, nodes, admin_note, created_at, updated_at, installed_at")
        .eq("orchard_id", o["id"])
        .order("created_at", desc=True)
        .limit(1)
        .execute()
        .data
    )
    detail.visit = Visit(**visits[0]) if visits else None
    return detail
