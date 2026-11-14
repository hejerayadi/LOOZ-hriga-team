"""What the dashboard reads for "Alertes": the regional alerts (migration
013) and the sensor alerts of every orchard (view iot_alert_log, 012-013).

Every query runs with the ADMIN's token (admin.db): the database rules
(RLS) apply. demo_only = the demo admin ("Connexion démo"): only its demo
alerts and the boxes of demo accounts appear.
"""
from datetime import datetime, timedelta, timezone

from supabase import Client

from .admin_data import ACTION_COLUMNS, ACTIONS_SHOWN, action_lines, actions_on
from .iot import _all, _time, is_demo_person
from .people import display_name
from .schemas import (
    FarmerChoice,
    RegionalAlert,
    RegionalAlertDetail,
    RegionalAlertsPage,
    SensorAlertRow,
    SensorAlertsPage,
)

ALERT_COLUMNS = ("id, kind, severity, governorates, title_ar, title_fr, body_ar, body_fr, advice_ar, advice_fr, "
                 "starts_at, ends_at, ended_at, created_at, updated_at, created_by, ended_by, is_demo")
SENSOR_ALERTS_SHOWN = 300
EVENT_COLUMNS = ("id, node_id, device_code, zone_letter, measured_at, received_at, level, previous_level, reasons, cause, "
                 "confidence, water_stress, heat_stress, soil_moisture_pct, air_temp_c, faults, orchard_id, farmer_id, "
                 "demo_orchard, farmer_name, governorate")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def alert_status(row: dict, now: datetime) -> str:
    """ended (by an admin) / scheduled (not started) / expired (past its end) / active."""
    if row.get("ended_at"):
        return "ended"
    if _time(row["starts_at"]) > now:
        return "scheduled"
    ends = _time(row.get("ends_at"))
    if ends is not None and ends <= now:
        return "expired"
    return "active"


def _names(db: Client, ids: set[str]) -> dict[str, str]:
    ids = {i for i in ids if i}
    if not ids:
        return {}
    rows = db.table("profiles").select("id, name, first_name, last_name").in_("id", sorted(ids)).execute().data
    return {r["id"]: display_name(r) for r in rows}


def _alert(row: dict, names: dict[str, str], seen: dict[str, int], now: datetime, demo_only: bool,
           reach: dict[str, tuple[int, int]] | None = None) -> RegionalAlert:
    def who(uid: str | None) -> str:
        if not uid:
            return ""
        # The demo admin never sees the name of a real admin.
        if demo_only and not row.get("is_demo"):
            return "Administrateur"
        return names.get(uid) or "Administrateur"

    return RegionalAlert(
        **{k: v for k, v in row.items()
           if k in RegionalAlert.model_fields
           and k not in ("status", "seen_count", "opened_count", "done_count", "governorates")},
        governorates=row.get("governorates") or [],
        status=alert_status(row, now),
        seen_count=seen.get(row["id"], 0),
        opened_count=(reach or {}).get(row["id"], (0, 0))[0],
        done_count=(reach or {}).get(row["id"], (0, 0))[1],
        created_by_name=who(row.get("created_by")),
        ended_by_name=who(row.get("ended_by")),
    )


def _seen(db: Client, ids: list[str]) -> dict[str, int]:
    """How many farmers said "Moi aussi" on each alert."""
    if not ids:
        return {}
    counts: dict[str, int] = {}
    for r in _all(lambda a, b: db.table("regional_alert_reports").select("alert_id").in_("alert_id", ids).range(a, b)):
        counts[r["alert_id"]] = counts.get(r["alert_id"], 0) + 1
    return counts


def _reach(db: Client, ids: list[str]) -> dict[str, tuple[int, int]]:
    """How many farmers opened each alert in the app, and tapped "Fait"
    (regional_alert_reach() of migration 015, with the admin's token; the
    demo admin gets its demo alerts only). Without 015: zeros, the page
    still works."""
    if not ids:
        return {}
    try:
        rows = db.rpc("regional_alert_reach", {"p_ids": ids}).execute().data or []
    except Exception:  # noqa: BLE001 - a counter must never break the page
        return {}
    return {r["alert"]: (r.get("opened") or 0, r.get("done") or 0) for r in rows}


def regional_alerts(db: Client, demo_only: bool) -> RegionalAlertsPage:
    """Every regional alert (newest first) and the latest actions on them.
    The demo admin: its demo alerts only."""
    now = _now()
    rows = _all(lambda a, b: db.table("regional_alerts").select(ALERT_COLUMNS).order("created_at", desc=True).range(a, b))
    if demo_only:
        rows = [r for r in rows if r.get("is_demo")]
    names = _names(db, {r.get("created_by") for r in rows} | {r.get("ended_by") for r in rows})
    seen = _seen(db, [r["id"] for r in rows])
    reach = _reach(db, [r["id"] for r in rows])
    page = RegionalAlertsPage(alerts=[_alert(r, names, seen, now, demo_only, reach) for r in rows], server_time=now)
    lines = (
        db.table("admin_actions").select(ACTION_COLUMNS).eq("target_type", "regional_alert")
        .order("id", desc=True).limit(ACTIONS_SHOWN * 2).execute().data
    )
    if demo_only:
        shown = {a.id for a in page.alerts}
        lines = [x for x in lines if x.get("is_demo") or x.get("target_id") in shown]
    page.actions = action_lines(lines[:ACTIONS_SHOWN], demo_only)
    return page


def regional_alert(db: Client, alert_id: str, demo_only: bool) -> RegionalAlertDetail | None:
    now = _now()
    rows = db.table("regional_alerts").select(ALERT_COLUMNS).eq("id", alert_id).limit(1).execute().data
    if not rows or (demo_only and not rows[0].get("is_demo")):
        return None
    row = rows[0]
    names = _names(db, {row.get("created_by"), row.get("ended_by")})
    return RegionalAlertDetail(
        alert=_alert(row, names, _seen(db, [alert_id]), now, demo_only, _reach(db, [alert_id])),
        actions=actions_on(db, [alert_id], demo_only),
        server_time=now,
    )


def alert_payload(body, alert_id: str | None = None) -> dict:
    """The jsonb of admin_save_regional_alert(): codes, texts, dates."""
    governorates = body.governorates
    p: dict = {
        "kind": body.kind,
        "severity": body.severity,
        "governorates": "all" if governorates == ["all"] else governorates,
        "title_ar": body.title_ar,
        "title_fr": body.title_fr,
        "body_ar": body.body_ar,
        "body_fr": body.body_fr,
        "advice_ar": (body.advice_ar or "").strip() or None,
        "advice_fr": (body.advice_fr or "").strip() or None,
        "ends_at": (body.ends_at or "").strip() or None,
    }
    if alert_id:
        p["id"] = alert_id
    if body.starts_at and body.starts_at.strip():
        p["starts_at"] = body.starts_at.strip()
    return p


# ---------- The sensor alerts of every orchard ----------


def sensor_alerts(db: Client, demo_only: bool, level: str | None = None, governorate: str | None = None,
                  farmer_id: str | None = None, days: int = 7) -> SensorAlertsPage:
    """The newest changes of level of every box (at most 300), received in the
    last `days` days. Filters: level, governorate, farmer. The demo admin:
    the boxes of demo accounts only."""
    now = _now()
    people = {p["id"]: p for p in _all(lambda a, b: db.table("profiles").select("id, name, first_name, last_name, "
                                                                                "is_demo, demo_account")
                                       .eq("role", "farmer").range(a, b))}
    demo_ids = sorted(i for i, p in people.items() if is_demo_person(p))
    query = (
        db.table("iot_alert_log").select(EVENT_COLUMNS)
        .gte("received_at", (now - timedelta(days=days)).isoformat())
        .order("id", desc=True).limit(SENSOR_ALERTS_SHOWN)
    )
    if level:
        query = query.eq("level", level)
    if governorate:
        query = query.eq("governorate", governorate)
    if farmer_id:
        query = query.eq("farmer_id", farmer_id)
    if demo_only:
        query = query.in_("farmer_id", demo_ids)
    rows = query.execute().data or []

    page = SensorAlertsPage(limit=SENSOR_ALERTS_SHOWN, server_time=now)
    for r in rows:
        p = people.get(r.get("farmer_id") or "")
        page.events.append(SensorAlertRow(
            **{k: v for k, v in r.items() if k in SensorAlertRow.model_fields and k not in ("reasons", "faults", "farmer_name", "demo")},
            reasons=r.get("reasons") or [], faults=r.get("faults") or [],
            farmer_name=display_name(p) or r.get("farmer_name") or "",
            demo=bool(r.get("demo_orchard")) or is_demo_person(p),
        ))
    # The farmers who have boxes (for the filter).
    owners = {o["farmer_id"] for o in _all(lambda a, b: db.table("orchards").select("farmer_id").range(a, b))}
    page.farmers = sorted(
        (FarmerChoice(id=i, name=display_name(people[i]) or "Sans nom") for i in owners
         if i in people and (not demo_only or is_demo_person(people[i]))),
        key=lambda f: f.name.lower(),
    )
    return page
