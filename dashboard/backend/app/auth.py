"""The "guard" of the API: get_current_admin.

Add it to a route and that route only works for logged-in admins:

    @router.get("/something")
    def something(admin: CurrentAdmin = Depends(get_current_admin)):
        rows = admin.db.table("posts").select("*").execute().data

Steps:
1. Read the header "Authorization: Bearer <token>".   Missing   -> 401
2. Ask Supabase who owns this token.                   Invalid   -> 401
3. Read this user's row in "profiles".                 Not admin -> 403
"""
from dataclasses import dataclass

import httpx
from fastapi import Header, HTTPException, status
from supabase import Client
from supabase_auth.errors import AuthError

from .config import DEMO_ADMIN_DOMAIN
from .schemas import Profile
from .supabase_client import user_client


@dataclass
class CurrentAdmin:
    profile: Profile
    # Supabase client acting as this admin (RLS applies). Use it for queries.
    db: Client

    @property
    def demo(self) -> bool:
        """The demo admin ("Connexion démo"): the lists show demo accounts
        only (screenshots), and the database lets it act on demo things only."""
        return self.profile.demo_admin


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=detail)


def get_current_admin(authorization: str | None = Header(default=None)) -> CurrentAdmin:
    # 1. The token
    if not authorization or not authorization.lower().startswith("bearer "):
        raise _unauthorized("Missing token")
    token = authorization.split(" ", 1)[1].strip()

    db = user_client(token)

    # 2. Who is it? (Supabase checks the token is real and not expired)
    try:
        response = db.auth.get_user(token)
    except AuthError:
        raise _unauthorized("Invalid or expired token")
    except httpx.HTTPError:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Supabase unreachable")
    if response is None or response.user is None:
        raise _unauthorized("Invalid or expired token")
    user = response.user

    # 3. Is it an admin? (this query runs WITH the user's token: RLS applies)
    rows = db.table("profiles").select("*").eq("id", user.id).limit(1).execute().data
    if not rows or rows[0].get("role") != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Access reserved to admins")

    demo = bool(user.email) and user.email.lower().endswith(DEMO_ADMIN_DOMAIN)
    return CurrentAdmin(profile=Profile(**rows[0], email=user.email, demo_admin=demo), db=db)
