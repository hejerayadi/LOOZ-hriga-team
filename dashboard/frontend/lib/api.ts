// The ONLY place that calls our backend. Pages use these functions,
// never fetch() directly.
//
// Every request gets the header "Authorization: Bearer <token>", where the
// token comes from the Supabase login. The backend checks it.
import { ACTION_ERROR } from "./labels";
import { supabase } from "./supabase";
import type {
  ActionDone,
  ActionsPage,
  AlertInput,
  BillingPage,
  CommunityPage,
  DemoSession,
  FarmerDetail,
  FarmerHistory,
  FarmersPage,
  ModerationDone,
  NewKey,
  OrchardDetail,
  OrchardsPage,
  Overview,
  PostDetail,
  Profile,
  RegionalAlert,
  RegionalAlertDetail,
  RegionalAlertsPage,
  SensorAlertsPage,
  SensorsPage,
  SettingsPage,
  UserDetail,
  UsersPage,
} from "./types";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000";

/**
 * An error from the backend. `status` = HTTP code (0 = server unreachable).
 * `code` = why the database refused an action (see ACTION_ERROR).
 */
export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public code: string | null = null,
  ) {
    super(message);
  }
}

/** true when the backend refused the user (not logged in, or not an admin). */
export function isAccessDenied(error: unknown): boolean {
  return error instanceof ApiError && (error.status === 401 || error.status === 403) && !error.code;
}

/** The message to show for an error (always in French). */
export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.code && ACTION_ERROR[error.code]) return ACTION_ERROR[error.code];
    if (error.status === 0) return "Impossible de joindre le serveur de l'API. Le backend est-il lancé ?";
    if (error.status === 401) return "Session expirée : reconnectez-vous.";
    if (error.status === 403) return "Accès réservé aux administrateurs.";
    if (error.status === 404) return "Introuvable.";
    if (error.status === 422) return "Valeur refusée : vérifiez le formulaire.";
    if (error.status === 503) return "Supabase ne répond pas. Réessayez dans un instant.";
    return `Erreur du serveur (code ${error.status}).`;
  }
  return "Erreur inattendue.";
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  // The current token (Supabase renews it automatically when it expires).
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;

  const headers = new Headers(options.headers);
  if (token) headers.set("Authorization", `Bearer ${token}`);
  if (options.body) headers.set("Content-Type", "application/json");

  let response: Response;
  try {
    response = await fetch(`${API_URL}${path}`, { cache: "no-store", ...options, headers });
  } catch {
    throw new ApiError(0, "unreachable");
  }

  if (!response.ok) {
    // FastAPI sends errors as { "detail": "..." } or, for a refused action,
    // { "detail": { "code": "reason", "message": "..." } } (in English).
    const body = await response.json().catch(() => null);
    const detail = body?.detail;
    if (detail && typeof detail === "object" && "code" in detail) {
      throw new ApiError(response.status, String(detail.message ?? ""), String(detail.code));
    }
    throw new ApiError(response.status, typeof detail === "string" ? detail : response.statusText);
  }
  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

/** Generic helpers, for the next pages. */
export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "POST", body: body === undefined ? undefined : JSON.stringify(body) }),
  patch: <T>(path: string, body: unknown) =>
    request<T>(path, { method: "PATCH", body: JSON.stringify(body) }),
  delete: <T>(path: string) => request<T>(path, { method: "DELETE" }),
};

const id = (value: string) => encodeURIComponent(value);

/** The logged-in admin's profile. Fails with 401/403 if not an admin. */
export function getMe(): Promise<Profile> {
  return api.get<Profile>("/api/me");
}

// ---------- "Connexion démo" ----------

/** Show the "Connexion démo" button? (switch on in Supabase and password in backend/.env) */
export async function demoLoginEnabled(): Promise<boolean> {
  try {
    const r = await fetch(`${API_URL}/api/demo-login`, { cache: "no-store" });
    return r.ok && (await r.json()).enabled === true;
  } catch {
    return false;
  }
}

/** The backend logs the demo admin in; the browser gets only the session. */
export function demoLogin(): Promise<DemoSession> {
  return api.post<DemoSession>("/api/demo-login");
}

// ---------- Reading ----------

export function getOverview(): Promise<Overview> {
  return api.get<Overview>("/api/overview");
}

/** Every farmer with his pack, orchard and boxes. q = part of a name or a number. */
export function getFarmers(q = ""): Promise<FarmersPage> {
  const query = q.trim() ? `?q=${encodeURIComponent(q.trim())}` : "";
  return api.get<FarmersPage>(`/api/farmers${query}`);
}

/** One farmer: pack, orchard, zones, trees, boxes, gateway, visit. */
export function getFarmer(farmerId: string): Promise<FarmerDetail> {
  return api.get<FarmerDetail>(`/api/farmers/${id(farmerId)}`);
}

/** The 3 days of a farmer: charts, alert log, sensor problems, admin actions. */
export function getFarmerHistory(farmerId: string): Promise<FarmerHistory> {
  return api.get<FarmerHistory>(`/api/farmers/${id(farmerId)}/history`);
}

/** Every box, installation visit and gateway. */
export function getSensors(): Promise<SensorsPage> {
  return api.get<SensorsPage>("/api/sensors");
}

// ---------- Actions (each one: a checked database function + a log line) ----------

export function acceptNode(nodeId: string, deviceCode: string, reason: string): Promise<ActionDone> {
  return api.post<ActionDone>(`/api/nodes/${id(nodeId)}/accept`, { device_code: deviceCode, reason });
}

export function unacceptNode(nodeId: string, reason: string): Promise<ActionDone> {
  return api.post<ActionDone>(`/api/nodes/${id(nodeId)}/unaccept`, { reason });
}

/** A NEW key for a gateway (the old one stops at once). Shown once. */
export function newGatewayKey(code: string): Promise<NewKey> {
  return api.post<NewKey>(`/api/gateways/${id(code)}/new-key`);
}

export function setGatewayEnabled(code: string, enabled: boolean, reason: string): Promise<ActionDone> {
  return api.post<ActionDone>(`/api/gateways/${id(code)}/enabled`, { enabled, reason });
}

/** status: new / contacted / cancelled (null = unchanged); note: null = unchanged, "" = removed. */
export function updateVisit(visitId: string, status: string | null, note: string | null): Promise<ActionDone> {
  return api.post<ActionDone>(`/api/visits/${id(visitId)}`, { status, note });
}

// ---------- "Utilisateurs" ----------

/** Every account (farmers, experts, admins). */
export function getUsers(): Promise<UsersPage> {
  return api.get<UsersPage>("/api/users");
}

export function getUser(userId: string): Promise<UserDetail> {
  return api.get<UserDetail>(`/api/users/${id(userId)}`);
}

/** The badge of an expert. reason: optional to verify, required to remove. */
export function setExpertVerified(userId: string, verified: boolean, reason: string): Promise<ActionDone> {
  return api.post<ActionDone>(`/api/users/${id(userId)}/verified`, { verified, reason });
}

/** Block / unblock an account (reason required; not with the demo account). */
export function setUserBlocked(userId: string, blocked: boolean, reason: string): Promise<ActionDone> {
  return api.post<ActionDone>(`/api/users/${id(userId)}/blocked`, { blocked, reason });
}

// ---------- "Communauté" ----------

export function getCommunity(): Promise<CommunityPage> {
  return api.get<CommunityPage>("/api/community");
}

export function getPost(postId: string): Promise<PostDetail> {
  return api.get<PostDetail>(`/api/community/posts/${id(postId)}`);
}

export type Moderation = "hide" | "unhide" | "delete";

/** Hide, show again or delete a post or an answer (reason required). */
export function moderate(kind: "post" | "comment", targetId: string, action: Moderation, reason: string): Promise<ModerationDone> {
  const what = kind === "post" ? "posts" : "comments";
  return api.post<ModerationDone>(`/api/community/${what}/${id(targetId)}/moderate`, { action, reason });
}

/** "Classer" a report: nothing wrong (reason required). */
export function dismissReport(reportId: string, reason: string): Promise<ActionDone> {
  return api.post<ActionDone>(`/api/community/reports/${id(reportId)}/dismiss`, { reason });
}

// ---------- "Alertes" ----------

export function getRegionalAlerts(): Promise<RegionalAlertsPage> {
  return api.get<RegionalAlertsPage>("/api/alerts/regional");
}

export function getRegionalAlert(alertId: string): Promise<RegionalAlertDetail> {
  return api.get<RegionalAlertDetail>(`/api/alerts/regional/${id(alertId)}`);
}

/** Create (alertId null) or change a regional alert. */
export function saveRegionalAlert(alertId: string | null, input: AlertInput): Promise<RegionalAlert> {
  return api.post<RegionalAlert>(alertId ? `/api/alerts/regional/${id(alertId)}` : "/api/alerts/regional", input);
}

/** End an alert now (reason required): it disappears from the app at once. */
export function endRegionalAlert(alertId: string, reason: string): Promise<RegionalAlert> {
  return api.post<RegionalAlert>(`/api/alerts/regional/${id(alertId)}/end`, { reason });
}

export type SensorAlertFilters = { level?: string; governorate?: string; farmer_id?: string; days?: number };

/** The newest changes of level of every box (at most 300). */
export function getSensorAlerts(filters: SensorAlertFilters = {}): Promise<SensorAlertsPage> {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(filters)) if (v !== undefined && v !== "") q.set(k, String(v));
  const query = q.toString();
  return api.get<SensorAlertsPage>(`/api/alerts/sensors${query ? `?${query}` : ""}`);
}

// ---------- "Vergers" (read only) ----------

export function getOrchards(): Promise<OrchardsPage> {
  return api.get<OrchardsPage>("/api/orchards");
}

export function getOrchard(orchardId: string): Promise<OrchardDetail> {
  return api.get<OrchardDetail>(`/api/orchards/${id(orchardId)}`);
}

// ---------- "Abonnements", "Réglages", "Journal des actions" ----------

export function getBilling(): Promise<BillingPage> {
  return api.get<BillingPage>("/api/billing");
}

/** The price of ONE box for one period, in millimes (reason required; not with the demo account). */
export function setPrice(priceMillimes: number, reason: string): Promise<ActionDone> {
  return api.post<ActionDone>("/api/billing/price", { price_millimes: priceMillimes, reason });
}

export function getSettings(): Promise<SettingsPage> {
  return api.get<SettingsPage>("/api/settings");
}

export type SettingName =
  | "demo_payments_enabled"
  | "demo_login_enabled"
  | "iot_ingest_enabled"
  | "demo_admin_login_enabled"
  | "hectares_per_node"
  | "iot_history_days";

/** One setting: "true" / "false", or a number ("" = none for hectares_per_node). */
export function setSetting(name: SettingName, value: string, reason: string): Promise<ActionDone> {
  return api.post<ActionDone>(`/api/settings/${name}`, { value, reason });
}

/** Every admin action, newest first, 100 at a time (before = id of the last line shown). */
export function getActions(before?: number, actions?: string[]): Promise<ActionsPage> {
  const q = new URLSearchParams();
  if (before) q.set("before", String(before));
  if (actions?.length) q.set("actions", actions.join(","));
  const query = q.toString();
  return api.get<ActionsPage>(`/api/actions${query ? `?${query}` : ""}`);
}
