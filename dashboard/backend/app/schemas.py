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
