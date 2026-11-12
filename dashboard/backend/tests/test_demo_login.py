""""Connexion démo": the backend logs the demo admin in (the password stays
in backend/.env), only when the switch is on, only from this computer."""
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from supabase_auth.errors import AuthApiError

import app.routers.demo_login as demo_login
from app.config import Settings
from app.main import app
from tests.conftest import FakeDB, db_error

PASSWORD = "Pw-of-the-demo-admin-123"
DEMO_ID = "ad000000-0000-4000-8000-000000000002"


class FakeAuth:
    def __init__(self, ok=True):
        self.ok, self.logins, self.signed_out = ok, [], 0

    def sign_in_with_password(self, credentials):
        self.logins.append(credentials)
        if not self.ok:
            raise AuthApiError("Invalid login credentials", 400, "invalid_credentials")
        session = SimpleNamespace(access_token="access-1", refresh_token="refresh-1", expires_in=3600,
                                  expires_at=1_900_000_000)
        return SimpleNamespace(session=session, user=SimpleNamespace(id=DEMO_ID))

    def sign_out(self):
        self.signed_out += 1


@pytest.fixture
def setup(monkeypatch):
    """setup(switch=True, password=PASSWORD, role="admin", login_ok=True) -> (client, auth)."""
    def make(switch=True, password=PASSWORD, role="admin", login_ok=True, host="127.0.0.1"):
        auth = FakeAuth(login_ok)
        rpcs = {"demo_admin_login_enabled": (lambda: switch) if not isinstance(switch, Exception)
                else (lambda: (_ for _ in ()).throw(switch))}
        anon = FakeDB({}, rpcs)
        anon.auth = auth
        settings = Settings(demo_admin_password=password, frontend_url="http://localhost:3000")
        monkeypatch.setattr(demo_login, "get_settings", lambda: settings)
        monkeypatch.setattr(demo_login, "anon_client", lambda: anon)
        monkeypatch.setattr(demo_login, "user_client",
                            lambda token: FakeDB({"profiles": [{"id": DEMO_ID, "role": role}]}))
        monkeypatch.setattr(demo_login, "_last_login", 0.0)
        app.dependency_overrides.clear()
        return TestClient(app, client=(host, 50000)), auth
    return make


def test_status_shows_the_button_only_when_switch_on_and_password_set(setup):
    c, _ = setup()
    r = c.get("/api/demo-login")
    assert r.json() == {"enabled": True} and r.headers["cache-control"] == "no-store"
    c, _ = setup(switch=False)
    assert c.get("/api/demo-login").json() == {"enabled": False}
    c, _ = setup(password="")
    assert c.get("/api/demo-login").json() == {"enabled": False}
    c, _ = setup(switch=db_error("42883", "function does not exist"))       # 013 not run: no button
    assert c.get("/api/demo-login").json() == {"enabled": False}


def test_login_gives_a_session_never_the_password(setup):
    c, auth = setup()
    r = c.post("/api/demo-login", headers={"Origin": "http://127.0.0.1:3000"})
    assert r.status_code == 200
    assert r.json() == {"access_token": "access-1", "refresh_token": "refresh-1", "expires_in": 3600,
                        "expires_at": 1_900_000_000}
    assert PASSWORD not in r.text and r.headers["cache-control"] == "no-store"
    assert auth.logins == [{"email": "admin-demo@looz-demo.invalid", "password": PASSWORD}]


def test_login_refused_from_another_computer(setup):
    c, auth = setup(host="192.168.1.20")
    r = c.post("/api/demo-login")
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_local_only"
    assert auth.logins == []


def test_login_refused_from_another_website(setup):
    c, auth = setup()
    r = c.post("/api/demo-login", headers={"Origin": "https://evil.example"})
    assert r.status_code == 403 and auth.logins == []


def test_login_refused_when_switch_off_or_no_password(setup):
    c, auth = setup(switch=False)
    r = c.post("/api/demo-login")
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_off" and auth.logins == []
    c, auth = setup(password="")
    r = c.post("/api/demo-login")
    assert r.status_code == 503 and r.json()["detail"]["code"] == "demo_not_configured"


def test_wrong_password_or_not_admin(setup):
    c, _ = setup(login_ok=False)
    r = c.post("/api/demo-login")
    assert r.status_code == 502 and r.json()["detail"]["code"] == "demo_login_failed"
    c, auth = setup(role="farmer")                     # demo_admin.sql not run yet
    r = c.post("/api/demo-login")
    assert r.status_code == 403 and r.json()["detail"]["code"] == "demo_not_admin"
    assert auth.signed_out == 1 and "access-1" not in r.text


def test_one_login_every_few_seconds(setup):
    c, _ = setup()
    assert c.post("/api/demo-login").status_code == 200
    r = c.post("/api/demo-login")
    assert r.status_code == 429 and r.json()["detail"]["code"] == "too_many"


def test_cors_allows_the_dashboard_on_localhost_and_127_0_0_1():
    assert Settings(frontend_url="http://localhost:3000").cors_origins == ["http://localhost:3000", "http://127.0.0.1:3000"]
    assert Settings(frontend_url="http://127.0.0.1:3000/").cors_origins == ["http://127.0.0.1:3000", "http://localhost:3000"]
    c = TestClient(app)
    for origin in ("http://localhost:3000", "http://127.0.0.1:3000"):
        r = c.options("/api/me", headers={"Origin": origin, "Access-Control-Request-Method": "GET"})
        assert r.headers.get("access-control-allow-origin") == origin
    r = c.options("/api/me", headers={"Origin": "http://evil.example", "Access-Control-Request-Method": "GET"})
    assert "access-control-allow-origin" not in r.headers


def test_the_password_is_secret_in_the_settings():
    s = Settings(demo_admin_password=PASSWORD)
    assert PASSWORD not in repr(s) and PASSWORD not in str(s.model_dump())
