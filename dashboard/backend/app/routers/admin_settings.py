""""Abonnements" (price, hectares per node), "Réglages" (the switches) and
the "Journal des actions" (admins only).

Every CHANGE calls one checked function of migration 013 with the admin's
own token (reason required; never with the demo admin; logged):
    admin_set_price     the price of ONE node for 30 days (millimes)
    admin_set_setting   one setting of app_settings
"""
from typing import Literal

from fastapi import APIRouter, Depends, Query

from .. import billing
from ..auth import CurrentAdmin, get_current_admin
from ..db_errors import checked_call
from ..schemas import ActionDone, ActionsPage, BillingPage, PriceBody, SettingBody, SettingsPage
from .common import one_row

router = APIRouter(prefix="/api", tags=["settings"])

SettingName = Literal["demo_payments_enabled", "demo_login_enabled", "iot_ingest_enabled", "demo_admin_login_enabled",
                      "hectares_per_node", "iot_history_days"]


@router.get("/billing", response_model=BillingPage)
def read_billing(admin: CurrentAdmin = Depends(get_current_admin)) -> BillingPage:
    """The price, the subscriptions (with their bill), the payments."""
    with checked_call():
        return billing.billing_page(admin.db, admin.demo)


@router.post("/billing/price", response_model=ActionDone)
def set_price(body: PriceBody, admin: CurrentAdmin = Depends(get_current_admin)) -> ActionDone:
    """A new price for ONE node and one period (reason required)."""
    params = {"p_price_millimes": body.price_millimes, "p_reason": body.reason.strip()}
    with checked_call():
        row = one_row(admin.db.rpc("admin_set_price", params).execute().data)
    return ActionDone(status=str(row.get("price_millimes")))


@router.get("/settings", response_model=SettingsPage)
def read_settings(admin: CurrentAdmin = Depends(get_current_admin)) -> SettingsPage:
    with checked_call():
        return billing.settings_page(admin.db, admin.demo)


@router.post("/settings/{name}", response_model=ActionDone)
def set_setting(name: SettingName, body: SettingBody, admin: CurrentAdmin = Depends(get_current_admin)) -> ActionDone:
    """One setting (reason required): 'true' / 'false', or a number."""
    params = {"p_name": name, "p_value": body.value.strip(), "p_reason": body.reason.strip()}
    with checked_call():
        row = one_row(admin.db.rpc("admin_set_setting", params).execute().data)
    value = row.get(name)
    return ActionDone(status=None if value is None else str(value).lower())


@router.get("/actions", response_model=ActionsPage)
def read_actions(
    before: int | None = Query(default=None, ge=1),
    actions: str | None = Query(default=None, max_length=400, pattern=r"^[a-z_]+(,[a-z_]+)*$"),
    admin: CurrentAdmin = Depends(get_current_admin),
) -> ActionsPage:
    """Every admin action, newest first, 100 at a time. actions = a list of
    codes (node_accept,node_unaccept...) to keep."""
    codes = actions.split(",") if actions else None
    with checked_call():
        return billing.journal(admin.db, admin.demo, before, codes)
