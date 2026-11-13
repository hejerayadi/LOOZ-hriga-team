""""Alertes": the regional alerts (create / change / end, in Arabic AND
French) and the sensor alerts of every orchard (admins only).

Every CHANGE calls one checked function of migration 013 with the admin's
own token (the database checks the alert and writes the action log):
    admin_save_regional_alert   create (no id) or change (with id)
    admin_end_regional_alert    end now (reason required)
"""
from typing import Literal

from fastapi import APIRouter, Depends, Query

from .. import alerts_data
from ..auth import CurrentAdmin, get_current_admin
from ..db_errors import checked_call
from ..schemas import (
    AlertBody,
    RegionalAlert,
    RegionalAlertDetail,
    RegionalAlertsPage,
    ReasonBody,
    SensorAlertsPage,
)
from .common import not_found, one_row, uuid_or_404

router = APIRouter(prefix="/api/alerts", tags=["alerts"])

Level = Literal["ok", "info", "watch", "warning", "critical", "sensor"]


@router.get("/regional", response_model=RegionalAlertsPage)
def read_regional_alerts(admin: CurrentAdmin = Depends(get_current_admin)) -> RegionalAlertsPage:
    """Every regional alert (newest first). The demo admin: its demo alerts."""
    with checked_call():
        return alerts_data.regional_alerts(admin.db, admin.demo)


@router.get("/regional/{alert_id}", response_model=RegionalAlertDetail)
def read_regional_alert(alert_id: str, admin: CurrentAdmin = Depends(get_current_admin)) -> RegionalAlertDetail:
    aid = uuid_or_404(alert_id)
    with checked_call():
        detail = alerts_data.regional_alert(admin.db, aid, admin.demo)
    if detail is None:
        raise not_found()
    return detail


def _saved(admin: CurrentAdmin, row: dict) -> RegionalAlert:
    detail = alerts_data.regional_alert(admin.db, row["id"], admin.demo)
    if detail is None:
        raise not_found()
    return detail.alert


@router.post("/regional", response_model=RegionalAlert)
def create_regional_alert(body: AlertBody, admin: CurrentAdmin = Depends(get_current_admin)) -> RegionalAlert:
    """A new alert (starts now unless starts_at is given)."""
    with checked_call():
        row = one_row(admin.db.rpc("admin_save_regional_alert", {"p": alerts_data.alert_payload(body)}).execute().data)
        return _saved(admin, row)


@router.post("/regional/{alert_id}", response_model=RegionalAlert)
def update_regional_alert(alert_id: str, body: AlertBody,
                          admin: CurrentAdmin = Depends(get_current_admin)) -> RegionalAlert:
    """Change an alert that is not ended (every field is sent again)."""
    p = alerts_data.alert_payload(body, uuid_or_404(alert_id))
    with checked_call():
        row = one_row(admin.db.rpc("admin_save_regional_alert", {"p": p}).execute().data)
        return _saved(admin, row)


@router.post("/regional/{alert_id}/end", response_model=RegionalAlert)
def end_regional_alert(alert_id: str, body: ReasonBody, admin: CurrentAdmin = Depends(get_current_admin)) -> RegionalAlert:
    """End an alert now: it disappears from the app at once (reason required)."""
    params = {"p_id": uuid_or_404(alert_id), "p_reason": body.reason.strip()}
    with checked_call():
        row = one_row(admin.db.rpc("admin_end_regional_alert", params).execute().data)
        return _saved(admin, row)


@router.get("/sensors", response_model=SensorAlertsPage)
def read_sensor_alerts(
    level: Level | None = None,
    governorate: str | None = Query(default=None, pattern=r"^[a-z_]{3,20}$"),
    farmer_id: str | None = None,
    days: int = Query(default=7, ge=1, le=90),
    admin: CurrentAdmin = Depends(get_current_admin),
) -> SensorAlertsPage:
    """The newest changes of level of every box (at most 300), with filters."""
    fid = uuid_or_404(farmer_id) if farmer_id else None
    with checked_call():
        return alerts_data.sensor_alerts(admin.db, admin.demo, level, governorate, fid, days)
