// Shapes of the data sent by the backend (same as backend/app/schemas.py).

export type Role = "farmer" | "expert" | "admin";

export type Profile = {
  id: string;
  role: Role;
  name: string;
  email: string | null;
  phone: string | null;
  language: string | null;
  zone: string | null;
  farm_name: string | null;
  speciality: string | null;
  verified: boolean | null;
  created_at: string | null;
  /** The demo admin of "Connexion démo": demo accounts only. */
  demo_admin: boolean;
};

// ---------- Farmers and their sensor boxes (backend/app/schemas.py) ----------
// The values are CODES (statuses, levels, faults): lib/labels.ts gives the texts.

export type Pack = {
  plan: string;
  active: boolean;
  ends_at: string | null;
  nodes: number | null;
};

export type BoxStatus = "waiting" | "installed" | "online" | "offline" | "sensor_problem";

export type BoxCounts = Record<BoxStatus, number> & { total: number };

export type FarmerSummary = {
  id: string;
  name: string;
  phone: string | null;
  governorate: string | null;
  created_at: string | null;
  pack: Pack;
  orchard_status: string | null;
  zones: number;
  boxes: BoxCounts;
  worst_level: string | null;
  last_received_at: string | null;
  demo_time: boolean;
};

export type FarmersPage = { farmers: FarmerSummary[]; server_time: string };

export type Point = { x: number; z: number };

export type Zone = {
  id: string;
  letter: string | null;
  name: string;
  color: string | null;
  zone_type: string | null;
  tree_count: number | null;
  cultivar: string | null;
  planted_year: number | null;
  boundary: Point[];
  tree_codes: string[];
};

export type Tree = { code: string; zone_id: string | null; x: number; z: number };

export type Box = {
  node_id: string;
  zone_id: string;
  zone_letter: string | null;
  device_code: string | null;
  position_x: number | null;
  position_z: number | null;
  status: BoxStatus;
  installed_at: string | null;
  received_at: string | null;
  measured_at: string | null;
  last_refused_at: string | null;
  last_refused_reason: string | null;
  gateway_code: string | null;
  time_mode: string | null;
  soil_moisture_pct: number | null;
  soil_temp_c: number | null;
  air_temp_c: number | null;
  humidity_pct: number | null;
  light_par: number | null;
  vpd_kpa: number | null;
  battery_pct: number | null;
  rssi_dbm: number | null;
  water_stress: number | null;
  heat_stress: number | null;
  anomaly: number | null;
  drying_rate_pct_h: number | null;
  hours_above_35c: number | null;
  level: string | null;
  reasons: string[];
  cause: string | null;
  confidence: number | null;
  faults: string[];
  packets_lost: number | null;
  firmware: string | null;
};

export type Gateway = {
  code: string;
  time_mode: string;
  enabled: boolean;
  last_seen_at: string | null;
  last_result: {
    accepted?: number;
    old?: number;
    refused?: Record<string, number>;
    refused_devices?: Record<string, string>;
  } | null;
  history_minutes: number;
  offline_after_minutes: number;
};

export type FarmerDetail = {
  farmer: {
    id: string;
    name: string;
    phone: string | null;
    governorate: string | null;
    language: string | null;
    created_at: string | null;
  };
  pack: Pack;
  orchard: {
    id: string;
    status: string;
    area_ha: number | null;
    outline: Point[];
    is_demo: boolean;
    completed_at: string | null;
  } | null;
  zones: Zone[];
  trees: Tree[];
  boxes: Box[];
  gateways: Gateway[];
  visit: {
    id: string | null;
    status: string;
    nodes: number | null;
    admin_note: string | null;
    created_at: string | null;
    updated_at: string | null;
    installed_at: string | null;
  } | null;
  server_time: string;
};

// ---------- The admin action log (migration 013) ----------

export type ActionLine = {
  id: number;
  created_at: string;
  admin_name: string;
  action: string;
  target_type: string;
  target_id: string | null;
  target_label: string | null;
  reason: string | null;
  details: Record<string, unknown>;
  is_demo: boolean;
};

// ---------- The 3 days of a farmer ----------

export type SeriesPoint = {
  t: string;
  soil: number | null;
  air: number | null;
  water: number | null;
  heat: number | null;
  battery: number | null;
  level: string | null;
};

export type BoxSeries = {
  node_id: string;
  device_code: string | null;
  zone_letter: string | null;
  points: SeriesPoint[];
};

export type AlertEvent = {
  id: number;
  node_id: string;
  device_code: string | null;
  zone_letter: string | null;
  measured_at: string;
  received_at: string | null;
  level: string;
  previous_level: string | null;
  reasons: string[];
  cause: string | null;
  confidence: number | null;
  water_stress: number | null;
  heat_stress: number | null;
  soil_moisture_pct: number | null;
  air_temp_c: number | null;
  faults: string[];
};

export type FaultLine = {
  node_id: string;
  device_code: string | null;
  zone_letter: string | null;
  code: string;
  days: number;
  count: number;
  first_at: string;
  last_at: string;
};

export type FarmerHistory = {
  window_start: string | null;
  window_end: string | null;
  time_mode: string | null;
  series: BoxSeries[];
  alerts: AlertEvent[];
  faults: FaultLine[];
  actions: ActionLine[];
  server_time: string;
};

// ---------- Vue d'ensemble ----------

export type TodoBox = {
  node_id: string;
  device_code: string | null;
  zone_letter: string | null;
  farmer_id: string | null;
  farmer_name: string | null;
  refused_at: string | null;
  faults: string[];
  level: string | null;
};

export type Overview = {
  farmers: { total: number; paid: number; demo: number };
  experts: { verified: number; waiting: number };
  orchards: { complete: number; draft: number };
  boxes: BoxCounts & { critical: number };
  regional_alerts: { active: number; danger: number };
  community: { posts_week: number; answers_week: number; hidden: number; reports_open: number };
  demo_payments_month: { count: number; millimes: number };
  visits_open: number;
  todo: {
    experts: { id: string; name: string | null; governorate: string | null; created_at: string | null }[];
    boxes_waiting: TodoBox[];
    sensor_problems: TodoBox[];
    reports: { id: string; post_id: string | null; comment_id: string | null; reason: string; created_at: string | null }[];
  };
  server_time: string;
};

// ---------- Capteurs ----------

export type SensorBox = {
  node_id: string;
  zone_letter: string | null;
  device_code: string | null;
  status: BoxStatus;
  level: string | null;
  faults: string[];
  installed_at: string | null;
  received_at: string | null;
  measured_at: string | null;
  last_refused_at: string | null;
  last_refused_reason: string | null;
  battery_pct: number | null;
  rssi_dbm: number | null;
  gateway_code: string | null;
  time_mode: string | null;
  orchard_id: string;
  farmer_id: string;
  farmer_name: string;
  farmer_phone: string | null;
  governorate: string | null;
  demo: boolean;
};

export type VisitRow = {
  id: string;
  user_id: string;
  farmer_name: string;
  phone: string | null;
  governorate: string | null;
  status: string;
  nodes: number | null;
  almond_trees: number | null;
  orchard_area_ha: number | null;
  admin_note: string | null;
  orchard_id: string | null;
  boxes_total: number;
  boxes_accepted: number;
  created_at: string | null;
  updated_at: string | null;
  installed_at: string | null;
  demo: boolean;
};

export type GatewayRow = Gateway & {
  orchard_id: string;
  farmer_id: string | null;
  farmer_name: string;
  created_at: string | null;
  demo: boolean;
};

export type SensorsPage = {
  boxes: SensorBox[];
  visits: VisitRow[];
  gateways: GatewayRow[];
  actions: ActionLine[];
  server_time: string;
};

export type ActionDone = {
  ok: boolean;
  installed_at: string | null;
  device_code: string | null;
  enabled: boolean | null;
  status: string | null;
};

export type NewKey = { code: string; key: string };

export type DemoSession = {
  access_token: string;
  refresh_token: string;
  expires_in: number | null;
  expires_at: number | null;
};

// ---------- "Utilisateurs" (Phase B) ----------

export type UserRow = {
  id: string;
  name: string;
  role: "farmer" | "expert" | "admin" | string;
  phone: string | null;
  /** Admins only. */
  email: string | null;
  governorate: string | null;
  language: string | null;
  created_at: string | null;
  last_sign_in_at: string | null;
  blocked: boolean;
  /** Experts: the badge "◆ خبير موثّق". */
  verified: boolean;
  speciality: string | null;
  organisation: string | null;
  pack: Pack;
  orchard_status: string | null;
  posts: number;
  answers: number;
  /** A demo account, or a fake person of the community. */
  demo: boolean;
  /** A fake person of the community (cannot log in). */
  fake: boolean;
  /** Made with the demo login (any number, any code). */
  demo_login: boolean;
};

export type UsersPage = { users: UserRow[]; server_time: string };

export type UserDetail = {
  user: UserRow;
  posts: PostRow[];
  answers: CommentRow[];
  actions: ActionLine[];
  server_time: string;
};

// ---------- "Communauté" (Phase B) ----------

export type Author = {
  id: string | null;
  name: string;
  role: string | null;
  verified: boolean;
  governorate: string | null;
  demo: boolean;
  fake: boolean;
};

export type PostRow = {
  id: string;
  type: "question" | "tip" | string;
  text: string;
  /** "demo" = a picture shipped in the app, "storage" = a farmer's photo. */
  photo_kind: "demo" | "storage" | null;
  photo_demo: string | null;
  hidden: boolean;
  created_at: string;
  updated_at: string | null;
  author: Author;
  answers: number;
  answers_hidden: number;
  reports_open: number;
  demo: boolean;
};

export type CommentRow = {
  id: string;
  post_id: string;
  text: string;
  hidden: boolean;
  created_at: string;
  author: Author;
  reports_open: number;
  demo: boolean;
};

export type ReportRow = {
  id: string;
  post_id: string | null;
  comment_id: string | null;
  reason: string;
  note: string | null;
  status: "open" | "dismissed" | "actioned" | string;
  created_at: string;
  resolved_at: string | null;
  reporter_name: string;
  target_text: string;
  target_post_id: string | null;
  demo: boolean;
};

export type CommunityPage = {
  posts: PostRow[];
  reports: ReportRow[];
  actions: ActionLine[];
  server_time: string;
};

export type PostDetail = {
  post: PostRow;
  /** A farmer's photo: a link valid 5 minutes. */
  photo_url: string | null;
  answers: CommentRow[];
  reports: ReportRow[];
  actions: ActionLine[];
  server_time: string;
};

export type ModerationDone = {
  ok: boolean;
  hidden: boolean | null;
  deleted: boolean;
  /** A deleted post's photo: removed from Storage? (null = it had none) */
  photo_removed: boolean | null;
};

// ---------- "Alertes" (Phase C) ----------

export type RegionalAlert = {
  id: string;
  kind: string;
  severity: "info" | "warning" | "danger" | string;
  governorates: string[];
  title_ar: string;
  title_fr: string;
  body_ar: string;
  body_fr: string;
  advice_ar: string | null;
  advice_fr: string | null;
  starts_at: string;
  ends_at: string | null;
  ended_at: string | null;
  created_at: string | null;
  updated_at: string | null;
  created_by_name: string;
  ended_by_name: string;
  status: "scheduled" | "active" | "expired" | "ended" | string;
  /** "Moi aussi" of the farmers. */
  seen_count: number;
  is_demo: boolean;
};

export type RegionalAlertsPage = { alerts: RegionalAlert[]; actions: ActionLine[]; server_time: string };

export type RegionalAlertDetail = { alert: RegionalAlert; actions: ActionLine[]; server_time: string };

/** What the editor sends. governorates: codes, or ["all"]. */
export type AlertInput = {
  kind: string;
  severity: string;
  governorates: string[];
  title_ar: string;
  title_fr: string;
  body_ar: string;
  body_fr: string;
  advice_ar: string | null;
  advice_fr: string | null;
  starts_at: string | null;
  ends_at: string | null;
};

export type SensorAlertRow = AlertEvent & {
  orchard_id: string;
  farmer_id: string | null;
  farmer_name: string;
  governorate: string | null;
  demo: boolean;
};

export type SensorAlertsPage = {
  events: SensorAlertRow[];
  farmers: { id: string; name: string }[];
  limit: number;
  server_time: string;
};

// ---------- "Vergers", "Abonnements", "Réglages", "Journal" (Phase D) ----------

export type OrchardRow = {
  id: string;
  farmer_id: string;
  farmer_name: string;
  farmer_phone: string | null;
  governorate: string | null;
  status: "draft" | "complete" | string;
  draw_mode: string | null;
  area_ha: number | null;
  zones: number;
  trees: number;
  boxes: number;
  boxes_accepted: number;
  pack: Pack;
  created_at: string | null;
  completed_at: string | null;
  demo: boolean;
};

export type OrchardsPage = { orchards: OrchardRow[]; server_time: string };

/** What the farmer pays for one period at the current price. */
export type Bill = {
  billed_nodes: number;
  min_nodes_by_area: number;
  price_millimes: number;
  period_days: number;
  amount_millimes: number;
};

export type OrchardDetail = {
  orchard: OrchardRow;
  outline: Point[];
  zones: Zone[];
  trees: Tree[];
  boxes: Box[];
  /** A draft: the zones of its drawing, not built yet. */
  draft_zones: number;
  bill: Bill | null;
  server_time: string;
};

export type Price = { price_millimes: number; period_days: number; per_node: boolean; updated_at: string | null };

export type SubscriptionRow = {
  user_id: string;
  farmer_name: string;
  farmer_phone: string | null;
  governorate: string | null;
  plan: string;
  status: string | null;
  active: boolean;
  nodes: number | null;
  started_at: string | null;
  ends_at: string | null;
  orchard_status: string | null;
  bill: Bill | null;
  demo: boolean;
};

export type PaymentRow = {
  id: string;
  user_id: string | null;
  farmer_name: string;
  plan: string;
  amount_millimes: number;
  nodes: number | null;
  period_days: number | null;
  kind: string | null;
  provider: string | null;
  status: string;
  created_at: string | null;
  paid_at: string | null;
  demo: boolean;
};

export type BillingPage = {
  price: Price;
  hectares_per_node: number | null;
  subscriptions: SubscriptionRow[];
  payments: PaymentRow[];
  actions: ActionLine[];
  server_time: string;
};

export type Settings = {
  demo_payments_enabled: boolean;
  demo_login_enabled: boolean;
  iot_ingest_enabled: boolean;
  demo_admin_login_enabled: boolean;
  hectares_per_node: number | null;
  iot_history_days: number;
  updated_at: string | null;
};

export type SettingsPage = { settings: Settings; actions: ActionLine[]; server_time: string };

export type ActionsPage = { actions: ActionLine[]; more: boolean; server_time: string };
