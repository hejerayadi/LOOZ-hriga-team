// The ONLY place that calls our backend. Pages use these functions,
// never fetch() directly.
//
// Every request gets the header "Authorization: Bearer <token>", where the
// token comes from the Supabase login. The backend checks it.
import { ACTION_ERROR } from "./labels";
import { supabase } from "./supabase";
import type {
  ActionDone,
  DemoSession,
  FarmerDetail,
  FarmerHistory,
  FarmersPage,
  NewKey,
  Overview,
  Profile,
  SensorsPage,
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
