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
