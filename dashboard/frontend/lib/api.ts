// The ONLY place that calls our backend. Pages use these functions,
// never fetch() directly.
//
// Every request gets the header "Authorization: Bearer <token>", where the
// token comes from the Supabase login. The backend checks it.
import { supabase } from "./supabase";
import type { Profile } from "./types";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

/** An error from the backend. `status` = HTTP code (0 = server unreachable). */
export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

/** true when the backend refused the user (not logged in, or not an admin). */
export function isAccessDenied(error: unknown): boolean {
  return error instanceof ApiError && (error.status === 401 || error.status === 403);
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
    response = await fetch(`${API_URL}${path}`, { ...options, headers });
  } catch {
    throw new ApiError(0, "Cannot reach the API server. Is the backend running?");
  }

  if (!response.ok) {
    // FastAPI sends errors as { "detail": "..." }
    const body = await response.json().catch(() => null);
    throw new ApiError(response.status, body?.detail ?? response.statusText);
  }
  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

/** Generic helpers, for the next pages (users, alerts...). */
export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body: unknown) =>
    request<T>(path, { method: "POST", body: JSON.stringify(body) }),
  patch: <T>(path: string, body: unknown) =>
    request<T>(path, { method: "PATCH", body: JSON.stringify(body) }),
  delete: <T>(path: string) => request<T>(path, { method: "DELETE" }),
};

/** The logged-in admin's profile. Fails with 401/403 if not an admin. */
export function getMe(): Promise<Profile> {
  return api.get<Profile>("/api/me");
}
