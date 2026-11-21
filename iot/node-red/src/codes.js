// ============================================================
//  CODES POUR SUPABASE (LOOZ)
//  Chaque mesure notée devient une ligne de CODES (aucune phrase : chaque
//  appli écrit ses textes dans sa langue). Les lignes attendent dans la
//  mémoire du flux (supabase_buffer, gardée sur le disque) ; le nœud
//  « Lot Supabase » les envoie une fois par minute.
// ============================================================
const MAX_BUFFER = 5000;   // ≈ 100 min de mesures si Supabase ne répond pas
const LEVEL = { OK: "ok", INFO: "info", WATCH: "watch", WARNING: "warning", CRITICAL: "critical", CAPTEUR: "sensor" };
const FIELD = { soil_moisture_pct: "soil_moisture", soil_temp_c: "soil_temp", air_temp_c: "air_temp",
                humidity_pct: "humidity", light_par: "light", battery_pct: "battery" };

// Codes de la passerelle (français) -> codes LOOZ (migration 012).
function faultCode(f) {
    if (f === "checksum_invalide") return "checksum_invalid";
    if (f === "sonde_sol_deconnectee") return "soil_probe_disconnected";
    if (f === "sonde_sol_figee") return "soil_probe_stuck";
    if (f === "sequence_dupliquee") return "duplicate_seq";
    if (f.startsWith("paquets_perdus_")) return "packets_lost";
    if (f === "batterie_faible") return "battery_low";
    if (f === "signal_faible") return "signal_weak";
    for (const [k, short] of Object.entries(FIELD)) {
        if (f === k + "_hors_plage") return short + "_out_of_range";
        if (f === k + "_absent") return short + "_missing";
    }
    return "other";
}
const num = v => (typeof v === "number" && Number.isFinite(v)) ? v : null;

const p = msg.payload;
const faults = (p.health && p.health.faults) || [];
let packetsLost = 0;
for (const f of faults) if (f.startsWith("paquets_perdus_")) packetsLost += Number(f.slice(15)) || 0;

// Mode démo : l'horloge simulée est l'heure de TUNISIE écrite comme UTC
// (« 05:00Z » = 05:00 à Sfax) -> on enlève 1 h pour envoyer le vrai instant.
const demo = (env.get("LOOZ_TIME_MODE") || "demo") === "demo";
const t = Date.parse(p.timestamp) - (demo ? 3600000 : 0);
if (!Number.isFinite(t)) { node.warn("mesure sans heure : ignorée"); return null; }
const ind = p.indicators || {};
const a = p.alert || {};

const reading = {
    device: p.nodeId,
    measured_at: new Date(t).toISOString(),
    seq: num(p.seq),
    soil_moisture_pct: num(p.soil_moisture_pct),
    soil_temp_c: num(p.soil_temp_c),
    air_temp_c: num(p.air_temp_c),
    humidity_pct: num(p.humidity_pct),
    light_par: num(p.light_par),
    light_adc: num(p.light_adc),
    piezo_rms: num(p.piezo_rms),
    piezo_events_h: num(p.piezo_events_h),
    vpd_kpa: num(p.vpd_kpa),
    battery_pct: num(p.battery_pct),
    rssi_dbm: num(p.rssi_dbm),
    water_stress: num(ind.water_stress),
    heat_stress: num(ind.heat_stress),
    anomaly: num(ind.anomaly_score),
    drying_rate_pct_h: num(ind.drying_rate_pct_h),
    hours_above_35c: num(ind.hours_above_35c),
    packets_lost: packetsLost,
    level: LEVEL[a.severity] || null,
    reasons: Array.isArray(a.reasons) ? a.reasons : [],
    cause: a.cause || null,
    confidence: num(a.confidence),
    faults: [...new Set(faults.map(faultCode))],
    firmware: p.firmware || null,
    model: a.model || null
};

const buffer = flow.get("supabase_buffer") || [];
buffer.push(reading);
// Trop de mesures en attente (Supabase injoignable) : les plus vieilles partent,
// mais jamais pendant un envoi (le lot en cours garde sa place).
if (buffer.length > MAX_BUFFER && !flow.get("supabase_inflight")) buffer.splice(0, buffer.length - MAX_BUFFER);
flow.set("supabase_buffer", buffer);
node.status({ fill: "grey", shape: "dot", text: `${buffer.length} mesure(s) en attente` });
return null;
