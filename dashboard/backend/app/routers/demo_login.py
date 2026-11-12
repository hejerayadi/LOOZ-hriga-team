""""Connexion démo": one click logs the DEMO ADMIN into the dashboard.

- The password is only in backend/.env (DEMO_ADMIN_PASSWORD): the backend
  logs in, the browser only gets the session (like after a normal login).
- Only when the switch app_settings.demo_admin_login_enabled is ON
  (migration 013, OFF by default), and only from this computer
  (127.0.0.1), from the dashboard's own address.
- The demo admin sees demo accounts only and acts on demo things only
  (the database checks it: migration 013).
"""
import threading
import time

import httpx
from fastapi import APIRouter, HTTPException, Request, Response, status
from postgrest.exceptions import APIError
from supabase_auth.errors import AuthError

from ..config import DEMO_ADMIN_DOMAIN, get_settings
from ..schemas import DemoLoginStatus, DemoSession
from ..supabase_client import anon_client, user_client

router = APIRouter(prefix="/api/demo-login", tags=["demo"])

LOCAL_HOSTS = {"127.0.0.1", "::1"}
MIN_SECONDS_BETWEEN = 3.0  # one login every 3 s at most
_last_login = 0.0
_lock = threading.Lock()


def _refuse(http_status: int, code: str, message: str) -> HTTPException:
    return HTTPException(http_status, {"code": code, "message": message})


def switch_on() -> bool:
    """The switch of migration 013 (a visitor may ask it: only yes / no)."""
    try:
        return anon_client().rpc("demo_admin_login_enabled", {}).execute().data is True
    except (APIError, httpx.HTTPError):
        return False


@router.get("", response_model=DemoLoginStatus)
def demo_login_status(response: Response) -> DemoLoginStatus:
    """Show the "Connexion démo" button? (switch on AND password in .env)"""
    response.headers["Cache-Control"] = "no-store"
    return DemoLoginStatus(enabled=get_settings().demo_login_configured and switch_on())


@router.post("", response_model=DemoSession)
def demo_login(request: Request, response: Response) -> DemoSession:
    global _last_login
    response.headers["Cache-Control"] = "no-store"
    settings = get_settings()

    host = request.client.host if request.client else ""
    if host not in LOCAL_HOSTS:
        raise _refuse(403, "demo_local_only", "Demo login only from this computer")
    origin = request.headers.get("origin")
    if origin is not None and origin.rstrip("/") not in settings.cors_origins:
        raise _refuse(403, "demo_local_only", "Demo login only from the dashboard")
    if not settings.demo_login_configured or not settings.demo_admin_email.lower().endswith(DEMO_ADMIN_DOMAIN):
        raise _refuse(503, "demo_not_configured", "DEMO_ADMIN_PASSWORD is not in backend/.env")
    if not switch_on():
        raise _refuse(403, "demo_off", "The demo login is off (app_settings.demo_admin_login_enabled)")
    with _lock:
        if time.monotonic() - _last_login < MIN_SECONDS_BETWEEN:
            raise _refuse(429, "too_many", "Wait a few seconds")
        _last_login = time.monotonic()

    client = anon_client()
    try:
        auth = client.auth.sign_in_with_password(
            {"email": settings.demo_admin_email, "password": settings.demo_admin_password.get_secret_value()}
        )
    except AuthError:
        raise _refuse(502, "demo_login_failed", "The demo admin login failed (account or password)") from None
    except httpx.HTTPError:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Supabase unreachable") from None
    session = auth.session
    if session is None or auth.user is None:
        raise _refuse(502, "demo_login_failed", "The demo admin login failed")

    # demo_admin.sql must have made it an admin.
    rows = (
        user_client(session.access_token).table("profiles").select("role").eq("id", auth.user.id)
        .limit(1).execute().data
    )
    if not rows or rows[0].get("role") != "admin":
        try:
            client.auth.sign_out()
        except (AuthError, httpx.HTTPError):
            pass
        raise _refuse(403, "demo_not_admin", "The demo account is not an admin (run supabase/seed/demo_admin.sql)")

    return DemoSession(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        expires_in=session.expires_in,
        expires_at=session.expires_at,
    )
