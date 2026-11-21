// ============================================================
//  MÉMOIRE NUMÉRIQUE DU NŒUD (ZONE) · INDICES DE STRESS · LOGIQUE D'ALERTE
//  Les alertes parlent de la ZONE (nœud), pas d'un arbre.
//  Règles déterministes (modèle « rules-v1 ») — point d'accroche du service IA (§12)
// ============================================================
const MEMORY_SIZE  = 288;          // 3 jours simulés à 15 min
const TICK_MINUTES = 15;
const T_HEAT = 35;

const p    = msg.payload;
// Capacité au champ / point de flétrissement du SOL DE LA ZONE (% volumique, envoyés par le nœud ; 38 / 15 par défaut).
const FIELD_CAP = p.field_cap || 38, WILTING = p.wilting || 15;
const mem  = flow.get("memoire") || {};
const tree = mem[p.nodeId] || { history: [], prevSeverity: "OK", persist: 0, faultHold: 0, lower: 0 };
const RANK = { CRITICAL: 4, WARNING: 3, WATCH: 2, INFO: 1, CAPTEUR: 1, OK: 0 };
const faults = p.health.faults;
const soilOk = !faults.some(f => f.startsWith("soil_moisture") || f.startsWith("sonde_sol") || f === "checksum_invalide");

// ---------- mémoire longitudinale (mesures valides seulement) ----------
const now = Date.parse(p.timestamp);
if (soilOk) tree.history.push({ t: now, sm: p.soil_moisture_pct, ta: p.air_temp_c, rh: p.humidity_pct, par: p.light_par });
if (tree.history.length > MEMORY_SIZE) tree.history.splice(0, tree.history.length - MEMORY_SIZE);
const H = tree.history;

// ---------- baseline personnalisée : plage « normale » apprise sur le premier jour de CE nœud ----------
const mean = a => a.reduce((x, y) => x + y, 0) / a.length;
const std  = a => { const m = mean(a); return Math.sqrt(mean(a.map(v => (v - m) ** 2))); };
let baseline = null;
if (H.length >= 24) {                                                       // ≥ 6 h de mesures valides
    const sms = H.slice(0, 96).map(x => x.sm);                              // 96 échantillons = 1 jour simulé
    baseline = { sm_mean: Math.round(mean(sms) * 10) / 10, sm_std: Math.max(2, std(sms)), n: sms.length };
}
// hystérésis des défauts capteur : un défaut maintient l'état CAPTEUR pendant 8 cycles (2 h simulées)
tree.faultHold = soilOk ? Math.max(0, tree.faultHold - 1) : 8;
const sensorFault = tree.faultHold > 0;

// ---------- features ----------
const clamp = (v, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));
const ago6 = H.filter(x => x.t <= now - 6 * 3600000).pop();                 // mesure ≈ 6 h plus tôt
const dryingRate = (ago6 && soilOk) ? Math.max(0, (ago6.sm - p.soil_moisture_pct) / ((now - ago6.t) / 3600000)) : 0; // %/h
const hoursHot = H.filter(x => x.t > now - 24 * 3600000 && x.ta >= T_HEAT).length * TICK_MINUTES / 60;

// ---------- indices (0–100) ----------
let wsi = null, anomaly = null;
if (soilOk) {
    const deficit = clamp((FIELD_CAP - p.soil_moisture_pct) / (FIELD_CAP - WILTING));
    wsi = Math.round(100 * (0.60 * deficit + 0.25 * clamp(dryingRate / 1.5) + 0.15 * clamp(p.vpd_kpa / 3)));
}
const hsi = Math.round(100 * (0.50 * clamp((p.air_temp_c - 32) / 12) + 0.35 * clamp(hoursHot / 10) + 0.15 * clamp(p.light_par / 1800)));
if (baseline && soilOk) {
    const z = (baseline.sm_mean - p.soil_moisture_pct) / baseline.sm_std;    // > 0 : plus sec que d'habitude
    anomaly = Math.round(100 * clamp(z / 4)) / 100;
}

// ---------- logique d'alerte (§14) ----------
const zl = "zone " + p.zone;                    // ex. « zone 2 »
const nb = (p.tree_count || 0) + " arbres";
const signals = [];
if (wsi !== null && wsi >= 60) signals.push("stress hydrique");
if (hsi >= 60) signals.push("stress thermique");
if (anomaly !== null && anomaly >= 0.6) signals.push("écart au profil habituel");
const modere = (wsi !== null && wsi >= 40) || hsi >= 40 || (anomaly !== null && anomaly >= 0.6);
tree.persist = modere ? tree.persist + 1 : 0;
const hydrique = (wsi !== null && wsi >= hsi);

let severity = "OK", message = "", action = "";
if (sensorFault) {
    severity = "CAPTEUR";
    message  = `Zone ${p.zone} · nœud ${p.nodeId} : défaut capteur${faults.length ? " (" + faults.join(", ") + ")" : " récent"}. Indices de stress hydrique suspendus.`;
    action   = "Vérifier la sonde de sol et le câblage du nœud.";
} else if ((wsi !== null && wsi >= 80) || hsi >= 80 || p.soil_moisture_pct <= WILTING) {
    severity = "CRITICAL";
    message  = `Inspection immédiate recommandée : stress sévère détecté dans la ${zl} (${nb}).`;
    action   = hydrique ? "Irriguer sans délai et inspecter la zone racinaire." : "Protéger les arbres de la zone (ombrage, irrigation de rafraîchissement).";
} else if (signals.length >= 2) {
    severity = "WARNING";
    message  = hydrique
        ? `Le risque de stress hydrique augmente dans la ${zl}. Inspecter la ligne d'irrigation de la zone.`
        : `Le risque de stress thermique augmente dans la ${zl} (${nb}).`;
    action   = hydrique ? "Contrôler la ligne d'irrigation et l'humidité du sol." : "Prévoir un arrosage de rafraîchissement.";
} else if (modere && tree.persist >= 4) {
    severity = "WATCH";
    message  = hydrique
        ? `Stress hydrique possible dans la ${zl}. Vérifier l'irrigation et l'humidité du sol.`
        : `Exposition thermique prolongée dans la ${zl}. Surveiller l'évolution.`;
    action   = "Vérifier sur place dans la journée.";
} else if (anomaly !== null && anomaly >= 0.5) {
    severity = "INFO";
    message  = `La ${zl} sèche plus vite que d'habitude (profil habituel du nœud).`;
    action   = "Aucune action immédiate ; suivre la tendance.";
}
// hystérésis : on ne redescend d'un niveau qu'après 4 cycles consécutifs (1 h simulée) sous ce niveau
if (severity !== "CAPTEUR" && tree.prevSeverity !== "CAPTEUR" && RANK[severity] < RANK[tree.prevSeverity]) {
    tree.lower += 1;
    if (tree.lower < 4) severity = tree.prevSeverity;
} else tree.lower = 0;
const confidence = sensorFault ? 0.9 : Math.min(0.95, 0.45 + 0.15 * signals.length + (baseline ? 0.15 : 0) + Math.min(0.2, tree.persist * 0.02));

// ---------- codes (Supabase, applis LOOZ) : jamais de phrases ----------
// reasons = ce qui explique le niveau ; cause = water | heat | sensor (null si OK)
const reasons = [];
if (severity === "CAPTEUR") reasons.push("sensor_fault");
else if (severity !== "OK") {
    if (soilOk && p.soil_moisture_pct <= WILTING) reasons.push("wilting_point");
    if (wsi !== null && wsi >= 40) reasons.push("water_stress");
    if (hsi >= 40) reasons.push("heat_stress");
    if (anomaly !== null && anomaly >= 0.5) reasons.push("unusual_drying");
}
const cause = severity === "OK" ? null
            : severity === "CAPTEUR" ? "sensor"
            : (severity === "INFO" || hydrique) ? "water" : "heat";

p.indicators = { water_stress: wsi, heat_stress: hsi, anomaly_score: anomaly,
                 drying_rate_pct_h: Math.round(dryingRate * 100) / 100, hours_above_35c: Math.round(hoursHot * 10) / 10 };
p.baseline = baseline;
p.alert    = { severity, message, action, confidence: Math.round(confidence * 100) / 100, model: "rules-v1",
               reasons, cause };
msg.payload = p;

// événement d'alerte uniquement sur changement de niveau (alertes événementielles, pas de flux continu)
let event = null;
if (severity !== tree.prevSeverity) {
    const retour = severity === "OK";
    event = { topic: `farm/${p.orchardId}/alerts`, payload: {
        id: `${p.nodeId}-${p.seq}`, nodeId: p.nodeId, zone: p.zone, cultivar: p.cultivar,
        trees: p.trees, tree_count: p.tree_count,
        severity, previous: tree.prevSeverity,
        message: retour ? `Retour à la normale dans la ${zl}.` : message,
        action:  retour ? "Aucune." : action,
        confidence: p.alert.confidence, confidence_pct: Math.round(p.alert.confidence * 100),
        indicators: p.indicators, model: "rules-v1",
        timestamp: p.timestamp, timestamp_label: msg.simTime || p.timestamp
    } };
    tree.prevSeverity = severity;
}
mem[p.nodeId] = tree;
flow.set("memoire", mem);
node.status({ fill: severity === "OK" ? "green" : (severity === "CRITICAL" ? "red" : "yellow"), shape: "dot", text: `${p.nodeId} ${severity}` });
return [msg, event];
