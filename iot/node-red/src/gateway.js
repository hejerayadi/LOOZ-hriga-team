// ============================================================
//  PASSERELLE DE VERGER : validation des paquets, santé des capteurs
//  (drapeaux « santé » séparés des scores biologiques — cf. §18)
// ============================================================
const GATEWAY = "GW-01";
const LIMITS = {
    soil_moisture_pct: [3, 95], soil_temp_c: [-10, 60], air_temp_c: [-15, 55],
    humidity_pct: [0, 100], light_par: [0, 2500], battery_pct: [0, 100]
};
function checksum(p) {
    const s = [p.nodeId, p.seq, p.soil_moisture_pct, p.soil_temp_c, p.air_temp_c, p.humidity_pct, p.light_par].join("|");
    let c = 0; for (const ch of s) c = (c * 31 + ch.charCodeAt(0)) & 0xffff; return c;
}

const p = msg.payload;
if (!p || !p.nodeId) { node.warn("paquet ignoré : nodeId absent"); return null; }
const faults = [];

if (checksum(p) !== p.checksum) faults.push("checksum_invalide");
for (const [k, [lo, hi]] of Object.entries(LIMITS)) {
    const v = p[k];
    if (typeof v !== "number" || Number.isNaN(v)) faults.push(k + "_absent");
    else if (k === "soil_moisture_pct" && v <= lo) faults.push("sonde_sol_deconnectee");   // lecture ≈ 0 : sonde débranchée
    else if (v < lo || v > hi) faults.push(k + "_hors_plage");
}
// séquence (paquets perdus / dupliqués) et sonde figée
const last = context.get("last_" + p.nodeId) || { seq: 0, sm: null, same: 0 };
if (last.seq > 0 && p.seq <= last.seq) faults.push("sequence_dupliquee");
else if (last.seq > 0 && p.seq > last.seq + 1) faults.push("paquets_perdus_" + (p.seq - last.seq - 1));
last.same = (last.sm === p.soil_moisture_pct) ? last.same + 1 : 0;
if (last.same >= 8) faults.push("sonde_sol_figee");
if (p.battery_pct < 15) faults.push("batterie_faible");
if (p.rssi_dbm < -105) faults.push("signal_faible");
context.set("last_" + p.nodeId, { seq: p.seq, sm: p.soil_moisture_pct, same: last.same });

p.gateway     = GATEWAY;
p.received_at = new Date().toISOString();
p.health      = { ok: faults.length === 0, faults };
msg.payload   = p;

node.status({ fill: faults.length ? "yellow" : "green", shape: "dot", text: `${p.nodeId} ${faults.length ? "⚠ " + faults[0] : "OK"}` });
const fault = faults.length
    ? { topic: `farm/${p.orchardId}/${p.nodeId}/health`, payload: { nodeId: p.nodeId, zone: p.zone, trees: p.trees, timestamp: p.timestamp, faults } }
    : null;
return [msg, fault];
