"""What the dashboard reads for "Vue d'ensemble", "Capteurs", the 3 days of
a farmer, and the admin action log (migrations 012 and 013).

Every query runs with the ADMIN's token (admin.db): the database rules
(RLS) apply. demo_only = the demo admin ("Connexion démo"): only demo
accounts appear (screenshots for the repo: no real farmer, no real phone).
"""
from datetime import datetime, timedelta, timezone
from typing import Any

from supabase import Client

from .iot import _all, _time, clean_box, is_demo_person
from .schemas import (
    ActionLine,
    AlertEvent,
    BoxSeries,
    FarmerHistory,
    FaultLine,
    GatewayRow,
    Overview,
    SensorBox,
    SensorsPage,
    SeriesPoint,
    VisitRow,
)

HISTORY_HOURS = 72  # the charts: the last 3 days
# A measure the box itself flags as wrong is not drawn (the line breaks):
# a disconnected soil probe sends 0 %, which is not a dry soil.
BAD_VALUE = {
    "soil": {"soil_probe_disconnected", "soil_probe_stuck", "soil_moisture_out_of_range", "soil_moisture_missing"},
    "water": {"soil_probe_disconnected", "soil_probe_stuck", "soil_moisture_out_of_range", "soil_moisture_missing"},
    "air": {"air_temp_out_of_range", "air_temp_missing"},
    "heat": {"air_temp_out_of_range", "air_temp_missing"},
    "battery": {"battery_out_of_range", "battery_missing"},
}
FAULT_DAYS = 14  # sensor problems: the last 14 days
ALERTS_SHOWN = 50
ACTIONS_SHOWN = 30


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat()


# ---------- The admin action log ----------


def action_lines(rows: list[dict], demo_only: bool) -> list[ActionLine]:
    """The log lines. For the demo admin, the name of a real admin is not
    shown ("Administrateur"): the screenshots show demo things only."""
    lines = []
    for r in rows:
        line = ActionLine(**{k: v for k, v in r.items() if k in ActionLine.model_fields})
        if line.details is None:
            line.details = {}
        if demo_only and not line.is_demo and line.admin_name != "SQL Editor":
            line.admin_name = "Administrateur"
        lines.append(line)
    return lines


ACTION_COLUMNS = "id, created_at, admin_name, action, target_type, target_id, target_label, reason, details, is_demo"


def actions_on(db: Client, target_ids: list[str], demo_only: bool, limit: int = ACTIONS_SHOWN) -> list[ActionLine]:
    """The latest admin actions on these items (boxes, gateways, visits...)."""
    ids = [i for i in dict.fromkeys(target_ids) if i]
    if not ids:
        return []
    rows = (
        db.table("admin_actions")
        .select(ACTION_COLUMNS)
        .in_("target_id", ids)
        .order("id", desc=True)
        .limit(limit)
        .execute()
        .data
    )
    return action_lines(rows, demo_only)


# ---------- The 3 days of a farmer ----------


def farmer_history(db: Client, orchard_id: str, boxes: list[dict], demo_only: bool,
                   extra_targets: list[str]) -> FarmerHistory:
    """Charts (3 days, every box), alert log, sensor problems and admin actions
    of one orchard. The 3 days end at the latest measure of the orchard: in
    demo mode the simulated clock runs ahead of the real one."""
    now = _now()
    node_ids = [b["node_id"] for b in boxes]
    latest = max((_time(b.get("measured_at")) for b in boxes if b.get("measured_at")), default=None)
    history = FarmerHistory(
        server_time=now,
        time_mode=next((b.get("time_mode") for b in boxes if b.get("time_mode")), None),
        actions=actions_on(db, node_ids + extra_targets, demo_only),
    )
    if not node_ids:
        return history
    by_node = {b["node_id"]: b for b in boxes}

    if latest is not None:
        start = latest - timedelta(hours=HISTORY_HOURS)
        history.window_start, history.window_end = start, latest
        rows = _all(
            lambda a, b: db.table("node_readings")
            .select("node_id, measured_at, soil_moisture_pct, air_temp_c, water_stress, heat_stress, battery_pct, level, "
                    "faults")
            .in_("node_id", node_ids)
            .gte("measured_at", _iso(start))
            .order("measured_at")
            .range(a, b)
        )
        points: dict[str, list[SeriesPoint]] = {n: [] for n in node_ids}
        for r in rows:
            t = _time(r["measured_at"])
            if t is None or t > latest or r["node_id"] not in points:
                continue
            faults = set(r.get("faults") or [])
            values = {"soil": r.get("soil_moisture_pct"), "air": r.get("air_temp_c"), "water": r.get("water_stress"),
                      "heat": r.get("heat_stress"), "battery": r.get("battery_pct")}
            for name, bad in BAD_VALUE.items():
                if faults & bad:
                    values[name] = None
            points[r["node_id"]].append(SeriesPoint(t=t, level=r.get("level"), **values))
        for pts in points.values():
            pts.sort(key=lambda p: p.t)
        history.series = [
            BoxSeries(node_id=n, device_code=by_node[n].get("device_code"), zone_letter=by_node[n].get("zone_letter"),
                      points=points[n])
            for n in node_ids
        ]

    events = (
        db.table("iot_alert_log")
        .select("id, node_id, device_code, zone_letter, measured_at, received_at, level, previous_level, reasons, cause, "
                "confidence, water_stress, heat_stress, soil_moisture_pct, air_temp_c, faults")
        .eq("orchard_id", orchard_id)
        .order("id", desc=True)
        .limit(ALERTS_SHOWN)
        .execute()
        .data
    )
    alerts = [AlertEvent(**{**e, "reasons": e.get("reasons") or [], "faults": e.get("faults") or []}) for e in events]
    # The latest 50 received, shown by time of measure (newest first).
    history.alerts = sorted(alerts, key=lambda a: (a.measured_at, a.id), reverse=True)

    since = ((latest or now) - timedelta(days=FAULT_DAYS)).date().isoformat()
    fault_rows = _all(
        lambda a, b: db.table("node_fault_days")
        .select("node_id, day, code, count, first_at, last_at")
        .in_("node_id", node_ids)
        .gte("day", since)
        .range(a, b)
    )
    grouped: dict[tuple[str, str], FaultLine] = {}
    for f in fault_rows:
        key = (f["node_id"], f["code"])
        first, last = _time(f["first_at"]), _time(f["last_at"])
        line = grouped.get(key)
        if line is None:
            box = by_node.get(f["node_id"], {})
            grouped[key] = FaultLine(node_id=f["node_id"], device_code=box.get("device_code"),
                                     zone_letter=box.get("zone_letter"), code=f["code"], days=1,
                                     count=f.get("count") or 0, first_at=first, last_at=last)
        else:
            line.days += 1
            line.count += f.get("count") or 0
            line.first_at, line.last_at = min(line.first_at, first), max(line.last_at, last)
    history.faults = sorted(grouped.values(), key=lambda x: x.last_at, reverse=True)
    return history


def farmer_history_of(db: Client, farmer_id: str, demo_only: bool) -> FarmerHistory | None:
    """The 3 days of one farmer (None: no such farmer, or not a demo account
    for the demo admin)."""
    rows = (
        db.table("profiles").select("id, is_demo, demo_account").eq("id", farmer_id).eq("role", "farmer")
        .limit(1).execute().data
    )
    if not rows or (demo_only and not is_demo_person(rows[0])):
        return None
    orchards = db.table("orchards").select("id").eq("farmer_id", farmer_id).limit(1).execute().data
    if not orchards:
        return FarmerHistory(server_time=_now(), actions=actions_on(db, [farmer_id], demo_only))
    oid = orchards[0]["id"]
    boxes = (
        db.table("iot_node_status").select("node_id, device_code, zone_letter, measured_at, time_mode")
        .eq("orchard_id", oid).execute().data
    )
    boxes.sort(key=lambda b: (b.get("zone_letter") or "", b.get("device_code") or ""))
    gateways = [g["code"] for g in db.table("gateways").select("code").eq("orchard_id", oid).execute().data]
    visits = [v["id"] for v in db.table("kit_requests").select("id").eq("orchard_id", oid).execute().data]
    return farmer_history(db, oid, boxes, demo_only, [farmer_id, *gateways, *visits])


# ---------- "Vue d'ensemble" ----------


def overview(db: Client) -> Overview:
    """The numbers and the "À faire" lists (admin_overview() of migration 013:
    the demo admin gets lists with demo accounts only)."""
    data: dict[str, Any] = db.rpc("admin_overview", {}).execute().data or {}
    todo = data.get("todo") or {}
    for key in ("boxes_waiting", "sensor_problems"):
        todo[key] = [{**b, "faults": b.get("faults") or []} for b in todo.get(key) or []]
    data["todo"] = todo
    return Overview(**data, server_time=_now())


# ---------- "Capteurs" ----------


def _people(db: Client, ids: set[str]) -> dict[str, dict]:
    if not ids:
        return {}
    rows = _all(
        lambda a, b: db.table("profiles")
        .select("id, name, phone, zone, is_demo, demo_account")
        .in_("id", sorted(ids))
        .range(a, b)
    )
    return {p["id"]: p for p in rows}


def sensors_page(db: Client, demo_only: bool) -> SensorsPage:
    """Every box, installation visit and gateway, with the farmer, and the
    latest admin actions on them."""
    now = _now()
    boxes = [
        clean_box(b)
        for b in _all(
            lambda a, b: db.table("iot_node_status")
            .select("node_id, orchard_id, farmer_id, zone_letter, device_code, status, level, faults, installed_at, "
                    "received_at, measured_at, last_refused_at, last_refused_reason, battery_pct, rssi_dbm, "
                    "gateway_code, time_mode")
            .range(a, b)
        )
    ]
    orchards = {o["id"]: o for o in _all(lambda a, b: db.table("orchards").select("id, farmer_id, is_demo").range(a, b))}
    visits = _all(
        lambda a, b: db.table("kit_requests")
        .select("id, user_id, phone, governorate, status, nodes, almond_trees, orchard_area_ha, admin_note, orchard_id, "
                "created_at, updated_at, installed_at")
        .order("created_at", desc=True)
        .range(a, b)
    )
    gateways = _all(
        lambda a, b: db.table("gateways")
        .select("code, orchard_id, enabled, time_mode, last_seen_at, last_result, history_minutes, "
                "offline_after_minutes, created_at")
        .order("code")
        .range(a, b)
    )
    people = _people(db, {b["farmer_id"] for b in boxes if b.get("farmer_id")}
                     | {v["user_id"] for v in visits}
                     | {orchards[g["orchard_id"]]["farmer_id"] for g in gateways if g["orchard_id"] in orchards})

    def demo_orchard(orchard_id: str | None) -> bool:
        o = orchards.get(orchard_id or "")
        return bool(o and (o.get("is_demo") or is_demo_person(people.get(o.get("farmer_id")))))

    page = SensorsPage(server_time=now)
    for b in boxes:
        demo = demo_orchard(b["orchard_id"])
        if demo_only and not demo:
            continue
        p = people.get(b["farmer_id"], {})
        page.boxes.append(SensorBox(
            **{k: v for k, v in b.items() if k in SensorBox.model_fields},
            farmer_name=p.get("name") or "", farmer_phone=p.get("phone"), governorate=p.get("zone"), demo=demo,
        ))
    status_rank = {"waiting": 0, "sensor_problem": 1, "offline": 2, "installed": 3, "online": 4}
    page.boxes.sort(key=lambda x: (status_rank.get(x.status, 9), x.farmer_name.lower(), x.zone_letter or ""))

    per_orchard: dict[str, list[dict]] = {}
    for b in boxes:
        per_orchard.setdefault(b["orchard_id"], []).append(b)
    visit_rank = {"new": 0, "contacted": 1, "installed": 2, "cancelled": 3}
    for v in visits:
        p = people.get(v["user_id"], {})
        demo = is_demo_person(p) or demo_orchard(v.get("orchard_id"))
        if demo_only and not demo:
            continue
        mine = per_orchard.get(v.get("orchard_id") or "", [])
        page.visits.append(VisitRow(
            **{k: val for k, val in v.items() if k in VisitRow.model_fields},
            farmer_name=p.get("name") or "", boxes_total=len(mine),
            boxes_accepted=sum(1 for b in mine if b.get("installed_at")), demo=demo,
        ))
    page.visits.sort(key=lambda x: visit_rank.get(x.status, 9))

    for g in gateways:
        o = orchards.get(g["orchard_id"], {})
        demo = demo_orchard(g["orchard_id"])
        if demo_only and not demo:
            continue
        p = people.get(o.get("farmer_id"), {})
        page.gateways.append(GatewayRow(**g, farmer_id=o.get("farmer_id"), farmer_name=p.get("name") or "", demo=demo))

    rows = (
        db.table("admin_actions")
        .select(ACTION_COLUMNS)
        .in_("target_type", ["node", "gateway", "visit"])
        .order("id", desc=True)
        .limit(ACTIONS_SHOWN * 2)
        .execute()
        .data
    )
    if demo_only:
        shown = {b.node_id for b in page.boxes} | {g.code for g in page.gateways} | {v.id for v in page.visits}
        rows = [r for r in rows if r.get("is_demo") or r.get("target_id") in shown]
    page.actions = action_lines(rows[:ACTIONS_SHOWN], demo_only)
    return page
