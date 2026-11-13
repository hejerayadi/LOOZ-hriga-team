""""Utilisateurs": every account, the expert badge, blocking (admins only).

Every CHANGE calls one checked function of migration 013 with the admin's
own token (the database checks the rules and writes the action log):
    admin_set_expert_verified   the badge "◆ خبير موثّق" of an expert
    admin_set_user_blocked      block / unblock (not the demo admin)
A role is never changed here (SQL only).
"""
from fastapi import APIRouter, Depends

from .. import people
from ..auth import CurrentAdmin, get_current_admin
from ..db_errors import checked_call
from ..schemas import ActionDone, BlockedBody, UserDetail, UsersPage, VerifiedBody
from .common import blank, not_found, one_row, uuid_or_404

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("", response_model=UsersPage)
def read_users(admin: CurrentAdmin = Depends(get_current_admin)) -> UsersPage:
    """Every account (newest first). The demo admin: the demo accounts only."""
    with checked_call():
        return people.list_users(admin.db, admin.demo)


@router.get("/{user_id}", response_model=UserDetail)
def read_user(user_id: str, admin: CurrentAdmin = Depends(get_current_admin)) -> UserDetail:
    """One account, its latest posts and answers, the admin actions on it."""
    uid = uuid_or_404(user_id)
    with checked_call():
        detail = people.user_detail(admin.db, uid, admin.demo)
    if detail is None:
        raise not_found()
    return detail


@router.post("/{user_id}/verified", response_model=ActionDone)
def set_verified(user_id: str, body: VerifiedBody, admin: CurrentAdmin = Depends(get_current_admin)) -> ActionDone:
    """"Vérifier" (reason optional) / "Retirer la vérification" (reason required)."""
    params = {"p_user": uuid_or_404(user_id), "p_verified": body.verified, "p_reason": blank(body.reason)}
    with checked_call():
        row = one_row(admin.db.rpc("admin_set_expert_verified", params).execute().data)
    return ActionDone(status="verified" if row.get("verified") else "not_verified")


@router.post("/{user_id}/blocked", response_model=ActionDone)
def set_blocked(user_id: str, body: BlockedBody, admin: CurrentAdmin = Depends(get_current_admin)) -> ActionDone:
    """"Bloquer" / "Débloquer" (reason required). A blocked account cannot log
    in or renew its session (at most one more hour in the app)."""
    params = {"p_user": uuid_or_404(user_id), "p_blocked": body.blocked, "p_reason": body.reason.strip()}
    with checked_call():
        until = admin.db.rpc("admin_set_user_blocked", params).execute().data
    return ActionDone(status="blocked" if until else "active")
