"""Who may use the API: only logged-in admins (401 / 403 otherwise)."""
from types import SimpleNamespace

import app.auth as auth
from tests.conftest import FakeDB


def fake_supabase(user, profiles):
    """A Supabase client that knows one token: its user and the profiles table."""
    db = FakeDB({"profiles": profiles})
    db.auth = SimpleNamespace(get_user=lambda token: SimpleNamespace(user=user) if user else None)
    return db


def test_health_needs_no_login(client):
    assert client.get("/api/health").json() == {"status": "ok"}


def test_no_token_is_refused(client):
    for path in ("/api/me", "/api/farmers", "/api/farmers/ee000000-0000-4000-8000-000000000010"):
        assert client.get(path).status_code == 401, path


def test_not_a_bearer_token_is_refused(client):
    assert client.get("/api/farmers", headers={"Authorization": "Basic abc"}).status_code == 401


def test_unknown_token_is_refused(client, monkeypatch):
    monkeypatch.setattr(auth, "user_client", lambda token: fake_supabase(None, []))
    assert client.get("/api/farmers", headers={"Authorization": "Bearer nope"}).status_code == 401


def test_a_farmer_is_refused_403(client, monkeypatch):
    user = SimpleNamespace(id="f1", email=None)
    monkeypatch.setattr(auth, "user_client", lambda token: fake_supabase(user, [{"id": "f1", "role": "farmer", "name": "Ali"}]))
    response = client.get("/api/farmers", headers={"Authorization": "Bearer t"})
    assert response.status_code == 403


def test_an_admin_gets_his_profile(client, monkeypatch):
    user = SimpleNamespace(id="a1", email="admin@example.com")
    monkeypatch.setattr(auth, "user_client", lambda token: fake_supabase(user, [{"id": "a1", "role": "admin", "name": "Hajer"}]))
    response = client.get("/api/me", headers={"Authorization": "Bearer t"})
    assert response.status_code == 200
    assert response.json()["role"] == "admin"
    assert response.json()["email"] == "admin@example.com"
