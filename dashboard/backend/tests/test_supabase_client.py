"""SUPABASE_IPV4_ONLY: the Supabase clients use an IPv4-only connection pool."""
import httpx

import app.supabase_client as sc
from app.config import get_settings


def test_default_uses_the_library_client(monkeypatch):
    monkeypatch.setattr(get_settings(), "supabase_ipv4_only", False)
    assert sc._http_client() is None


def test_ipv4_only_gives_a_new_client_on_a_shared_ipv4_pool(monkeypatch):
    monkeypatch.setattr(get_settings(), "supabase_ipv4_only", True)
    a, b = sc._http_client(), sc._http_client()
    assert isinstance(a, httpx.Client) and a is not b          # one client per request: no shared token
    assert a._transport is b._transport is sc._ipv4_transport()
    assert a._transport._pool._local_address == "0.0.0.0"       # IPv4 only
    assert "authorization" not in {k.lower() for k in a.headers}


def test_user_client_with_ipv4_only_still_sends_the_token(monkeypatch):
    monkeypatch.setattr(get_settings(), "supabase_ipv4_only", True)
    db = sc.user_client("token-123")
    assert db.options.httpx_client is not None
    assert db.options.headers["Authorization"] == "Bearer token-123"
