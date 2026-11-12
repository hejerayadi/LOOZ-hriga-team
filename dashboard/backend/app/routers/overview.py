""""Vue d'ensemble": the key numbers and the "À faire" lists (admins only)."""
from fastapi import APIRouter, Depends

from .. import admin_data
from ..auth import CurrentAdmin, get_current_admin
from ..db_errors import checked_call
from ..schemas import Overview

router = APIRouter(prefix="/api/overview", tags=["overview"])


@router.get("", response_model=Overview)
def read_overview(admin: CurrentAdmin = Depends(get_current_admin)) -> Overview:
    """One call of admin_overview() (migration 013)."""
    with checked_call():
        return admin_data.overview(admin.db)
