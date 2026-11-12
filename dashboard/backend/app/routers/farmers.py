"""Routes about the farmers and their sensor boxes (admins only)."""
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from .. import admin_data, iot
from ..auth import CurrentAdmin, get_current_admin
from ..schemas import FarmerDetail, FarmerHistory, FarmersPage

router = APIRouter(prefix="/api/farmers", tags=["farmers"])


def _check_id(farmer_id: str) -> None:
    try:
        UUID(farmer_id)
    except ValueError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Farmer not found") from None


@router.get("", response_model=FarmersPage)
def read_farmers(
    q: str = Query(default="", max_length=60, description="Part of a name or of a phone number"),
    admin: CurrentAdmin = Depends(get_current_admin),
) -> FarmersPage:
    """Every farmer with his pack, orchard and boxes (most recent data first).
    The demo admin: the demo accounts only."""
    return FarmersPage(farmers=iot.list_farmers(admin.db, q, admin.demo), server_time=datetime.now(timezone.utc))


@router.get("/{farmer_id}", response_model=FarmerDetail)
def read_farmer(farmer_id: str, admin: CurrentAdmin = Depends(get_current_admin)) -> FarmerDetail:
    """One farmer: pack, orchard (outline, zones, trees), boxes, gateway, visit."""
    _check_id(farmer_id)
    detail = iot.farmer_detail(admin.db, farmer_id, admin.demo)
    if detail is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Farmer not found")
    return detail


@router.get("/{farmer_id}/history", response_model=FarmerHistory)
def read_farmer_history(farmer_id: str, admin: CurrentAdmin = Depends(get_current_admin)) -> FarmerHistory:
    """The last 3 days of every box (charts), the alert log of the orchard,
    its sensor problems (14 days) and the admin actions on it."""
    _check_id(farmer_id)
    history = admin_data.farmer_history_of(admin.db, farmer_id, admin.demo)
    if history is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Farmer not found")
    return history
