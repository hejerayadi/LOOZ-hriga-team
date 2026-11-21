// The data of the pages "Prédictions IA", "Assistant vocal", "Diagnostics
// photo", the trends of "Vue d'ensemble" and a farmer's whole activity
// (backend: app/insights.py). Codes only come from the database: the French
// words are here.
import { api } from "./api";

export type Person = { id: string | null; name: string; phone: string | null; governorate: string | null; demo: boolean };
export type Factor = { code: string; level: "low" | "high" | null; share: number | null; feature?: string | null; value?: number | null; shap?: number | null };
export type ZoneRef = { id: string | null; letter: string | null; name: string };

export type Prediction = {
  node_id: string;
  model: "frost" | "stress";
  status: "ok" | "not_enough_data" | "sensor_problem";
  state: string | null;
  confidence: number | null;
  certainty: "likely" | "unsure" | null;
  probabilities: Record<string, number> | null;
  threshold: number | null;
  factors: Factor[];
  readings: Record<string, number | string | null>;
  explanation_ar: string | null;
  explanation_fr: string | null;
  action_ar: string | null;
  action_fr: string | null;
  explanation_source: string | null;
  model_version: string | null;
  measured_at: string;
  predicted_at: string;
  state_since: string | null;
  farmer: Person;
  zone: ZoneRef;
  device_code: string | null;
};

export type MlNotification = {
  id: string;
  model: "frost" | "stress";
  state: string;
  severity: "warning" | "danger";
  confidence: number | null;
  certainty: string | null;
  measured_at: string;
  created_at: string;
  read_at: string | null;
  resolved_at: string | null;
  node_id: string;
  farmer: Person;
  zone: ZoneRef;
  device_code: string | null;
};

export type MlPage = {
  predictions: Prediction[];
  notifications: MlNotification[];
  counts: { model: string; state: string; count: number }[];
  open_problems: number;
  worker: { code: string; enabled: boolean; last_seen_at: string | null; last_result: Record<string, number> | null } | null;
  server_time: string;
};

export type HistoryPoint = { model: string; measured_at: string; status: string; state: string | null; confidence: number | null; certainty: string | null; changed: boolean };

export type VoicePage = {
  days: { day: string; minutes: number; sessions: number; questions: number; tool_calls: number }[];
  by_farmer: { farmer: Person; sessions: number; minutes: number; questions: number; tool_calls: number; last: string | null }[];
  sessions: { id: string; started_at: string; ended_at: string | null; charged_seconds: number | null; end_reason: string | null; questions: number | null; tool_calls: number | null; community_posts: number | null; tokens_in: number | null; tokens_out: number | null; model: string | null; farmer: Person }[];
  totals: { sessions: number; minutes: number; questions: number; tool_calls: number };
};

export type Diagnosis = { id: string; status: string; model: string | null; verdict: string | null; top_class: string | null; top_confidence: number | null; plant: string | null; error: string | null; post_id: string | null; created_at: string; farmer: Person };
export type DiagnosesPage = { diagnoses: Diagnosis[]; by_verdict: Record<string, number>; by_class: Record<string, number>; by_model: Record<string, number> };

export type Trends = { days: string[]; series: Record<"signups" | "payments_dt" | "problems" | "diagnoses" | "voice_minutes" | "posts", number[]> };

export type TimelineEvent = { at: string; kind: string; label: string | null; detail: string | number | null };
export type FarmerActivity = {
  farmer: Person & { role: string; created_at: string };
  subscriptions: { id: string; plan: string; status: string; started_at: string; ends_at: string | null; nodes: number | null }[];
  payments: { id: string; plan: string; kind: string | null; amount_millimes: number; status: string; nodes: number | null; created_at: string }[];
  ml: MlPage;
  diagnoses: DiagnosesPage;
  voice: VoicePage;
  community: { posts: { id: string; text: string; hidden: boolean; date: string }[]; answers: { id: string; post_id: string; text: string; hidden: boolean; created_at: string }[]; reports: { id: string; reason: string; status: string; created_at: string }[]; me_too: number };
  admin_actions: { id: number; created_at: string; admin_name: string; action: string; target_label: string | null; reason: string | null }[];
  timeline: TimelineEvent[];
};

const q = encodeURIComponent;
export const getMl = () => api.get<MlPage>("/api/insights/ml");
export const getMlHistory = (nodeId: string) => api.get<{ node_id: string; points: HistoryPoint[] }>(`/api/insights/ml/history/${q(nodeId)}`);
export const getZoneContext = (zoneId: string) => api.get<Record<string, unknown>>(`/api/insights/zones/${q(zoneId)}/context`);
export const getVoice = (days = 30) => api.get<VoicePage>(`/api/insights/voice?days=${days}`);
export const getDiagnoses = () => api.get<DiagnosesPage>("/api/insights/diagnoses");
export const getTrends = (days = 30) => api.get<Trends>(`/api/insights/trends?days=${days}`);
export const getFarmerActivity = (id: string) => api.get<FarmerActivity>(`/api/insights/farmers/${q(id)}/activity`);

// ---------- French words ----------

export const STATE: Record<string, string> = {
  none: "Tout va bien",
  water_deficit: "Manque d'eau",
  waterlogging: "Trop d'eau",
  heat: "Forte chaleur",
  frost: "Dégâts du froid",
  rootzone: "Problème de racines",
  frost_risk: "Risque de gel cette nuit",
  no_frost: "Pas de gel cette nuit",
  sensor_problem: "Problème de capteur",
  not_enough_data: "Pas assez de données",
};

/** Colour of a state (the app's: 3 greens, blue for the frost night, grey without prediction). */
export const STATE_COLOR: Record<string, string> = {
  none: "#8ed04a",
  no_frost: "#8ed04a",
  water_deficit: "#69a66f",
  waterlogging: "#69a66f",
  rootzone: "#69a66f",
  heat: "#28664a",
  frost: "#28664a",
  frost_risk: "#6e9fc4",
  sensor_problem: "#9aa8a0",
  not_enough_data: "#9aa8a0",
};

export const MODEL: Record<string, string> = { frost: "Gel (cette nuit)", stress: "Stress des arbres" };

export const FACTOR: Record<string, [string, string]> = {
  // code: [low, high]
  soil_water: ["Peu d'eau dans le sol", "Beaucoup d'eau dans le sol"],
  soil_drying: ["Le sol sèche lentement", "Le sol sèche vite"],
  soil_too_wet: ["Sol pas gorgé d'eau", "Sol gorgé d'eau"],
  watering: ["Pas d'eau arrivée depuis un moment", "De l'eau est arrivée"],
  tree_water_need: ["Faible besoin en eau", "Fort besoin en eau"],
  air_heat: ["Journée peu chaude", "Forte chaleur la journée"],
  night_cold: ["Nuit dernière froide", "Nuit dernière douce"],
  evening_temp: ["Il fait froid maintenant", "Il ne fait pas froid maintenant"],
  cooling_fast: ["Refroidissement lent", "Refroidissement rapide"],
  night_low_expected: ["La nuit peut devenir très froide", "Nuit pas très froide"],
  dew_point: ["Air sec (point de rosée bas)", "Air humide (point de rosée haut)"],
  air_humidity: ["Air peu humide", "Air très humide"],
  air_dryness: ["Air pas sec", "Air sec et chaud"],
  clear_sky: ["Ciel couvert", "Ciel clair (la chaleur s'échappe)"],
  sunlight: ["Peu de soleil", "Beaucoup de soleil"],
  soil_temp: ["Sol froid", "Sol chaud"],
  tree_sounds: ["Tronc calme", "Le tronc donne des signes de soif"],
  zone_place: ["Zone dans un creux", "Zone en hauteur"],
  ground_cover: ["Petits arbres", "Grands arbres"],
  season_stage: ["Saison et stade des arbres", "Saison et stade des arbres"],
  soil_type: ["Type de sol", "Type de sol"],
  irrigation_type: ["Arrosage et sel de l'eau", "Arrosage et sel de l'eau"],
  other_zones: ["Comparé aux autres zones", "Comparé aux autres zones"],
  data_quality: ["Mesures manquantes", "Mesures manquantes"],
};

export function factorLabel(f: Factor): string {
  const pair = FACTOR[f.code];
  if (!pair) return f.code;
  return f.level === "low" ? pair[0] : pair[1];
}

export const TIMELINE: Record<string, string> = {
  payment: "Paiement",
  notification: "Notification (IA)",
  diagnosis: "Diagnostic photo",
  voice: "Assistant vocal",
  post: "Question publiée",
  answer: "Réponse",
  report: "Signalement",
  me_too: "« Moi aussi »",
};

export const VERDICT: Record<string, string> = { likely: "Probable", unsure: "Pas sûr", nothing: "Rien trouvé", none: "Rien trouvé", error: "Erreur", pending: "En cours" };
export const DISEASE: Record<string, string> = { shot_hole: "Criblure", leaf_curl: "Cloque", leaf_spot: "Taches" };
export const VOICE_END: Record<string, string> = { farmer: "Arrêtée par l'agriculteur", time_up: "Temps écoulé", error: "Connexion coupée", replaced: "Remplacée par une nouvelle", lost: "Jamais terminée (app fermée)", token_error: "Pas de jeton Google" };
