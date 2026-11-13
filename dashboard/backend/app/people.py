"""What the dashboard reads for "Utilisateurs" and "Communauté"
(migrations 005 to 007 and 013).

Every query runs with the ADMIN's token (admin.db): the database rules
(RLS) apply. demo_only = the demo admin ("Connexion démo"): only demo
accounts and their posts appear (screenshots: no real person).
"""
from datetime import datetime, timezone
from typing import Any

from supabase import Client

from .admin_data import ACTION_COLUMNS, ACTIONS_SHOWN, action_lines, actions_on
from .iot import _all, _time, is_demo_person, make_pack
from .schemas import (
    Author,
    CommentRow,
    CommunityPage,
    PostDetail,
    PostRow,
    ReportRow,
    UserDetail,
    UserRow,
    UsersPage,
)

PHOTO_BUCKET = "community"
PHOTO_LINK_SECONDS = 300  # a farmer's photo: the link works 5 minutes
DEMO_PICTURE = "demo:"  # "demo:almond_blossoms" = a picture shipped in the app
PROFILE_COLUMNS = ("id, role, name, first_name, last_name, phone, zone, language, verified, speciality, organisation, "
                   "is_demo, demo_account, created_at")
USER_POSTS_SHOWN = 10


def _now() -> datetime:
    return datetime.now(timezone.utc)


def display_name(p: dict | None) -> str:
    """The name to show: "name", or first + last name. "New user" (the name
    the database gives an account that has none yet) is never shown."""
    if not p:
        return ""
    name = (p.get("name") or "").strip()
    if name and name != "New user":
        return name
    return " ".join(x.strip() for x in (p.get("first_name"), p.get("last_name")) if x and x.strip())


def author_of(p: dict | None) -> Author:
    if not p:
        return Author()
    return Author(id=p["id"], name=display_name(p), role=p.get("role"), verified=bool(p.get("verified")),
                  governorate=p.get("zone"), demo=is_demo_person(p), fake=bool(p.get("is_demo")))


def _profiles(db: Client, ids: set[str] | None = None) -> dict[str, dict]:
    """Profiles by id (every one when ids is None)."""
    if ids is not None and not ids:
        return {}

    def query(a: int, b: int):
        q = db.table("profiles").select(PROFILE_COLUMNS)
        if ids is not None:
            q = q.in_("id", sorted(ids))
        return q.order("created_at", desc=True).range(a, b)

    return {p["id"]: p for p in _all(query)}


def _auth(db: Client, ids: list[str] | None = None) -> dict[str, dict]:
    """Login facts (last login, blocked, e-mail of the admins) from
    admin_auth_users() of migration 013."""
    params: dict[str, Any] = {"p_ids": ids} if ids is not None else {}
    rows = db.rpc("admin_auth_users", params).execute().data or []
    return {r["id"]: r for r in rows}


# ---------- "Utilisateurs" ----------


def user_row(p: dict, auth: dict | None, sub: dict | None, orchard_status: str | None, posts: int, answers: int,
             now: datetime) -> UserRow:
    auth = auth or {}
    return UserRow(
        id=p["id"],
        name=display_name(p),
        role=p.get("role") or "farmer",
        phone=p.get("phone"),
        email=auth.get("email"),
        governorate=p.get("zone"),
        language=p.get("language"),
        created_at=_time(p.get("created_at")),
        last_sign_in_at=_time(auth.get("last_sign_in_at")),
        blocked=bool(auth.get("blocked")),
        verified=bool(p.get("verified")),
        speciality=p.get("speciality"),
        organisation=p.get("organisation"),
        pack=make_pack(sub, now) if p.get("role") == "farmer" else make_pack(None, now),
        orchard_status=orchard_status,
        posts=posts,
        answers=answers,
        demo=is_demo_person(p),
        fake=bool(p.get("is_demo")),
        demo_login=bool(auth.get("demo_login")),
    )


def _count_by(rows: list[dict], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for r in rows:
        counts[r[key]] = counts.get(r[key], 0) + 1
    return counts


def list_users(db: Client, demo_only: bool) -> UsersPage:
    """Every account: farmers, experts, admins (newest first). The demo
    admin: the demo accounts only."""
    now = _now()
    profiles = [p for p in _profiles(db).values() if not demo_only or is_demo_person(p)]
    if not profiles:
        return UsersPage(server_time=now)
    auth = _auth(db)
    subs = {s["user_id"]: s for s in _all(lambda a, b: db.table("subscriptions")
                                          .select("user_id, plan, status, ends_at, nodes").range(a, b))}
    orchards = {o["farmer_id"]: o["status"] for o in _all(lambda a, b: db.table("orchards")
                                                          .select("farmer_id, status").range(a, b))}
    posts = _count_by(_all(lambda a, b: db.table("posts").select("author_id").range(a, b)), "author_id")
    answers = _count_by(_all(lambda a, b: db.table("comments").select("author_id").range(a, b)), "author_id")
    users = [user_row(p, auth.get(p["id"]), subs.get(p["id"]), orchards.get(p["id"]), posts.get(p["id"], 0),
                      answers.get(p["id"], 0), now) for p in profiles]
    users.sort(key=lambda u: u.created_at or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
    return UsersPage(users=users, server_time=now)


def user_detail(db: Client, user_id: str, demo_only: bool) -> UserDetail | None:
    """One account, its latest posts and answers, and the admin actions on it.
    None: no such account (or not a demo account for the demo admin)."""
    now = _now()
    p = _profiles(db, {user_id}).get(user_id)
    if p is None or (demo_only and not is_demo_person(p)):
        return None
    auth = _auth(db, [user_id]).get(user_id)
    subs = db.table("subscriptions").select("user_id, plan, status, ends_at, nodes").eq("user_id", user_id).execute().data
    orchards = db.table("orchards").select("status").eq("farmer_id", user_id).limit(1).execute().data
    post_rows = (
        db.table("posts").select("id, author_id, type, text, photo, hidden, date, updated_at")
        .eq("author_id", user_id).order("date", desc=True).execute().data
    )
    answer_rows = (
        db.table("comments").select("id, post_id, author_id, text, hidden, created_at")
        .eq("author_id", user_id).order("created_at", desc=True).execute().data
    )
    row = user_row(p, auth, subs[0] if subs else None, orchards[0]["status"] if orchards else None,
                   len(post_rows), len(answer_rows), now)
    shown_posts = post_rows[:USER_POSTS_SHOWN]
    counts = _comment_counts(db, [x["id"] for x in shown_posts])
    open_reports = _open_reports(db, [x["id"] for x in shown_posts] + [a["id"] for a in answer_rows[:USER_POSTS_SHOWN]])
    author = author_of(p)
    return UserDetail(
        user=row,
        posts=[post_row(x, author, counts.get(x["id"], (0, 0)), open_reports.get(x["id"], 0)) for x in shown_posts],
        answers=[comment_row(a, author, open_reports.get(a["id"], 0)) for a in answer_rows[:USER_POSTS_SHOWN]],
        actions=actions_on(db, [user_id], demo_only),
        server_time=now,
    )


# ---------- "Communauté" ----------


def post_row(r: dict, author: Author, counts: tuple[int, int], reports_open: int) -> PostRow:
    photo = r.get("photo")
    demo_picture = photo[len(DEMO_PICTURE):] if photo and photo.startswith(DEMO_PICTURE) else None
    return PostRow(
        id=r["id"],
        type=r.get("type") or "question",
        text=r.get("text") or "",
        photo_kind=None if not photo else ("demo" if demo_picture else "storage"),
        photo_demo=demo_picture,
        hidden=bool(r.get("hidden")),
        created_at=_time(r.get("date")),
        updated_at=_time(r.get("updated_at")),
        author=author,
        answers=counts[0],
        answers_hidden=counts[1],
        reports_open=reports_open,
        demo=author.demo,
    )


def comment_row(r: dict, author: Author, reports_open: int) -> CommentRow:
    return CommentRow(id=r["id"], post_id=r["post_id"], text=r.get("text") or "", hidden=bool(r.get("hidden")),
                      created_at=_time(r.get("created_at")), author=author, reports_open=reports_open,
                      demo=author.demo)


def _comment_counts(db: Client, post_ids: list[str]) -> dict[str, tuple[int, int]]:
    """Per post: (answers, hidden answers)."""
    if not post_ids:
        return {}
    counts: dict[str, list[int]] = {}
    for c in _all(lambda a, b: db.table("comments").select("post_id, hidden").in_("post_id", post_ids).range(a, b)):
        n = counts.setdefault(c["post_id"], [0, 0])
        n[0] += 1
        n[1] += 1 if c.get("hidden") else 0
    return {k: (v[0], v[1]) for k, v in counts.items()}


def _open_reports(db: Client, target_ids: list[str]) -> dict[str, int]:
    """Per post or answer: its open reports."""
    if not target_ids:
        return {}
    counts: dict[str, int] = {}
    for r in _all(lambda a, b: db.table("content_reports").select("post_id, comment_id, status")
                  .eq("status", "open").range(a, b)):
        target = r.get("post_id") or r.get("comment_id")
        if target in target_ids:
            counts[target] = counts.get(target, 0) + 1
    return counts


REPORT_COLUMNS = "id, post_id, comment_id, reporter_id, reason, note, status, created_at, resolved_at"


def _reports(db: Client, rows: list[dict], posts: dict[str, dict], comments: dict[str, dict],
             people: dict[str, dict]) -> list[ReportRow]:
    result = []
    for r in rows:
        target = posts.get(r.get("post_id") or "") or comments.get(r.get("comment_id") or "") or {}
        author = people.get(target.get("author_id") or "")
        result.append(ReportRow(
            id=r["id"], post_id=r.get("post_id"), comment_id=r.get("comment_id"), reason=r["reason"],
            note=r.get("note"), status=r["status"], created_at=_time(r["created_at"]),
            resolved_at=_time(r.get("resolved_at")), reporter_name=display_name(people.get(r.get("reporter_id"))),
            target_text=(target.get("text") or "")[:200],
            target_post_id=r.get("post_id") or target.get("post_id"),
            demo=is_demo_person(author),
        ))
    return result


def list_community(db: Client, demo_only: bool) -> CommunityPage:
    """Every post (newest first, the hidden ones too), the reports, and the
    latest moderation actions. The demo admin: the posts of demo accounts."""
    now = _now()
    post_rows = _all(lambda a, b: db.table("posts").select("id, author_id, type, text, photo, hidden, date, updated_at")
                     .order("date", desc=True).range(a, b))
    comment_rows = _all(lambda a, b: db.table("comments").select("id, post_id, author_id, text, hidden").range(a, b))
    report_rows = _all(lambda a, b: db.table("content_reports").select(REPORT_COLUMNS)
                       .order("created_at", desc=True).range(a, b))
    people = _profiles(db, {x["author_id"] for x in post_rows} | {c["author_id"] for c in comment_rows}
                       | {r["reporter_id"] for r in report_rows})
    if demo_only:
        post_rows = [x for x in post_rows if is_demo_person(people.get(x["author_id"]))]
    counts: dict[str, list[int]] = {}
    for c in comment_rows:
        n = counts.setdefault(c["post_id"], [0, 0])
        n[0] += 1
        n[1] += 1 if c.get("hidden") else 0
    open_counts: dict[str, int] = {}
    for r in report_rows:
        if r["status"] == "open":
            target = r.get("post_id") or r.get("comment_id")
            open_counts[target] = open_counts.get(target, 0) + 1
    page = CommunityPage(server_time=now)
    page.posts = [
        post_row(x, author_of(people.get(x["author_id"])), tuple(counts.get(x["id"], [0, 0])),
                 open_counts.get(x["id"], 0))
        for x in post_rows
    ]
    page.reports = _reports(db, report_rows, {x["id"]: x for x in post_rows},
                            {c["id"]: c for c in comment_rows}, people)
    if demo_only:
        page.reports = [r for r in page.reports if r.demo]

    rows = (
        db.table("admin_actions").select(ACTION_COLUMNS)
        .in_("target_type", ["post", "comment", "report"])
        .order("id", desc=True).limit(ACTIONS_SHOWN * 2).execute().data
    )
    if demo_only:
        shown = {p.id for p in page.posts} | {c["id"] for c in comment_rows
                                              if is_demo_person(people.get(c["author_id"]))} | {r.id for r in page.reports}
        rows = [r for r in rows if r.get("is_demo") or r.get("target_id") in shown]
    page.actions = action_lines(rows[:ACTIONS_SHOWN], demo_only)
    return page


def photo_link(db: Client, path: str) -> str | None:
    """A link to a farmer's photo (private bucket), valid 5 minutes."""
    try:
        signed = db.storage.from_(PHOTO_BUCKET).create_signed_url(path, PHOTO_LINK_SECONDS)
    except Exception:  # noqa: BLE001 - no photo is better than no page
        return None
    if not isinstance(signed, dict):
        return None
    return signed.get("signedURL") or signed.get("signedUrl") or signed.get("signed_url")


def post_detail(db: Client, post_id: str, demo_only: bool) -> PostDetail | None:
    """One post with its photo, ALL its answers (the hidden ones too), its
    reports and the admin actions on it. None: no such post (or not a demo
    post for the demo admin)."""
    now = _now()
    rows = (db.table("posts").select("id, author_id, type, text, photo, hidden, date, updated_at")
            .eq("id", post_id).limit(1).execute().data)
    if not rows:
        return None
    r = rows[0]
    answer_rows = (db.table("comments").select("id, post_id, author_id, text, hidden, created_at")
                   .eq("post_id", post_id).order("created_at").execute().data)
    report_rows = _all(lambda a, b: db.table("content_reports").select(REPORT_COLUMNS)
                       .order("created_at", desc=True).range(a, b))
    answer_ids = {a["id"] for a in answer_rows}
    report_rows = [x for x in report_rows if x.get("post_id") == post_id or x.get("comment_id") in answer_ids]
    people = _profiles(db, {r["author_id"]} | {a["author_id"] for a in answer_rows}
                       | {x["reporter_id"] for x in report_rows})
    if demo_only and not is_demo_person(people.get(r["author_id"])):
        return None
    if demo_only:
        answer_rows = [a for a in answer_rows if is_demo_person(people.get(a["author_id"]))]
        answer_ids = {a["id"] for a in answer_rows}
        report_rows = [x for x in report_rows if x.get("post_id") == post_id or x.get("comment_id") in answer_ids]
    open_counts: dict[str, int] = {}
    for x in report_rows:
        if x["status"] == "open":
            target = x.get("post_id") or x.get("comment_id")
            open_counts[target] = open_counts.get(target, 0) + 1
    hidden = sum(1 for a in answer_rows if a.get("hidden"))
    post = post_row(r, author_of(people.get(r["author_id"])), (len(answer_rows), hidden), open_counts.get(post_id, 0))
    photo_url = photo_link(db, r["photo"]) if post.photo_kind == "storage" else None
    return PostDetail(
        post=post,
        photo_url=photo_url,
        answers=[comment_row(a, author_of(people.get(a["author_id"])), open_counts.get(a["id"], 0))
                 for a in answer_rows],
        reports=_reports(db, report_rows, {post_id: r}, {a["id"]: a for a in answer_rows}, people),
        actions=actions_on(db, [post_id, *answer_ids, *[x["id"] for x in report_rows]], demo_only),
        server_time=now,
    )


def remove_photo(db: Client, path: str) -> bool:
    """Deletes the photo of a deleted post from Storage (admins may: rule of
    migration 007). False: the file stays (delete it in Supabase › Storage)."""
    try:
        db.storage.from_(PHOTO_BUCKET).remove([path])
        return True
    except Exception:  # noqa: BLE001
        return False
