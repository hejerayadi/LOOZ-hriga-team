"""The ways to talk to Supabase.

- user_client(token): acts AS the logged-in user. RLS rules apply.
  Use this for almost everything.
- anon_client(): a visitor (no login), for the "Connexion démo" route only:
  ask the demo switch, log the demo admin in.
- service_client(): uses the secret service_role key. It IGNORES all RLS
  rules, so use it ONLY for actions that truly need it. Not used: every
  admin action goes through the checked functions of migration 013, with
  the admin's own token.

SUPABASE_IPV4_ONLY=true in .env: the connections to Supabase use IPv4 only
(a network with a broken IPv6 made every call wait about 40 s).
"""
from functools import lru_cache

import httpx
from supabase import Client, ClientOptions, create_client

from .config import get_settings


@lru_cache
def _ipv4_transport() -> httpx.HTTPTransport:
    """One pool of IPv4 connections, shared (it holds no token, no header)."""
    return httpx.HTTPTransport(local_address="0.0.0.0", retries=1)


def _http_client() -> httpx.Client | None:
    """None = the library's own client. Otherwise a NEW client per Supabase
    client (the token is sent with each request, never kept here)."""
    if not get_settings().supabase_ipv4_only:
        return None
    return httpx.Client(transport=_ipv4_transport(), timeout=30, follow_redirects=True)


def user_client(token: str) -> Client:
    """A Supabase client that sends the user's token with every query."""
    settings = get_settings()
    return create_client(
        settings.supabase_url,
        settings.supabase_anon_key,
        options=ClientOptions(
            headers={"Authorization": f"Bearer {token}"},
            # The server doesn't keep sessions: one client per request.
            persist_session=False,
            auto_refresh_token=False,
            httpx_client=_http_client(),
        ),
    )


def anon_client() -> Client:
    """A visitor's client (public key, no login, no session kept)."""
    settings = get_settings()
    return create_client(
        settings.supabase_url,
        settings.supabase_anon_key,
        options=ClientOptions(persist_session=False, auto_refresh_token=False, httpx_client=_http_client()),
    )


@lru_cache
def service_client() -> Client:
    """DANGER: bypasses RLS. Only for actions that truly need it."""
    settings = get_settings()
    return create_client(
        settings.supabase_url,
        settings.supabase_service_role_key,
        options=ClientOptions(persist_session=False, auto_refresh_token=False, httpx_client=_http_client()),
    )
