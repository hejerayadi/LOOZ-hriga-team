// The French texts of the codes sent by the backend (the database stores
// only codes: each app writes its own texts). One place for all of them.

export const GOVERNORATES: Record<string, string> = {
  tunis: "Tunis",
  ariana: "Ariana",
  ben_arous: "Ben Arous",
  manouba: "Manouba",
  nabeul: "Nabeul",
  zaghouan: "Zaghouan",
  bizerte: "Bizerte",
  beja: "Béja",
  jendouba: "Jendouba",
  kef: "Le Kef",
  siliana: "Siliana",
  sousse: "Sousse",
  monastir: "Monastir",
  mahdia: "Mahdia",
  sfax: "Sfax",
  kairouan: "Kairouan",
  kasserine: "Kasserine",
  sidi_bouzid: "Sidi Bouzid",
  gabes: "Gabès",
  medenine: "Médenine",
  tataouine: "Tataouine",
  gafsa: "Gafsa",
  tozeur: "Tozeur",
  kebili: "Kébili",
};

/** State of a sensor box (view iot_node_status). */
export const BOX_STATUS: Record<string, string> = {
  waiting: "En attente d'installation",
  installed: "Installé, aucune donnée",
  online: "En ligne",
  offline: "Hors ligne",
  sensor_problem: "Problème de capteur",
};

/** Level of a box (rules-v1 of Node-RED). */
export const LEVEL: Record<string, string> = {
  ok: "Normal",
  info: "Information",
  watch: "À surveiller",
  warning: "Alerte",
  critical: "Critique",
  sensor: "Capteur",
};

/** What explains the level. */
export const REASON: Record<string, string> = {
  water_stress: "stress hydrique",
  heat_stress: "stress thermique",
  unusual_drying: "sèche plus vite que d'habitude",
  wilting_point: "sol au point de flétrissement",
  sensor_fault: "défaut de capteur",
  other: "autre raison",
};

/** Sensor and box problems. */
export const FAULT: Record<string, string> = {
  checksum_invalid: "Paquet abîmé (somme de contrôle)",
  soil_probe_disconnected: "Sonde de sol débranchée",
  soil_probe_stuck: "Sonde de sol figée",
  packets_lost: "Paquets perdus",
  duplicate_seq: "Paquet reçu deux fois",
  battery_low: "Batterie faible",
  signal_weak: "Signal faible",
  soil_moisture_out_of_range: "Humidité du sol hors plage",
  soil_temp_out_of_range: "Température du sol hors plage",
  air_temp_out_of_range: "Température de l'air hors plage",
  humidity_out_of_range: "Humidité de l'air hors plage",
  light_out_of_range: "Lumière hors plage",
  battery_out_of_range: "Batterie hors plage",
  soil_moisture_missing: "Humidité du sol absente",
  soil_temp_missing: "Température du sol absente",
  air_temp_missing: "Température de l'air absente",
  humidity_missing: "Humidité de l'air absente",
  light_missing: "Lumière absente",
  battery_missing: "Batterie absente",
  other: "Autre problème",
};

/** Why Supabase refused the readings of a box. */
export const REFUSAL: Record<string, string> = {
  not_installed: "installation non acceptée",
  no_paid_pack: "pas de pack payant en cours",
  zone_archived: "zone supprimée",
  bad_time: "heure invalide",
  bad_values: "valeurs invalides",
  unknown_device: "boîtier inconnu",
  bad_device: "code de boîtier invalide",
};

export const ZONE_TYPE: Record<string, string> = {
  young_trees: "Jeunes arbres",
  old_trees: "Vieux arbres",
  sandy_soil: "Sol sableux",
  irrigated: "Irriguée",
  rainfed: "Pluviale",
  other: "Autre",
};

export const VISIT: Record<string, string> = {
  new: "à planifier",
  contacted: "agriculteur contacté",
  installed: "installation faite",
  cancelled: "annulée",
};

/** A code -> its text (the code itself if unknown, never an empty cell). */
export function label(table: Record<string, string>, code: string | null | undefined): string {
  if (!code) return "—";
  return table[code] ?? code;
}

/**
 * The name of a person, or `fallback`. "New user" is the name the database
 * gives an account that has none yet (English): never shown.
 */
export function personName(name: string | null | undefined, fallback = "Administrateur"): string {
  const n = (name ?? "").trim();
  return n && n !== "New user" ? n : fallback;
}

/** "Zone A" (the farmer's own name of the zone if he gave one). */
export function zoneName(letter: string | null | undefined, name?: string | null): string {
  if (name && name.trim()) return name.trim();
  return letter ? `Zone ${letter}` : "Zone";
}

/** What an admin did (admin_actions.action, migration 013). */
export const ACTION: Record<string, string> = {
  node_accept: "Installation acceptée",
  node_unaccept: "Acceptation retirée",
  gateway_new_key: "Nouvelle clé de passerelle",
  gateway_enable: "Passerelle activée",
  gateway_disable: "Passerelle désactivée",
  visit_update: "Visite d'installation modifiée",
  expert_verify: "Expert vérifié",
  expert_unverify: "Vérification retirée",
  user_block: "Compte bloqué",
  user_unblock: "Compte débloqué",
  post_hide: "Publication masquée",
  post_unhide: "Publication de nouveau visible",
  post_delete: "Publication supprimée",
  comment_hide: "Réponse masquée",
  comment_unhide: "Réponse de nouveau visible",
  comment_delete: "Réponse supprimée",
  report_dismiss: "Signalement classé",
  alert_create: "Alerte régionale créée",
  alert_update: "Alerte régionale modifiée",
  alert_end: "Alerte régionale terminée",
  price_change: "Prix modifié",
  setting_change: "Réglage modifié",
};

/** Why the database refused an action (code sent by the backend). */
export const ACTION_ERROR: Record<string, string> = {
  reason: "Le motif doit faire entre 3 et 300 caractères (sans < ni >).",
  device_code: "Code du boîtier : 2 à 40 caractères, lettres majuscules, chiffres, - ou _.",
  device_code_taken: "Ce code est déjà utilisé par un autre boîtier.",
  device_code_missing: "Indiquez le code imprimé sur le boîtier.",
  demo_not_allowed: "Action impossible avec le compte de démonstration.",
  demo_only: "Le compte de démonstration agit seulement sur les données de démonstration.",
  admin_only: "Action réservée aux administrateurs.",
  box_zone_removed: "Boîtier introuvable (sa zone a peut-être été supprimée).",
  not_found: "Introuvable : la page n'est peut-être plus à jour. Rechargez.",
  visit_closed: "Cette visite est terminée : son état ne peut plus changer.",
  visit_status: "État de visite invalide.",
  note: "La note fait au plus 500 caractères.",
  forbidden: "Action refusée par la base de données.",
  invalid: "Valeur refusée par la base de données.",
  conflict: "Conflit : cette valeur existe déjà.",
  too_many: "Trop de tentatives : attendez quelques secondes.",
  demo_local_only: "La connexion démo marche seulement sur cet ordinateur (127.0.0.1).",
  demo_not_configured: "Connexion démo non configurée : DEMO_ADMIN_PASSWORD manque dans backend/.env.",
  demo_off: "La connexion démo est désactivée.",
  demo_login_failed: "La connexion du compte de démonstration a échoué (compte ou mot de passe).",
  demo_not_admin: "Le compte de démonstration n'est pas administrateur : lancez supabase/seed/demo_admin.sql.",
  not_expert: "Seuls les experts reçoivent le badge.",
  admin_target: "Un compte administrateur ne peut pas être bloqué ici.",
  report_closed: "Ce signalement est déjà traité.",
  alert_ended: "Cette alerte est terminée : elle ne peut plus changer.",
  alert_ends_at: "Date de fin invalide.",
  alert_kind: "Choisissez le type d'alerte.",
  alert_severity: "Choisissez la gravité.",
  alert_governorates: "Choisissez au moins un gouvernorat.",
  alert_title_ar: "Titre en arabe : 1 à 80 caractères, en lettres arabes.",
  alert_title_fr: "Titre en français : 1 à 80 caractères.",
  alert_body_ar: "Texte en arabe : 1 à 600 caractères, en lettres arabes.",
  alert_body_fr: "Texte en français : 1 à 600 caractères.",
  alert_advice: "Le conseil s'écrit dans les deux langues, ou pas du tout.",
  alert_advice_ar: "Conseil en arabe : 1 à 400 caractères, en lettres arabes.",
  alert_advice_fr: "Conseil en français : 1 à 400 caractères.",
  alert_starts_at: "Date de début invalide.",
  price: "Prix : entre 1 et 1000 DT.",
  hectares: "Hectares par boîtier : entre 0,10 et 1000, ou vide.",
  history_days: "Durée de conservation : entre 1 et 3650 jours.",
  database: "Erreur de la base de données.",
};

export const ROLE: Record<string, string> = {
  farmer: "Agriculteur",
  expert: "Expert",
  admin: "Administrateur",
};

export const LANGUAGE: Record<string, string> = {
  ar: "Arabe",
  fr: "Français",
};

export const POST_TYPE: Record<string, string> = {
  question: "Question",
  tip: "Conseil",
};

/** Why a user reported a post or an answer (the app's future "Signaler"). */
export const REPORT_REASON: Record<string, string> = {
  spam: "Publicité ou spam",
  insult: "Insulte",
  wrong_advice: "Conseil faux ou dangereux",
  other: "Autre raison",
};

export const REPORT_STATUS: Record<string, string> = {
  open: "À traiter",
  dismissed: "Classé",
  actioned: "Traité",
};

// ---------- Regional alerts (Phase C) ----------

export const ALERT_KIND: Record<string, string> = {
  frost: "Gel",
  heat: "Vague de chaleur",
  drought: "Sécheresse",
  disease: "Maladie",
  pest: "Ravageurs",
  wind: "Vent fort",
  rain: "Fortes pluies",
};

export const ALERT_KIND_ICON: Record<string, string> = {
  frost: "❄️",
  heat: "🌡️",
  drought: "☀️",
  disease: "🍂",
  pest: "🐛",
  wind: "💨",
  rain: "🌧️",
};

export const SEVERITY: Record<string, string> = {
  info: "Information",
  warning: "Vigilance",
  danger: "Danger",
};

export const ALERT_STATUS: Record<string, string> = {
  active: "En cours",
  scheduled: "Programmée",
  expired: "Expirée",
  ended: "Terminée",
};

/**
 * ONLY for the preview of what farmers see in the app (Arabic screen): the
 * same words as the app (mobile_app/lib/l10n/app_ar.arb).
 */
// The app's own words (mobile_app/lib/l10n/app_ar.arb): keep them the same.
export const PREVIEW_AR = {
  screenTitle: "تنبيه في منطقتك",
  whatToDo: "ماذا أفعل؟",
  meToo: "أنا أيضًا",
  done: "تمّ",
  validUntil: (date: string, time: string) => `صالح حتى ${date} على الساعة ${time}`,
  noEnd: "صالح حتى إشعار آخر",
  /** The Arabic plural of the app ("meTooFirst" / "meTooSaid"). */
  meTooText: (n: number) => {
    if (n === 0) return "كن أول من يقول: أنا أيضًا";
    if (n === 1) return "فلاح واحد قال: أنا أيضًا";
    if (n === 2) return "فلاحان قالا: أنا أيضًا";
    const m = n % 100;
    if (m >= 3 && m <= 10) return `${n} فلاحين قالوا: أنا أيضًا`;
    if (m >= 11) return `${n} فلاحًا قالوا: أنا أيضًا`;
    return `${n} فلاح قالوا: أنا أيضًا`;
  },
  kind: {
    frost: "صقيع",
    heat: "موجة حرّ",
    drought: "جفاف",
    disease: "مرض",
    pest: "آفات",
    wind: "رياح قوية",
    rain: "أمطار غزيرة",
  } as Record<string, string>,
  severity: { info: "معلومة", warning: "انتباه", danger: "خطر" } as Record<string, string>,
  governorates: {
    tunis: "تونس",
    ariana: "أريانة",
    ben_arous: "بن عروس",
    manouba: "منوبة",
    nabeul: "نابل",
    zaghouan: "زغوان",
    bizerte: "بنزرت",
    beja: "باجة",
    jendouba: "جندوبة",
    kef: "الكاف",
    siliana: "سليانة",
    sousse: "سوسة",
    monastir: "المنستير",
    mahdia: "المهدية",
    sfax: "صفاقس",
    kairouan: "القيروان",
    kasserine: "القصرين",
    sidi_bouzid: "سيدي بوزيد",
    gabes: "قابس",
    medenine: "مدنين",
    tataouine: "تطاوين",
    gafsa: "قفصة",
    tozeur: "توزر",
    kebili: "قبلي",
  } as Record<string, string>,
};

/** The French screen of the app (mobile_app/lib/l10n/app_fr.arb). */
export const PREVIEW_FR = {
  screenTitle: "Alerte régionale",
  whatToDo: "Que faire ?",
  meToo: "Moi aussi",
  done: "Fait",
  validUntil: (date: string, time: string) => `Valable jusqu'au ${date} à ${time}`,
  noEnd: "Valable jusqu'à nouvel ordre",
  meTooText: (n: number) =>
    n === 0 ? "Soyez le premier à dire « Moi aussi »" : n === 1 ? "1 agriculteur a dit « Moi aussi »" : `${n} agriculteurs ont dit « Moi aussi »`,
};

// ---------- Packs and payments (Phase D) ----------

export const PLAN: Record<string, string> = {
  free: "Gratuit",
  paid: "Payant",
};

export const PAYMENT_STATUS: Record<string, string> = {
  paid_demo: "Payé (démo)",
  failed_demo: "Échoué (démo)",
  pending: "En attente",
  paid: "Payé",
  failed: "Échoué",
  expired: "Expiré",
};

export const PAYMENT_KIND: Record<string, string> = {
  period: "Période",
  extra_nodes: "Boîtiers en plus",
};

export const ORCHARD_STATUS: Record<string, string> = {
  complete: "Construit",
  draft: "Brouillon",
};

/** The settings of app_settings (Réglages, Abonnements). */
export const SETTING: Record<string, string> = {
  demo_payments_enabled: "Paiement de démonstration",
  demo_login_enabled: "Connexion de démonstration de l'application",
  iot_ingest_enabled: "Réception des données des capteurs",
  demo_admin_login_enabled: "« Connexion démo » du tableau de bord",
  hectares_per_node: "Hectares par boîtier",
  iot_history_days: "Conservation de l'historique des capteurs",
};

/** The groups of the "Journal des actions" filter. */
export const ACTION_GROUPS: { id: string; label: string; actions: string[] }[] = [
  { id: "sensors", label: "Boîtiers, passerelles et visites", actions: ["node_accept", "node_unaccept", "gateway_new_key", "gateway_enable", "gateway_disable", "visit_update"] },
  { id: "users", label: "Comptes et experts", actions: ["expert_verify", "expert_unverify", "user_block", "user_unblock"] },
  { id: "community", label: "Communauté", actions: ["post_hide", "post_unhide", "post_delete", "comment_hide", "comment_unhide", "comment_delete", "report_dismiss"] },
  { id: "alerts", label: "Alertes régionales", actions: ["alert_create", "alert_update", "alert_end"] },
  { id: "settings", label: "Prix et réglages", actions: ["price_change", "setting_change"] },
];
