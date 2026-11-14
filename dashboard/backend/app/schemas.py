"""Shapes of the data the API sends back (same columns as the database)."""
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class Profile(BaseModel):
    """One row of the "profiles" table, plus the login e-mail."""

    id: str
    role: str
    name: str
    email: str | None = None
    phone: str | None = None
    language: str | None = None
    zone: str | None = None
    farm_name: str | None = None
    speciality: str | None = None
    verified: bool | None = None
    created_at: datetime | None = None
    # The demo admin of "Connexion démo" (e-mail @looz-demo.invalid).
    demo_admin: bool = False


# ---------- Farmers and their sensor boxes (IoT, migration 012) ----------
# Codes only (levels, statuses, faults...): the dashboard writes the texts.


class Pack(BaseModel):
    """The farmer's pack. active = paid and not ended."""

    plan: str = "free"
    active: bool = False
    ends_at: datetime | None = None
    nodes: int | None = None


class BoxCounts(BaseModel):
    """How many boxes of the orchard are in each state."""

    total: int = 0
    waiting: int = 0
    installed: int = 0
    online: int = 0
    offline: int = 0
    sensor_problem: int = 0


class FarmerSummary(BaseModel):
    """One line of the farmers list."""

    id: str
    name: str
    phone: str | None = None
    governorate: str | None = None
    created_at: datetime | None = None
    pack: Pack
    orchard_status: str | None = None  # None = no orchard, 'draft', 'complete'
    zones: int = 0
    boxes: BoxCounts
    worst_level: str | None = None  # the most serious level of a box sending data
    last_received_at: datetime | None = None
    demo_time: bool = False  # a gateway of this orchard runs the simulation clock


class FarmersPage(BaseModel):
    farmers: list[FarmerSummary]
    server_time: datetime


class Point(BaseModel):
    x: float
    z: float


class FarmerInfo(BaseModel):
    id: str
    name: str
    phone: str | None = None
    governorate: str | None = None
    language: str | None = None
    created_at: datetime | None = None


class Orchard(BaseModel):
    id: str
    status: str
    area_ha: float | None = None
    outline: list[Point] = Field(default_factory=list)
    is_demo: bool = False
    completed_at: datetime | None = None


class Zone(BaseModel):
    id: str
    letter: str | None = None
    name: str = ""
    color: str | None = None
    zone_type: str | None = None
    tree_count: int | None = None
    cultivar: str | None = None
    planted_year: int | None = None
    boundary: list[Point] = Field(default_factory=list)
    tree_codes: list[str] = Field(default_factory=list)  # filled when the zone has 30 trees or fewer


class Tree(BaseModel):
    code: str
    zone_id: str | None = None
    x: float
    z: float


class Box(BaseModel):
    """A sensor box (node) with its state and its latest reading (view iot_node_status)."""

    node_id: str
    zone_id: str
    zone_letter: str | None = None
    device_code: str | None = None
    position_x: float | None = None
    position_z: float | None = None
    status: str  # waiting | installed | online | offline | sensor_problem
    installed_at: datetime | None = None
    received_at: datetime | None = None  # real time of the last reception
    measured_at: datetime | None = None  # time measured by the box (simulated in demo)
    last_refused_at: datetime | None = None
    last_refused_reason: str | None = None
    gateway_code: str | None = None
    time_mode: str | None = None
    soil_moisture_pct: float | None = None
    soil_temp_c: float | None = None
    air_temp_c: float | None = None
    humidity_pct: float | None = None
    light_par: float | None = None
    vpd_kpa: float | None = None
    battery_pct: float | None = None
    rssi_dbm: int | None = None
    water_stress: int | None = None
    heat_stress: int | None = None
    anomaly: float | None = None
    drying_rate_pct_h: float | None = None
    hours_above_35c: float | None = None
    level: str | None = None
    reasons: list[str] = Field(default_factory=list)
    cause: str | None = None
    confidence: float | None = None
    faults: list[str] = Field(default_factory=list)
    packets_lost: int | None = None
    firmware: str | None = None


class Gateway(BaseModel):
    """The farm's gateway (Node-RED). Its key hash is never sent."""

    code: str
    time_mode: str
    enabled: bool
    last_seen_at: datetime | None = None
    last_result: dict[str, Any] | None = None
    history_minutes: int
    offline_after_minutes: int


class Visit(BaseModel):
    """The installation visit of the boxes (table kit_requests)."""

    id: str | None = None
    status: str
    nodes: int | None = None
    admin_note: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    installed_at: datetime | None = None


class FarmerDetail(BaseModel):
    farmer: FarmerInfo
    pack: Pack
    orchard: Orchard | None = None
    zones: list[Zone] = Field(default_factory=list)
    trees: list[Tree] = Field(default_factory=list)
    boxes: list[Box] = Field(default_factory=list)
    gateways: list[Gateway] = Field(default_factory=list)
    visit: Visit | None = None
    server_time: datetime


# ---------- The admin action log (migration 013) ----------


class ActionLine(BaseModel):
    """One line of admin_actions: who did what, when, on what, why."""

    id: int
    created_at: datetime
    admin_name: str
    action: str  # code: node_accept, node_unaccept, gateway_new_key...
    target_type: str
    target_id: str | None = None
    target_label: str | None = None
    reason: str | None = None
    details: dict[str, Any] = Field(default_factory=dict)
    is_demo: bool = False


# ---------- The 3 days of a farmer: charts, alerts, sensor problems ----------


class SeriesPoint(BaseModel):
    t: datetime  # measured_at (simulated time in demo mode)
    soil: float | None = None  # soil moisture %
    air: float | None = None  # air temperature, degrees C
    water: int | None = None  # water stress 0-100
    heat: int | None = None  # heat stress 0-100
    battery: float | None = None  # %
    level: str | None = None


class BoxSeries(BaseModel):
    node_id: str
    device_code: str | None = None
    zone_letter: str | None = None
    points: list[SeriesPoint] = Field(default_factory=list)


class AlertEvent(BaseModel):
    """A change of level of a box (view iot_alert_log)."""

    id: int
    node_id: str
    device_code: str | None = None
    zone_letter: str | None = None
    measured_at: datetime
    received_at: datetime | None = None
    level: str
    previous_level: str | None = None
    reasons: list[str] = Field(default_factory=list)
    cause: str | None = None
    confidence: float | None = None
    water_stress: int | None = None
    heat_stress: int | None = None
    soil_moisture_pct: float | None = None
    air_temp_c: float | None = None
    faults: list[str] = Field(default_factory=list)


class FaultLine(BaseModel):
    """A sensor problem of a box over the last days (node_fault_days)."""

    node_id: str
    device_code: str | None = None
    zone_letter: str | None = None
    code: str
    days: int
    count: int
    first_at: datetime
    last_at: datetime


class FarmerHistory(BaseModel):
    # The 3 days shown end at the latest measure of the orchard (in demo
    # mode the simulated clock runs ahead of the real one).
    window_start: datetime | None = None
    window_end: datetime | None = None
    time_mode: str | None = None
    series: list[BoxSeries] = Field(default_factory=list)
    alerts: list[AlertEvent] = Field(default_factory=list)
    faults: list[FaultLine] = Field(default_factory=list)
    actions: list[ActionLine] = Field(default_factory=list)
    server_time: datetime


# ---------- "Vue d'ensemble" (admin_overview() of migration 013) ----------


class OverviewFarmers(BaseModel):
    total: int = 0
    paid: int = 0
    demo: int = 0


class OverviewExperts(BaseModel):
    verified: int = 0
    waiting: int = 0


class OverviewOrchards(BaseModel):
    complete: int = 0
    draft: int = 0


class OverviewBoxes(BoxCounts):
    critical: int = 0


class OverviewAlerts(BaseModel):
    active: int = 0
    danger: int = 0


class OverviewCommunity(BaseModel):
    posts_week: int = 0
    answers_week: int = 0
    hidden: int = 0
    reports_open: int = 0


class OverviewPayments(BaseModel):
    count: int = 0
    millimes: int = 0


class TodoExpert(BaseModel):
    id: str
    name: str | None = None
    governorate: str | None = None
    created_at: datetime | None = None


class TodoBox(BaseModel):
    node_id: str
    device_code: str | None = None
    zone_letter: str | None = None
    farmer_id: str | None = None
    farmer_name: str | None = None
    refused_at: datetime | None = None
    faults: list[str] = Field(default_factory=list)
    level: str | None = None


class TodoReport(BaseModel):
    id: str
    post_id: str | None = None
    comment_id: str | None = None
    reason: str
    created_at: datetime | None = None


class OverviewTodo(BaseModel):
    experts: list[TodoExpert] = Field(default_factory=list)
    boxes_waiting: list[TodoBox] = Field(default_factory=list)
    sensor_problems: list[TodoBox] = Field(default_factory=list)
    reports: list[TodoReport] = Field(default_factory=list)


class Overview(BaseModel):
    farmers: OverviewFarmers = Field(default_factory=OverviewFarmers)
    experts: OverviewExperts = Field(default_factory=OverviewExperts)
    orchards: OverviewOrchards = Field(default_factory=OverviewOrchards)
    boxes: OverviewBoxes = Field(default_factory=OverviewBoxes)
    regional_alerts: OverviewAlerts = Field(default_factory=OverviewAlerts)
    community: OverviewCommunity = Field(default_factory=OverviewCommunity)
    demo_payments_month: OverviewPayments = Field(default_factory=OverviewPayments)
    visits_open: int = 0
    todo: OverviewTodo = Field(default_factory=OverviewTodo)
    server_time: datetime


# ---------- "Capteurs": every box, installation visit and gateway ----------


class SensorBox(BaseModel):
    node_id: str
    zone_letter: str | None = None
    device_code: str | None = None
    status: str
    level: str | None = None
    faults: list[str] = Field(default_factory=list)
    installed_at: datetime | None = None
    received_at: datetime | None = None
    measured_at: datetime | None = None
    last_refused_at: datetime | None = None
    last_refused_reason: str | None = None
    battery_pct: float | None = None
    rssi_dbm: int | None = None
    gateway_code: str | None = None
    time_mode: str | None = None
    orchard_id: str
    farmer_id: str
    farmer_name: str = ""
    farmer_phone: str | None = None
    governorate: str | None = None
    demo: bool = False


class VisitRow(BaseModel):
    id: str
    user_id: str
    farmer_name: str = ""
    phone: str | None = None
    governorate: str | None = None
    status: str
    nodes: int | None = None
    almond_trees: int | None = None
    orchard_area_ha: float | None = None
    admin_note: str | None = None
    orchard_id: str | None = None
    boxes_total: int = 0
    boxes_accepted: int = 0
    created_at: datetime | None = None
    updated_at: datetime | None = None
    installed_at: datetime | None = None
    demo: bool = False


class GatewayRow(Gateway):
    orchard_id: str
    farmer_id: str | None = None
    farmer_name: str = ""
    created_at: datetime | None = None
    demo: bool = False


class SensorsPage(BaseModel):
    boxes: list[SensorBox] = Field(default_factory=list)
    visits: list[VisitRow] = Field(default_factory=list)
    gateways: list[GatewayRow] = Field(default_factory=list)
    actions: list[ActionLine] = Field(default_factory=list)
    server_time: datetime


# ---------- What the admin sends for an action ----------


class AcceptBody(BaseModel):
    device_code: str | None = Field(default=None, max_length=40)
    reason: str | None = Field(default=None, max_length=300)


class ReasonBody(BaseModel):
    reason: str = Field(max_length=300)


class GatewayEnabledBody(BaseModel):
    enabled: bool
    reason: str = Field(max_length=300)


class VisitBody(BaseModel):
    status: str | None = Field(default=None, max_length=20)
    note: str | None = Field(default=None, max_length=500)


class ActionDone(BaseModel):
    """The answer of an action: what the database says now."""

    ok: bool = True
    installed_at: datetime | None = None
    device_code: str | None = None
    enabled: bool | None = None
    status: str | None = None


class NewKey(BaseModel):
    """A new gateway key: shown ONCE, never kept by the API."""

    code: str
    key: str


# ---------- "Connexion démo" ----------


class DemoLoginStatus(BaseModel):
    enabled: bool


class DemoSession(BaseModel):
    """The session of the demo admin (the password never leaves the API)."""

    access_token: str
    refresh_token: str
    expires_in: int | None = None
    expires_at: int | None = None


# ---------- "Utilisateurs" (Phase B) ----------


class UserRow(BaseModel):
    """One account (farmer, expert or admin). The e-mail: admins only."""

    id: str
    name: str = ""
    role: str
    phone: str | None = None
    email: str | None = None
    governorate: str | None = None
    language: str | None = None
    created_at: datetime | None = None
    last_sign_in_at: datetime | None = None
    blocked: bool = False
    verified: bool = False  # experts: the badge "◆ خبير موثّق"
    speciality: str | None = None
    organisation: str | None = None
    pack: Pack = Field(default_factory=Pack)
    orchard_status: str | None = None
    posts: int = 0
    answers: int = 0
    demo: bool = False  # a demo account or a fake person of the community
    fake: bool = False  # a fake person of the community (cannot log in)
    demo_login: bool = False  # made with the demo login (any number, any code)


class UsersPage(BaseModel):
    users: list[UserRow] = Field(default_factory=list)
    server_time: datetime


class VerifiedBody(BaseModel):
    verified: bool
    reason: str | None = Field(default=None, max_length=300)


class BlockedBody(BaseModel):
    blocked: bool
    reason: str = Field(max_length=300)


# ---------- "Communauté" (Phase B) ----------


class Author(BaseModel):
    id: str | None = None
    name: str = ""
    role: str | None = None
    verified: bool = False
    governorate: str | None = None
    demo: bool = False
    fake: bool = False


class PostRow(BaseModel):
    id: str
    type: str  # question / tip
    text: str
    photo_kind: str | None = None  # "demo" (picture of the app) or "storage" (a farmer's photo)
    photo_demo: str | None = None  # the name of the demo picture (almond_blossoms)
    hidden: bool = False
    created_at: datetime
    updated_at: datetime | None = None
    author: Author = Field(default_factory=Author)
    answers: int = 0
    answers_hidden: int = 0
    reports_open: int = 0
    demo: bool = False


class CommentRow(BaseModel):
    id: str
    post_id: str
    text: str
    hidden: bool = False
    created_at: datetime
    author: Author = Field(default_factory=Author)
    reports_open: int = 0
    demo: bool = False


class ReportRow(BaseModel):
    id: str
    post_id: str | None = None
    comment_id: str | None = None
    reason: str  # spam / insult / wrong_advice / other
    note: str | None = None
    status: str  # open / dismissed / actioned
    created_at: datetime
    resolved_at: datetime | None = None
    reporter_name: str = ""
    target_text: str = ""
    target_post_id: str | None = None
    demo: bool = False


class CommunityPage(BaseModel):
    posts: list[PostRow] = Field(default_factory=list)
    reports: list[ReportRow] = Field(default_factory=list)
    actions: list[ActionLine] = Field(default_factory=list)
    server_time: datetime


class PostDetail(BaseModel):
    post: PostRow
    photo_url: str | None = None  # a farmer's photo: a link valid 5 minutes
    answers: list[CommentRow] = Field(default_factory=list)
    reports: list[ReportRow] = Field(default_factory=list)
    actions: list[ActionLine] = Field(default_factory=list)
    server_time: datetime


class UserDetail(BaseModel):
    user: UserRow
    posts: list[PostRow] = Field(default_factory=list)
    answers: list[CommentRow] = Field(default_factory=list)
    actions: list[ActionLine] = Field(default_factory=list)
    server_time: datetime


class ModerateBody(BaseModel):
    action: str = Field(pattern=r"^(hide|unhide|delete)$")
    reason: str = Field(max_length=300)


class ModerationDone(BaseModel):
    ok: bool = True
    hidden: bool | None = None
    deleted: bool = False
    photo_removed: bool | None = None  # a deleted post's photo: removed from Storage?


# ---------- "Alertes" (Phase C) ----------


class RegionalAlert(BaseModel):
    """A regional alert (migration 013), in Arabic AND French."""

    id: str
    kind: str  # frost / heat / drought / disease / pest / wind / rain
    severity: str  # info / warning / danger
    governorates: list[str] = Field(default_factory=list)
    title_ar: str
    title_fr: str
    body_ar: str
    body_fr: str
    advice_ar: str | None = None
    advice_fr: str | None = None
    starts_at: datetime
    ends_at: datetime | None = None
    ended_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    created_by_name: str = ""
    ended_by_name: str = ""
    status: str  # scheduled / active / expired / ended
    seen_count: int = 0  # "Moi aussi" of the farmers
    opened_count: int = 0  # farmers who opened it in the app (migration 015)
    done_count: int = 0  # farmers who tapped "Fait" (migration 015)
    is_demo: bool = False


class RegionalAlertsPage(BaseModel):
    alerts: list[RegionalAlert] = Field(default_factory=list)
    actions: list[ActionLine] = Field(default_factory=list)
    server_time: datetime


class RegionalAlertDetail(BaseModel):
    alert: RegionalAlert
    actions: list[ActionLine] = Field(default_factory=list)
    server_time: datetime


class AlertBody(BaseModel):
    """Create or change a regional alert. governorates: codes, or ["all"]."""

    kind: str = Field(max_length=20)
    severity: str = Field(max_length=20)
    governorates: list[str] = Field(min_length=1, max_length=24)
    title_ar: str = Field(max_length=200)
    title_fr: str = Field(max_length=200)
    body_ar: str = Field(max_length=1200)
    body_fr: str = Field(max_length=1200)
    advice_ar: str | None = Field(default=None, max_length=800)
    advice_fr: str | None = Field(default=None, max_length=800)
    starts_at: str | None = Field(default=None, max_length=40)  # None = now (a new alert) / unchanged
    ends_at: str | None = Field(default=None, max_length=40)  # None = until an admin ends it


class SensorAlertRow(AlertEvent):
    orchard_id: str
    farmer_id: str | None = None
    farmer_name: str = ""
    governorate: str | None = None
    demo: bool = False


class FarmerChoice(BaseModel):
    id: str
    name: str


class SensorAlertsPage(BaseModel):
    events: list[SensorAlertRow] = Field(default_factory=list)
    farmers: list[FarmerChoice] = Field(default_factory=list)  # for the filter
    limit: int = 0  # at most this many lines (the newest)
    server_time: datetime


# ---------- "Vergers" (Phase D, read only) ----------


class OrchardRow(BaseModel):
    id: str
    farmer_id: str
    farmer_name: str = ""
    farmer_phone: str | None = None
    governorate: str | None = None
    status: str  # draft / complete
    draw_mode: str | None = None
    area_ha: float | None = None
    zones: int = 0
    trees: int = 0
    boxes: int = 0
    boxes_accepted: int = 0
    pack: Pack = Field(default_factory=Pack)
    created_at: datetime | None = None
    completed_at: datetime | None = None
    demo: bool = False


class OrchardsPage(BaseModel):
    orchards: list[OrchardRow] = Field(default_factory=list)
    server_time: datetime


class OrchardDetail(BaseModel):
    """One orchard: its line, and the plan (zones, trees, boxes). A draft:
    the zones of its drawing (design), not yet built."""

    orchard: OrchardRow
    outline: list[Point] = Field(default_factory=list)
    zones: list[Zone] = Field(default_factory=list)
    trees: list[Tree] = Field(default_factory=list)
    boxes: list[Box] = Field(default_factory=list)
    draft_zones: int = 0  # zones of the drawing not built yet
    bill: "Bill | None" = None
    server_time: datetime


# ---------- "Abonnements" (Phase D) ----------


class Price(BaseModel):
    price_millimes: int  # one node for period_days days (8000 = 8 DT)
    period_days: int = 30
    per_node: bool = True
    updated_at: datetime | None = None


class Bill(BaseModel):
    """What the farmer pays for one period at the current price (same rule
    as orchard_quote_for() of migration 011)."""

    billed_nodes: int
    min_nodes_by_area: int = 0
    price_millimes: int
    period_days: int
    amount_millimes: int


class SubscriptionRow(BaseModel):
    user_id: str
    farmer_name: str = ""
    farmer_phone: str | None = None
    governorate: str | None = None
    plan: str = "free"
    status: str | None = None
    active: bool = False
    nodes: int | None = None  # nodes paid
    started_at: datetime | None = None
    ends_at: datetime | None = None
    orchard_status: str | None = None
    bill: Bill | None = None
    demo: bool = False


class PaymentRow(BaseModel):
    id: str
    user_id: str | None = None  # None: the account was deleted
    farmer_name: str = ""
    plan: str
    amount_millimes: int
    nodes: int | None = None
    period_days: int | None = None
    kind: str | None = None  # period / extra_nodes
    provider: str | None = None  # demo / ...
    status: str  # paid_demo / failed_demo / pending / paid / failed / expired
    created_at: datetime | None = None
    paid_at: datetime | None = None
    demo: bool = False


class BillingPage(BaseModel):
    price: Price
    hectares_per_node: float | None = None
    subscriptions: list[SubscriptionRow] = Field(default_factory=list)
    payments: list[PaymentRow] = Field(default_factory=list)
    actions: list[ActionLine] = Field(default_factory=list)
    server_time: datetime


class PriceBody(BaseModel):
    price_millimes: int = Field(ge=1, le=10_000_000)
    reason: str = Field(max_length=300)


# ---------- "Réglages" and "Journal des actions" (Phase D) ----------


class Settings(BaseModel):
    demo_payments_enabled: bool
    demo_login_enabled: bool
    iot_ingest_enabled: bool
    demo_admin_login_enabled: bool
    hectares_per_node: float | None = None
    iot_history_days: int
    updated_at: datetime | None = None


class SettingsPage(BaseModel):
    settings: Settings
    actions: list[ActionLine] = Field(default_factory=list)
    server_time: datetime


class SettingBody(BaseModel):
    value: str = Field(max_length=20)  # 'true' / 'false', a number, or '' (hectares_per_node)
    reason: str = Field(max_length=300)


class ActionsPage(BaseModel):
    actions: list[ActionLine] = Field(default_factory=list)
    more: bool = False  # older lines exist (ask again with before=<the last id>)
    server_time: datetime


OrchardDetail.model_rebuild()
