"""Phase B, "Communauté": posts, one post (photo, answers), moderation, reports."""
from tests.conftest import db_error

REAL = "aa000000-0000-4000-8000-000000000001"     # a real farmer
DEMO = "aa000000-0000-4000-8000-000000000002"     # a demo account
FAKE = "aa000000-0000-4000-8000-000000000003"     # a fake person of the community
P_REAL = "b1000000-0000-4000-8000-000000000001"   # real post with a farmer's photo
P_DEMO = "b1000000-0000-4000-8000-000000000002"   # demo post with the app's demo picture, hidden
P_OLD = "b1000000-0000-4000-8000-000000000003"    # older demo post
C1 = "cc000000-0000-4000-8000-000000000001"
C2 = "cc000000-0000-4000-8000-000000000002"
C3 = "cc000000-0000-4000-8000-000000000003"
R1 = "d1000000-0000-4000-8000-000000000001"
PHOTO = f"{REAL}/photo-1.jpg"


def person(id, name, is_demo=False, demo_account=False, role="farmer", verified=False):
    return {"id": id, "role": role, "name": name, "first_name": None, "last_name": None, "phone": None, "zone": "sfax",
            "language": "ar", "verified": verified, "speciality": None, "organisation": None, "is_demo": is_demo,
            "demo_account": demo_account, "created_at": "2026-01-01T00:00:00+00:00"}


def post(id, author, text, date, photo=None, hidden=False):
    return {"id": id, "author_id": author, "type": "question", "text": text, "photo": photo, "hidden": hidden,
            "date": date, "updated_at": date}


def tables():
    return {
        "profiles": [person(REAL, "Mounir"), person(DEMO, "Nadia", demo_account=True),
                     person(FAKE, "سامي", is_demo=True, role="expert", verified=True)],
        "posts": [post(P_OLD, FAKE, "قديم", "2026-10-01T10:00:00+00:00"),
                  post(P_REAL, REAL, "Mes feuilles jaunissent", "2026-10-03T10:00:00+00:00", photo=PHOTO),
                  post(P_DEMO, DEMO, "سؤال", "2026-10-02T10:00:00+00:00", photo="demo:almond_blossoms", hidden=True)],
        "comments": [
            {"id": C1, "post_id": P_DEMO, "author_id": FAKE, "text": "جواب", "hidden": False,
             "created_at": "2026-10-02T11:00:00+00:00"},
            {"id": C2, "post_id": P_DEMO, "author_id": REAL, "text": "Réponse d'un vrai agriculteur", "hidden": True,
             "created_at": "2026-10-02T12:00:00+00:00"},
            {"id": C3, "post_id": P_REAL, "author_id": FAKE, "text": "Arrosez le soir", "hidden": False,
             "created_at": "2026-10-03T11:00:00+00:00"},
        ],
        "content_reports": [
            {"id": R1, "post_id": None, "comment_id": C1, "reporter_id": REAL, "reason": "wrong_advice", "note": None,
             "status": "open", "created_at": "2026-10-04T10:00:00+00:00", "resolved_at": None},
        ],
        "admin_actions": [
            {"id": 3, "created_at": "2026-11-01T10:00:00+00:00", "admin_name": "Hajer", "action": "post_hide",
             "target_type": "post", "target_id": P_DEMO, "target_label": "سؤال", "reason": "Essai", "details": {},
             "is_demo": False},
            {"id": 4, "created_at": "2026-11-02T10:00:00+00:00", "admin_name": "Hajer", "action": "post_hide",
             "target_type": "post", "target_id": P_REAL, "target_label": "Mes feuilles", "reason": "Essai",
             "details": {}, "is_demo": False},
        ],
    }


def test_posts_newest_first_with_their_counts(client_with):
    client = client_with(tables())
    r = client.get("/api/community")
    assert r.status_code == 200, r.text
    page = r.json()
    assert [p["id"] for p in page["posts"]] == [P_REAL, P_DEMO, P_OLD]
    demo_post = page["posts"][1]
    assert demo_post["hidden"] is True and demo_post["answers"] == 2 and demo_post["answers_hidden"] == 1
    assert demo_post["photo_kind"] == "demo" and demo_post["photo_demo"] == "almond_blossoms"
    assert page["posts"][0]["photo_kind"] == "storage" and page["posts"][0]["photo_demo"] is None
    assert page["posts"][2]["author"]["fake"] is True and page["posts"][2]["author"]["verified"] is True
    assert [(x["id"], x["reporter_name"], x["target_post_id"]) for x in page["reports"]] == [(R1, "Mounir", P_DEMO)]
    assert [a["id"] for a in page["actions"]] == [4, 3]


def test_demo_admin_sees_demo_posts_only(client_with):
    client = client_with(tables(), demo=True)
    page = client.get("/api/community").json()
    assert [p["id"] for p in page["posts"]] == [P_DEMO, P_OLD]
    assert [r["id"] for r in page["reports"]] == [R1]          # it is about the answer of a fake person
    assert [a["id"] for a in page["actions"]] == [3]           # not the action on the real post
    assert page["actions"][0]["admin_name"] == "Administrateur"
    assert client.get(f"/api/community/posts/{P_REAL}").status_code == 404
    d = client.get(f"/api/community/posts/{P_DEMO}").json()
    assert [a["id"] for a in d["answers"]] == [C1]              # not the real farmer's answer


def test_one_post_with_every_answer_and_its_photo(client_with):
    client = client_with(tables())
    client.db.storage.files["community"] = {PHOTO}
    d = client.get(f"/api/community/posts/{P_REAL}").json()
    assert d["photo_url"].startswith("https://storage.test/community/") and "expires=300" in d["photo_url"]
    assert [a["text"] for a in d["answers"]] == ["Arrosez le soir"]
    d = client.get(f"/api/community/posts/{P_DEMO}").json()
    assert d["photo_url"] is None and d["post"]["photo_demo"] == "almond_blossoms"
    assert [(a["id"], a["hidden"], a["reports_open"]) for a in d["answers"]] == [(C1, False, 1), (C2, True, 0)]
    assert [x["id"] for x in d["reports"]] == [R1]
    assert [a["id"] for a in d["actions"]] == [3]


def test_a_missing_photo_does_not_break_the_page(client_with):
    client = client_with(tables())   # the file is not in the storage
    r = client.get(f"/api/community/posts/{P_REAL}")
    assert r.status_code == 200 and r.json()["photo_url"] is None


def test_unknown_post(client_with):
    client = client_with(tables())
    assert client.get("/api/community/posts/b1000000-0000-4000-8000-000000000099").status_code == 404
    assert client.get("/api/community/posts/nope").status_code == 404


def test_hide_and_show_again(client_with):
    seen = []

    def moderate(p_type, p_id, p_action, p_reason):
        seen.append((p_type, p_id, p_action, p_reason))
        return {"photo": None}

    client = client_with(tables(), {"admin_moderate_content": moderate})
    r = client.post(f"/api/community/posts/{P_REAL}/moderate", json={"action": "hide", "reason": " Publicité "})
    assert r.status_code == 200 and r.json() == {"ok": True, "hidden": True, "deleted": False, "photo_removed": None}
    r = client.post(f"/api/community/comments/{C1}/moderate", json={"action": "unhide", "reason": "Vérifié"})
    assert r.json()["hidden"] is False
    assert seen == [("post", P_REAL, "hide", "Publicité"), ("comment", C1, "unhide", "Vérifié")]


def test_delete_a_post_removes_its_photo(client_with):
    client = client_with(tables(), {"admin_moderate_content": lambda **_: {"photo": PHOTO}})
    client.db.storage.files["community"] = {PHOTO}
    r = client.post(f"/api/community/posts/{P_REAL}/moderate", json={"action": "delete", "reason": "Insulte"})
    assert r.status_code == 200 and r.json()["deleted"] is True and r.json()["photo_removed"] is True
    assert client.db.storage.removed == [("community", PHOTO)]


def test_delete_a_post_whose_photo_cannot_be_removed(client_with):
    client = client_with(tables(), {"admin_moderate_content": lambda **_: {"photo": PHOTO}})
    client.db.storage.fail_remove = True
    r = client.post(f"/api/community/posts/{P_REAL}/moderate", json={"action": "delete", "reason": "Insulte"})
    assert r.status_code == 200 and r.json()["photo_removed"] is False


def test_moderation_refused(client_with):
    def short_reason(**_):
        raise db_error("22023", "Reason: 3 to 300 letters")

    client = client_with(tables(), {"admin_moderate_content": short_reason})
    r = client.post(f"/api/community/posts/{P_REAL}/moderate", json={"action": "hide", "reason": "a"})
    assert r.status_code == 422 and r.json()["detail"]["code"] == "reason"
    r = client.post(f"/api/community/posts/{P_REAL}/moderate", json={"action": "erase", "reason": "Essai"})
    assert r.status_code == 422                                  # not hide / unhide / delete
    assert client.post(f"/api/community/posts/{P_REAL}/moderate", json={"action": "hide"}).status_code == 422


def test_dismiss_a_report(client_with):
    seen = []

    def dismiss(p_report, p_reason):
        seen.append((p_report, p_reason))
        return {"id": p_report, "status": "dismissed"}

    def closed(**_):
        raise db_error("22023", "This report is already closed")

    client = client_with(tables(), {"admin_dismiss_report": dismiss})
    r = client.post(f"/api/community/reports/{R1}/dismiss", json={"reason": "Le conseil est juste"})
    assert r.status_code == 200 and r.json()["status"] == "dismissed" and seen == [(R1, "Le conseil est juste")]
    client = client_with(tables(), {"admin_dismiss_report": closed})
    r = client.post(f"/api/community/reports/{R1}/dismiss", json={"reason": "Encore"})
    assert r.status_code == 409 and r.json()["detail"]["code"] == "report_closed"
