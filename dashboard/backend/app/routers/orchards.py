""""Vergers": every orchard and its plan (admins only, read only)."""
from fastapi import APIRouter, Depends

from .. import billing
from ..auth import CurrentAdmin, get_current_admin
from ..db_errors import checked_call
from ..schemas import OrchardDetail, OrchardsPage
from .common import not_found, uuid_or_404

router = APIRouter(prefix="/api/orchards", tags=["orchards"])


@router.get("", response_model=OrchardsPage)
def read_orchards(admin: CurrentAdmin = Depends(get_current_admin)) -> OrchardsPage:
    """Every orchard (newest first). The demo admin: the demo orchards only."""
    with checked_call():
        return billing.orchards_page(admin.db, admin.demo)


@router.get("/{orchard_id}", response_model=OrchardDetail)
def read_orchard(orchard_id: str, admin: CurrentAdmin = Depends(get_current_admin)) -> OrchardDetail:
    """One orchard: the plan (zones, trees, boxes) and the bill of one period."""
    oid = uuid_or_404(orchard_id)
    with checked_call():
        detail = billing.orchard_detail(admin.db, oid, admin.demo)
    if detail is None:
        raise not_found()
    return detail
