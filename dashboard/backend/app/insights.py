"""What the dashboard reads about everything the app does (migrations 016-019):
the ML predictions (with their reasons and Groq texts), the in-app
notifications, the voice assistant's usage (minutes, questions, tool calls —
never a word: nothing else is saved), the photo diagnoses, the trends of
"Vue d'ensemble", and ALL the activity of one farmer.

Every query runs with the ADMIN's token (admin.db): the database rules apply
(the demo admin reads demo rows only: migrations 014 and 019). As on the other
pages, demo_only also filters here (the fake database of the tests).
"""
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone

from supabase import Client

from .iot import _all, _time, is_demo_person
from .people import display_name

PROFILE_COLUMNS = "id, role, name, first_name, last_name, phone, zone, is_demo, demo_account, created_at"
ML_COLUMNS = ("node_id, model, zone_id, orchard_id, farmer_id, measured_at, predicted_at, status, state, confidence, "
              "certainty, probabilities, threshold, factors, readings, explanation_ar, explanation_fr, action_ar, "
              "action_fr, explanation_source, model_version, state_since")
NOTIF_COLUMNS = "id, farmer_id, node_id, zone_id, model, state, severity, confidence, certainty, measured_at, created_at, read_at, resolved_at"
VOICE_COLUMNS = "id, user_id, model, started_at, ended_at, charged_seconds, end_reason, questions, tool_calls, community_posts, tokens_in, tokens_out"
DIAG_COLUMNS = "id, user_id, zone_id, status, model, verdict, top_class, top_confidence, plant, error, post_id, created_at, finished_at"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _rows(db: Client, table: str, columns: str, build=None, limit: int | None = None) -> list[dict]:
    """Every row (or the first `limit`), newest first when build sets an order."""
    def query(a: int, b: int):
        q = db.table(table).select(columns)
        if build:
            q = build(q)
        return q.range(a, b)

    rows = _all(query)
    return rows[:limit] if limit else rows


def _profiles(db: Client, ids: set[str]) -> dict[str, dict]:
    ids = {i for i in ids if i}
    if not ids:
        return {}
    rows = _rows(db, "profiles", PROFILE_COLUMNS, lambda q: q.in_("id", sorted(ids)))
    return {p["id"]: p for p in rows}


def _person(p: dict | None) -> dict:
    if not p:
        return {"id": None, "name": "", "phone": None, "governorate": None, "demo": False}
    return {"id": p["id"], "name": display_name(p), "phone": p.get("phone"), "governorate": p.get("zone"),
            "demo": is_demo_person(p)}


def _zones_nodes(db: Client, zone_ids: set[str], node_ids: set[str]) -> tuple[dict, dict]:
    zones = {z["id"]: z for z in _rows(db, "zones", "id, letter, name, orchard_id",
                                       lambda q: q.in_("id", sorted(zone_ids)))} if zone_ids else {}
    nodes = {n["id"]: n for n in _rows(db, "nodes", "id, hardware_id, zone_id",
                                       lambda q: q.in_("id", sorted(node_ids)))} if node_ids else {}
    return zones, nodes


def _keep(person: dict | None, demo_only: bool) -> bool:
    return not demo_only or is_demo_person(person)


# ---------- ML predictions ----------


def _prediction(r: dict, people: dict, zones: dict, nodes: dict) -> dict:
    z = zones.get(r.get("zone_id")) or {}
    n = nodes.get(r["node_id"]) or {}
    return {
        **{k: r.get(k) for k in ("node_id", "model", "status", "state", "confidence", "certainty", "probabilities",
                                 "threshold", "factors", "readings", "explanation_ar", "explanation_fr", "action_ar",
                                 "action_fr", "explanation_source", "model_version", "measured_at", "predicted_at",
                                 "state_since")},
        "farmer": _person(people.get(r.get("farmer_id"))),
        "zone": {"id": r.get("zone_id"), "letter": z.get("letter"), "name": z.get("name") or ""},
        "device_code": n.get("hardware_id"),
    }


def _notification(r: dict, people: dict, zones: dict, nodes: dict) -> dict:
    z = zones.get(r.get("zone_id")) or {}
    return {**{k: r.get(k) for k in ("id", "model", "state", "severity", "confidence", "certainty", "measured_at",
                                     "created_at", "read_at", "resolved_at", "node_id")},
            "farmer": _person(people.get(r.get("farmer_id"))),
            "zone": {"id": r.get("zone_id"), "letter": z.get("letter"), "name": z.get("name") or ""},
            "device_code": (nodes.get(r.get("node_id")) or {}).get("hardware_id")}


def ml_page(db: Client, demo_only: bool, farmer_id: str | None = None) -> dict:
    """The latest prediction of every box and model, the notifications (50
    newest), the counts per state, and the worker's last round."""
    def mine(q):
        return q.eq("farmer_id", farmer_id) if farmer_id else q

    latest = _rows(db, "ml_latest", ML_COLUMNS, lambda q: mine(q).order("predicted_at", desc=True))
    notes = _rows(db, "ml_notifications", NOTIF_COLUMNS, lambda q: mine(q).order("created_at", desc=True), limit=50)
    people = _profiles(db, {r.get("farmer_id") for r in latest + notes})
    zones, nodes = _zones_nodes(db, {r.get("zone_id") for r in latest + notes if r.get("zone_id")},
                                {r["node_id"] for r in latest + notes})
    latest = [r for r in latest if _keep(people.get(r.get("farmer_id")), demo_only)]
    notes = [r for r in notes if _keep(people.get(r.get("farmer_id")), demo_only)]
    counts = Counter((r["model"], r["state"] if r["status"] == "ok" else r["status"]) for r in latest)
    worker = None
    if not demo_only and not farmer_id:
        rows = _rows(db, "ml_workers", "code, enabled, last_seen_at, last_result", lambda q: q.order("code"))
        worker = rows[0] if rows else None
    return {
        "predictions": [_prediction(r, people, zones, nodes) for r in latest],
        "notifications": [_notification(r, people, zones, nodes) for r in notes],
        "counts": [{"model": m, "state": s, "count": c} for (m, s), c in sorted(counts.items())],
        "open_problems": sum(1 for r in notes if not r.get("resolved_at")),
        "worker": worker,
        "server_time": _now().isoformat(),
    }


def ml_history(db: Client, node_id: str, demo_only: bool) -> dict:
    """The prediction history of one box (a point per change or per hour): the charts."""
    rows = _rows(db, "ml_history", "model, measured_at, status, state, confidence, certainty, factors, explanation_fr, changed",
                 lambda q: q.eq("node_id", node_id).order("measured_at", desc=False))
    if demo_only:
        latest = _rows(db, "ml_latest", "farmer_id", lambda q: q.eq("node_id", node_id), limit=1)
        people = _profiles(db, {latest[0]["farmer_id"]} if latest else set())
        if not latest or not _keep(people.get(latest[0]["farmer_id"]), True):
            return {"node_id": node_id, "points": []}
    return {"node_id": node_id, "points": rows}


# ---------- voice assistant and photo diagnosis ----------


def _days(n: int) -> list[date]:
    today = _now().date()
    return [today - timedelta(days=i) for i in range(n - 1, -1, -1)]


def voice_page(db: Client, demo_only: bool, days: int = 30, user_id: str | None = None) -> dict:
    """Minutes, conversations, questions and tool calls per day and per farmer
    (no transcript: LOOZ never saves the words)."""
    since = (_now() - timedelta(days=days)).isoformat()
    rows = _rows(db, "voice_sessions", VOICE_COLUMNS,
                 lambda q: (q.eq("user_id", user_id) if user_id else q).gte("started_at", since).order("started_at", desc=True))
    people = _profiles(db, {r["user_id"] for r in rows})
    rows = [r for r in rows if _keep(people.get(r["user_id"]), demo_only)]
    per_day: dict[str, dict] = {d.isoformat(): {"minutes": 0.0, "sessions": 0, "questions": 0, "tool_calls": 0} for d in _days(days)}
    per_user: dict[str, dict] = defaultdict(lambda: {"sessions": 0, "minutes": 0.0, "questions": 0, "tool_calls": 0, "last": None})
    for r in rows:
        d = (_time(r["started_at"]) or _now()).date().isoformat()
        minutes = (r.get("charged_seconds") or 0) / 60
        for bucket in [per_day.get(d), per_user[r["user_id"]]]:
            if bucket is None:
                continue
            bucket["minutes"] += minutes
            bucket["sessions"] += 1
            bucket["questions"] += r.get("questions") or 0
            bucket["tool_calls"] += r.get("tool_calls") or 0
        u = per_user[r["user_id"]]
        u["last"] = max(filter(None, [u["last"], r["started_at"]]))
    return {
        "days": [{"day": d, **v, "minutes": round(v["minutes"], 1)} for d, v in per_day.items()],
        "by_farmer": sorted(({"farmer": _person(people.get(uid)), **v, "minutes": round(v["minutes"], 1)}
                             for uid, v in per_user.items()), key=lambda x: -x["minutes"]),
        "sessions": [{**{k: r.get(k) for k in ("id", "started_at", "ended_at", "charged_seconds", "end_reason",
                                               "questions", "tool_calls", "community_posts", "tokens_in", "tokens_out", "model")},
                      "farmer": _person(people.get(r["user_id"]))} for r in rows[:100]],
        "totals": {"sessions": len(rows), "minutes": round(sum((r.get("charged_seconds") or 0) for r in rows) / 60, 1),
                   "questions": sum(r.get("questions") or 0 for r in rows),
                   "tool_calls": sum(r.get("tool_calls") or 0 for r in rows)},
    }


def diagnoses_page(db: Client, demo_only: bool, user_id: str | None = None) -> dict:
    """Every photo diagnosis (codes only; the photo stays private)."""
    rows = _rows(db, "photo_diagnoses", DIAG_COLUMNS,
                 lambda q: (q.eq("user_id", user_id) if user_id else q).order("created_at", desc=True), limit=300)
    people = _profiles(db, {r["user_id"] for r in rows})
    rows = [r for r in rows if _keep(people.get(r["user_id"]), demo_only)]
    return {
        "diagnoses": [{**r, "farmer": _person(people.get(r["user_id"]))} for r in rows],
        "by_verdict": dict(Counter(r.get("verdict") or r.get("status") for r in rows)),
        "by_class": dict(Counter(r.get("top_class") for r in rows if r.get("top_class"))),
        "by_model": dict(Counter((r.get("model") or "").split(":")[0] for r in rows)),
    }


# ---------- trends of "Vue d'ensemble" ----------


def trends(db: Client, demo_only: bool, days: int = 30) -> dict:
    """Per day, the last `days` days: sign-ups, demo payments (DT), problems
    found by the predictions, photo diagnoses, minutes of voice, community posts."""
    since = (_now() - timedelta(days=days)).isoformat()
    span = [d.isoformat() for d in _days(days)]

    def by_day(rows: list[dict], key: str, value=None) -> list[float]:
        acc = dict.fromkeys(span, 0.0)
        for r in rows:
            t = _time(r.get(key))
            if t is None:
                continue
            d = t.date().isoformat()
            if d in acc:
                acc[d] += value(r) if value else 1
        return [round(acc[d], 2) for d in span]

    profiles = _rows(db, "profiles", PROFILE_COLUMNS, lambda q: q.gte("created_at", since))
    profiles = [p for p in profiles if p.get("role") in ("farmer", "expert") and _keep(p, demo_only)]
    payments = _rows(db, "payments", "user_id, amount_millimes, status, created_at", lambda q: q.gte("created_at", since))
    notes = _rows(db, "ml_notifications", "farmer_id, created_at", lambda q: q.gte("created_at", since))
    diags = _rows(db, "photo_diagnoses", "user_id, created_at", lambda q: q.gte("created_at", since))
    voice = _rows(db, "voice_sessions", "user_id, started_at, charged_seconds", lambda q: q.gte("started_at", since))
    posts = _rows(db, "posts", "author_id, date", lambda q: q.gte("date", since))
    people = _profiles(db, {r.get("user_id") for r in payments + diags + voice}
                       | {r.get("farmer_id") for r in notes} | {r.get("author_id") for r in posts})

    def keep(rows, who):
        return [r for r in rows if _keep(people.get(r.get(who)), demo_only)]

    payments = keep(payments, "user_id")
    return {
        "days": span,
        "series": {
            "signups": by_day(profiles, "created_at"),
            "payments_dt": by_day([p for p in payments if p.get("status") == "paid_demo"], "created_at",
                                  lambda r: (r.get("amount_millimes") or 0) / 1000),
            "problems": by_day(keep(notes, "farmer_id"), "created_at"),
            "diagnoses": by_day(keep(diags, "user_id"), "created_at"),
            "voice_minutes": by_day(keep(voice, "user_id"), "started_at", lambda r: (r.get("charged_seconds") or 0) / 60),
            "posts": by_day(keep(posts, "author_id"), "date"),
        },
    }


# ---------- everything of one farmer ----------


def farmer_activity(db: Client, farmer_id: str, demo_only: bool) -> dict | None:
    """ALL the activity of one farmer, for his page: pack and payments,
    predictions and notifications, photo diagnoses, voice conversations,
    posts / answers / reports, "Moi aussi", and the admin actions on him."""
    people = _profiles(db, {farmer_id})
    me = people.get(farmer_id)
    if me is None or not _keep(me, demo_only):
        return None
    subs = _rows(db, "subscriptions", "id, plan, status, started_at, ends_at, nodes",
                 lambda q: q.eq("user_id", farmer_id).order("started_at", desc=True))
    payments = _rows(db, "payments", "id, plan, kind, amount_millimes, status, nodes, period_days, created_at, paid_at",
                     lambda q: q.eq("user_id", farmer_id).order("created_at", desc=True))
    posts = _rows(db, "posts", "id, text, hidden, date, photo", lambda q: q.eq("author_id", farmer_id).order("date", desc=True))
    comments = _rows(db, "comments", "id, post_id, text, hidden, created_at",
                     lambda q: q.eq("author_id", farmer_id).order("created_at", desc=True))
    reports = _rows(db, "content_reports", "id, post_id, comment_id, reason, status, created_at",
                    lambda q: q.eq("reporter_id", farmer_id).order("created_at", desc=True))
    me_too = _rows(db, "regional_alert_reports", "alert_id, created_at",
                   lambda q: q.eq("user_id", farmer_id).order("created_at", desc=True))
    actions = _rows(db, "admin_actions", "id, created_at, admin_name, action, target_type, target_label, reason, is_demo",
                    lambda q: q.eq("target_id", farmer_id).order("id", desc=True), limit=50)
    ml = ml_page(db, demo_only, farmer_id)
    timeline = (
        [{"at": p["created_at"], "kind": "payment", "label": p.get("status"), "detail": (p.get("amount_millimes") or 0) / 1000}
         for p in payments]
        + [{"at": n["created_at"], "kind": "notification", "label": n["state"], "detail": n["zone"]["letter"]}
           for n in ml["notifications"]]
        + [{"at": d["created_at"], "kind": "diagnosis", "label": d.get("verdict") or d.get("status"),
            "detail": d.get("top_class")} for d in diagnoses_page(db, demo_only, farmer_id)["diagnoses"]]
        + [{"at": s["started_at"], "kind": "voice", "label": s.get("end_reason"),
            "detail": round((s.get("charged_seconds") or 0) / 60, 1)} for s in voice_page(db, demo_only, 90, farmer_id)["sessions"]]
        + [{"at": p["date"], "kind": "post", "label": "hidden" if p.get("hidden") else "visible", "detail": (p.get("text") or "")[:80]}
           for p in posts]
        + [{"at": c["created_at"], "kind": "answer", "label": "hidden" if c.get("hidden") else "visible",
            "detail": (c.get("text") or "")[:80]} for c in comments]
        + [{"at": r["created_at"], "kind": "report", "label": r.get("reason"), "detail": r.get("status")} for r in reports]
        + [{"at": m["created_at"], "kind": "me_too", "label": "me_too", "detail": None} for m in me_too]
    )
    timeline.sort(key=lambda e: e["at"] or "", reverse=True)
    return {
        "farmer": {**_person(me), "role": me.get("role"), "created_at": me.get("created_at")},
        "subscriptions": subs,
        "payments": payments,
        "ml": ml,
        "diagnoses": diagnoses_page(db, demo_only, farmer_id),
        "voice": voice_page(db, demo_only, 90, farmer_id),
        "community": {"posts": posts[:30], "answers": comments[:30], "reports": reports[:30], "me_too": len(me_too)},
        "admin_actions": actions,
        "timeline": timeline[:150],
    }


def zone_context(db: Client, zone_id: str) -> dict | None:
    """The farm context the models use for a zone, and which values are defaults."""
    data = db.rpc("admin_zone_context", {"p_zone": zone_id}).execute().data
    return data if isinstance(data, dict) else None
