""""Communauté": posts, answers, reports, moderation (admins only).

Moderation = admin_moderate_content() of migration 013 (hide, show again,
delete, always with a reason; the log keeps a copy of the text). A deleted
post's photo is then removed from Storage with the admin's own token.
"""
from fastapi import APIRouter, Depends

from .. import people
from ..auth import CurrentAdmin, get_current_admin
from ..db_errors import checked_call
from ..schemas import ActionDone, CommunityPage, ModerateBody, ModerationDone, PostDetail, ReasonBody
from .common import not_found, one_row, uuid_or_404

router = APIRouter(prefix="/api/community", tags=["community"])


@router.get("", response_model=CommunityPage)
def read_community(admin: CurrentAdmin = Depends(get_current_admin)) -> CommunityPage:
    """Every post (newest first, hidden ones too), the reports, the latest
    moderation actions. The demo admin: the posts of demo accounts only."""
    with checked_call():
        return people.list_community(admin.db, admin.demo)


@router.get("/posts/{post_id}", response_model=PostDetail)
def read_post(post_id: str, admin: CurrentAdmin = Depends(get_current_admin)) -> PostDetail:
    """One post: its photo (a link valid 5 minutes), every answer, its reports
    and the admin actions on it."""
    pid = uuid_or_404(post_id)
    with checked_call():
        detail = people.post_detail(admin.db, pid, admin.demo)
    if detail is None:
        raise not_found()
    return detail


def _moderate(admin: CurrentAdmin, kind: str, target_id: str, body: ModerateBody) -> ModerationDone:
    params = {"p_type": kind, "p_id": uuid_or_404(target_id), "p_action": body.action, "p_reason": body.reason.strip()}
    with checked_call():
        result = admin.db.rpc("admin_moderate_content", params).execute().data or {}
    done = ModerationDone(hidden={"hide": True, "unhide": False}.get(body.action), deleted=body.action == "delete")
    photo = result.get("photo") if isinstance(result, dict) else None
    if photo:
        done.photo_removed = people.remove_photo(admin.db, photo)
    return done


@router.post("/posts/{post_id}/moderate", response_model=ModerationDone)
def moderate_post(post_id: str, body: ModerateBody, admin: CurrentAdmin = Depends(get_current_admin)) -> ModerationDone:
    """"Masquer" / "Afficher de nouveau" / "Supprimer" a post (reason required)."""
    return _moderate(admin, "post", post_id, body)


@router.post("/comments/{comment_id}/moderate", response_model=ModerationDone)
def moderate_comment(comment_id: str, body: ModerateBody,
                     admin: CurrentAdmin = Depends(get_current_admin)) -> ModerationDone:
    """The same for an answer."""
    return _moderate(admin, "comment", comment_id, body)


@router.post("/reports/{report_id}/dismiss", response_model=ActionDone)
def dismiss_report(report_id: str, body: ReasonBody, admin: CurrentAdmin = Depends(get_current_admin)) -> ActionDone:
    """"Classer" a report: nothing wrong (reason required)."""
    params = {"p_report": uuid_or_404(report_id), "p_reason": body.reason.strip()}
    with checked_call():
        row = one_row(admin.db.rpc("admin_dismiss_report", params).execute().data)
    return ActionDone(status=row.get("status"))
