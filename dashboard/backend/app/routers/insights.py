"""Routes of the pages "Prédictions IA", "Assistant vocal", "Diagnostics photo",
the trends of "Vue d'ensemble" and the full activity of a farmer (admins only,
read only: every query with the admin's own token)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from .. import insights
from ..auth import CurrentAdmin, get_current_admin

router = APIRouter(prefix="/api/insights", tags=["insights"])


def _uuid(value: str, what: str) -> str:
    try:
        return str(UUID(value))
    except ValueError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"{what} not found") from None


@router.get("/ml")
def read_ml(admin: CurrentAdmin = Depends(get_current_admin)) -> dict:
    """The latest predictions of every box, the in-app notifications, the counts per state."""
    return insights.ml_page(admin.db, admin.demo)


@router.get("/ml/history/{node_id}")
def read_ml_history(node_id: str, admin: CurrentAdmin = Depends(get_current_admin)) -> dict:
    """The prediction history of one box (charts)."""
    return insights.ml_history(admin.db, _uuid(node_id, "Box"), admin.demo)


@router.get("/zones/{zone_id}/context")
def read_zone_context(zone_id: str, admin: CurrentAdmin = Depends(get_current_admin)) -> dict:
    """The farm context the models use for a zone (and which values are defaults)."""
    data = insights.zone_context(admin.db, _uuid(zone_id, "Zone"))
    if data is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Zone not found")
    return data


@router.get("/voice")
def read_voice(days: int = Query(default=30, ge=1, le=90), admin: CurrentAdmin = Depends(get_current_admin)) -> dict:
    """The voice assistant's use: minutes, conversations, questions, tool calls (never a word)."""
    return insights.voice_page(admin.db, admin.demo, days)


@router.get("/diagnoses")
def read_diagnoses(admin: CurrentAdmin = Depends(get_current_admin)) -> dict:
    """The photo diagnoses (codes only, the photos stay private)."""
    return insights.diagnoses_page(admin.db, admin.demo)


@router.get("/trends")
def read_trends(days: int = Query(default=30, ge=7, le=90), admin: CurrentAdmin = Depends(get_current_admin)) -> dict:
    """Per day: sign-ups, demo payments, problems found, diagnoses, voice minutes, posts."""
    return insights.trends(admin.db, admin.demo, days)


@router.get("/farmers/{farmer_id}/activity")
def read_farmer_activity(farmer_id: str, admin: CurrentAdmin = Depends(get_current_admin)) -> dict:
    """Everything one farmer did and got in the app."""
    data = insights.farmer_activity(admin.db, _uuid(farmer_id, "Farmer"), admin.demo)
    if data is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Farmer not found")
    return data
