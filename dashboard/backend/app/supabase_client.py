"""The 2 ways to talk to Supabase.

- user_client(token): acts AS the logged-in user. RLS rules apply.
  Use this for almost everything.
- service_client(): uses the secret service_role key. It IGNORES all RLS
  rules, so use it ONLY for actions that truly need it (for example,
  managing login accounts in auth.users). Not used yet.
"""
from functools import lru_cache

from supabase import Client, ClientOptions, create_client

from .config import get_settings


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
        ),
    )


@lru_cache
def service_client() -> Client:
    """DANGER: bypasses RLS. Only for actions that truly need it."""
    settings = get_settings()
    return create_client(
        settings.supabase_url,
        settings.supabase_service_role_key,
        options=ClientOptions(persist_session=False, auto_refresh_token=False),
    )
