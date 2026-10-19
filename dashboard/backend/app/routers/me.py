"""Routes about the logged-in admin."""
from fastapi import APIRouter, Depends

from ..auth import CurrentAdmin, get_current_admin
from ..schemas import Profile

router = APIRouter(prefix="/api", tags=["me"])


@router.get("/me", response_model=Profile)
def read_me(admin: CurrentAdmin = Depends(get_current_admin)) -> Profile:
    """Returns the profile of the logged-in admin (401/403 if not an admin)."""
    return admin.profile
