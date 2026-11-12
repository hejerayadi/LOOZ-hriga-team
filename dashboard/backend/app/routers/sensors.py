"""Sensor boxes, installation visits, gateways (admins only).

Reading: GET /api/sensors. Every CHANGE calls one checked function of
migration 013 with the admin's own token: the database checks the rules
(reason, demo admin...) and writes the line of the admin action log.
"""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Path, Response, status

from .. import admin_data
from ..auth import CurrentAdmin, get_current_admin
from ..db_errors import checked_call
from ..schemas import (
    AcceptBody,
    ActionDone,
    GatewayEnabledBody,
    NewKey,
    ReasonBody,
    SensorsPage,
    VisitBody,
)

router = APIRouter(prefix="/api", tags=["sensors"])

GATEWAY_CODE = Path(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{1,31}$")


def _uuid(value: str) -> str:
    try:
        return str(UUID(value))
    except ValueError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, {"code": "not_found", "message": "Unknown id"}) from None


def _row(data) -> dict:
    """A function returning one row: PostgREST sends an object (or a list of one)."""
    if isinstance(data, list):
        return data[0] if data else {}
    return data or {}


def _blank(text: str | None) -> str | None:
    return text.strip() or None if text is not None else None


@router.get("/sensors", response_model=SensorsPage)
def read_sensors(admin: CurrentAdmin = Depends(get_current_admin)) -> SensorsPage:
    """Every box (the waiting ones first), every installation visit, every
    gateway, and the latest admin actions on them."""
    with checked_call():
        return admin_data.sensors_page(admin.db, admin.demo)


@router.post("/nodes/{node_id}/accept", response_model=ActionDone)
def accept_node(node_id: str, body: AcceptBody, admin: CurrentAdmin = Depends(get_current_admin)) -> ActionDone:
    """"Accepter l'installation": the box may send (device_code = the code
    printed on the box, if it has none yet)."""
    params = {"p_node": _uuid(node_id), "p_device_code": _blank(body.device_code), "p_reason": _blank(body.reason)}
    with checked_call():
        row = _row(admin.db.rpc("iot_accept_node", params).execute().data)
    return ActionDone(installed_at=row.get("installed_at"), device_code=row.get("hardware_id"))


@router.post("/nodes/{node_id}/unaccept", response_model=ActionDone)
def unaccept_node(node_id: str, body: ReasonBody, admin: CurrentAdmin = Depends(get_current_admin)) -> ActionDone:
    """"Retirer l'acceptation" (reason required): the readings of the box are refused again."""
    params = {"p_node": _uuid(node_id), "p_reason": body.reason.strip()}
    with checked_call():
        row = _row(admin.db.rpc("iot_unaccept_node", params).execute().data)
    return ActionDone(installed_at=row.get("installed_at"), device_code=row.get("hardware_id"))


@router.post("/gateways/{code}/new-key", response_model=NewKey)
def new_gateway_key(response: Response, code: str = GATEWAY_CODE,
                    admin: CurrentAdmin = Depends(get_current_admin)) -> NewKey:
    """A NEW secret key for a gateway: the old one stops at once. Sent ONCE,
    never kept, never logged (not for the demo admin)."""
    response.headers["Cache-Control"] = "no-store"
    with checked_call():
        key = admin.db.rpc("iot_gateway_new_key", {"p_code": code.upper()}).execute().data
    if not isinstance(key, str) or not key.startswith("lgw_"):
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, {"code": "database", "message": "No key returned"})
    return NewKey(code=code.upper(), key=key)


@router.post("/gateways/{code}/enabled", response_model=ActionDone)
def set_gateway_enabled(body: GatewayEnabledBody, code: str = GATEWAY_CODE,
                        admin: CurrentAdmin = Depends(get_current_admin)) -> ActionDone:
    """Turn a gateway on or off (reason required; not for the demo admin)."""
    params = {"p_code": code.upper(), "p_enabled": body.enabled, "p_reason": body.reason.strip()}
    with checked_call():
        row = _row(admin.db.rpc("admin_set_gateway_enabled", params).execute().data)
    return ActionDone(enabled=row.get("enabled"))


@router.post("/visits/{visit_id}", response_model=ActionDone)
def update_visit(visit_id: str, body: VisitBody, admin: CurrentAdmin = Depends(get_current_admin)) -> ActionDone:
    """An installation visit: status new / contacted / cancelled, and a note.
    ("installed" comes by itself when every box of the orchard is accepted.)"""
    params = {"p_visit": _uuid(visit_id), "p_status": body.status, "p_note": body.note}
    with checked_call():
        row = _row(admin.db.rpc("admin_update_visit", params).execute().data)
    return ActionDone(status=row.get("status"))
