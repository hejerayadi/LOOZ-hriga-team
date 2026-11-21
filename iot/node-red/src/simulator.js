// ============================================================
//  SIMULATION DES NŒUDS (ESP32) — LOOZ
//  1 nœud = 1 zone du verger ; chaque nœud couvre plusieurs arbres.
//  Zones A à D : les mêmes noms que dans Supabase et le dashboard admin LOOZ.
//  Un message par NŒUD à chaque déclenchement (toutes les 5 s = 15 min simulées).
//
//  Canaux bruts (mêmes noms que les jeux de données des modèles IA) :
//    soil_moisture_pct (sonde capacitive = VWC x 100), soil_temp_c (DS18B20, pas de
//    1/16 °C), air_temp_c + humidity_pct (DHT11 : °C et % entiers, 0 °C au plus bas,
//    humidité entre 20 et 90 %), light_adc (capteur de lumière 12 bits, saturé en
//    plein soleil), piezo_rms + piezo_events_h (piézo sur le tronc : vibrations et
//    « clics » d'émission acoustique par heure), + light_par, vpd_kpa (rules-v1).
//
//  Scénarios (flow.scenario, interrupteur du dashboard, ou LOOZ_SCENARIO dans .env) :
//    summer : 15 juin, irrigation goutte-à-goutte ; NODE-02 ligne fuyarde,
//             NODE-03 zone chaude, NODE-04 sonde de sol défaillante.
//    frost  : NUIT DE GEL EN FLORAISON (18 → 19 février) : ciel clair, air sec,
//             la zone D (bas-fond) passe sous 0 °C vers 4 h du matin.
//  Quand le scénario change, l'horloge AVANCE jusqu'au début du scénario (jamais
//  en arrière) et les 36 h simulées d'avant sont envoyées d'un coup (historique
//  pour les modèles IA).
// ============================================================
const ORCHARD      = "VERGER-NORD";
const TICK_MINUTES = 15;
const BACKFILL_H   = 36;
const NODES = [
    // soil : sol de la zone (mêmes valeurs que Supabase, migration 019) ; fc / wp / sat en % volumique
    { id: "NODE-01", zone: "A", cultivar: "Nonpareil", age: 8,  scenario: "normal",                 far: false,
      soil: "sandy_loam", fc: 25, wp: 11, sat: 44, place: 0,
      trees: ["TREE-012", "TREE-013", "TREE-014", "TREE-027", "TREE-028"] },
    { id: "NODE-02", zone: "B", cultivar: "Nonpareil", age: 10, scenario: "irrigation_defaillante", far: false,
      soil: "sandy_loam", fc: 25, wp: 11, sat: 44, place: 0,
      trees: ["TREE-042", "TREE-043", "TREE-044", "TREE-058"] },
    { id: "NODE-03", zone: "C", cultivar: "Tuono",     age: 12, scenario: "zone_chaude",            far: true,
      soil: "loamy_sand", fc: 17.4, wp: 7.1, sat: 43, place: 1.5,
      trees: ["TREE-073", "TREE-074", "TREE-075", "TREE-076", "TREE-077"] },
    { id: "NODE-04", zone: "D", cultivar: "Ferraduel", age: 4,  scenario: "sonde_sol_defaillante",  far: true,
      soil: "sand", fc: 12, wp: 5, sat: 43, place: -2.5,
      trees: ["TREE-089", "TREE-090", "TREE-091", "TREE-092"] }
];
// place : écart de température la nuit (zone haute +1,5 °C, bas-fond -2,5 °C : l'air froid y descend)

if (flow.get("simulation_active") === false) {
    node.status({ fill: "grey", shape: "ring", text: "simulation en pause" });
    return null;
}

// ---------- scénario et horloge ----------
const wanted = flow.get("scenario") || env.get("LOOZ_SCENARIO") || "summer";
const scenario = wanted === "frost" ? "frost" : "summer";
let clock = context.get("clock");
const running = context.get("scenario_running") || (clock === undefined ? null : "summer");
const p2 = v => String(v).padStart(2, "0");

// Le prochain début du scénario (après l'horloge actuelle) : 15 juin 05:00 / 18 février 18:00.
function nextStart(sc, after) {
    const d = new Date(after);
    for (let y = d.getUTCFullYear(); y < d.getUTCFullYear() + 3; y++) {
        const t = sc === "frost" ? Date.UTC(y, 1, 18, 18, 0) : Date.UTC(y, 5, 15, 5, 0);
        if (t > after) return t;
    }
    return after;
}
let ticks = [];                                     // les horloges à simuler maintenant
if (clock === undefined || running !== scenario) {
    const start = clock === undefined
        ? (scenario === "frost" ? Date.UTC(2027, 1, 18, 18, 0) : Date.UTC(2026, 5, 15, 5, 0))
        : nextStart(scenario, clock + BACKFILL_H * 3600000);
    for (let t = start - BACKFILL_H * 3600000; t <= start; t += TICK_MINUTES * 60000) ticks.push(t);
    context.set("scenario_running", scenario);
    context.set("scenario_start", start);
    context.set("state", {});                       // nouveau scénario : nouvel état des sols
} else {
    ticks.push(clock + TICK_MINUTES * 60000);
}
const scStart = context.get("scenario_start") || ticks[0];

// ---------- hasard (Math.random, remplaçable par les tests) ----------
const rnd = a => (Math.random() - 0.5) * 2 * a;
const r1 = v => Math.round(v * 10) / 10;
const es = t => 0.6108 * Math.exp(17.27 * t / (t + 237.3));
function poisson(lambda) {                          // nombre d'événements (loi de Poisson)
    const L = Math.exp(-lambda); let k = 0, p = 1;
    do { k++; p *= Math.random(); } while (p > L);
    return k - 1;
}
function checksum(p) {
    const s = [p.nodeId, p.seq, p.soil_moisture_pct, p.soil_temp_c, p.air_temp_c, p.humidity_pct, p.light_par].join("|");
    let c = 0; for (const ch of s) c = (c * 31 + ch.charCodeAt(0)) & 0xffff; return c;
}

// ---------- météo du verger (commune), selon le scénario ----------
// Température de l'air à l'heure h du jour j (j = jours depuis le début du scénario, peut être < 0).
function weather(t) {
    const d = new Date(t);
    const h = d.getUTCHours() + d.getUTCMinutes() / 60;
    const day = Math.floor((t - Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate())) / 86400000);
    const j = Math.floor((Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) -
              Date.UTC(new Date(scStart).getUTCFullYear(), new Date(scStart).getUTCMonth(), new Date(scStart).getUTCDate())) / 86400000);
    if (scenario === "summer") {
        const canicule = (j >= 1 && j <= 2) ? 3 : 0;                  // vague de chaleur jours 2-3 (+3 °C)
        let cloud = context.get("cloud_" + j);
        if (cloud === undefined) { cloud = 0.75 + Math.random() * 0.25; context.set("cloud_" + j, cloud); }
        const tAir = 27 + canicule + 8 * Math.cos(2 * Math.PI * (h - 15) / 24);
        const par = (h > 6 && h < 20) ? 1900 * cloud * Math.sin(Math.PI * (h - 6) / 14) : 0;
        return { tAir, par, td: null, night: h < 6 || h >= 20, sunrise: 6, sunset: 20, winter: false, day };
    }
    // Hiver, floraison. j = 0 : le soir de la nuit de gel (18 → 19 février).
    const TMAX = { "-2": 16, "-1": 16, "0": 15, "1": 17, "2": 18 };
    const TMIN = { "-2": 6, "-1": 5, "0": 0.5, "1": 4, "2": 6 };       // TMIN[j] = minimum de la nuit qui COMMENCE le soir du jour j
    const TD   = { "-2": 7, "-1": 6, "0": -4, "1": 3, "2": 6 };        // point de rosée du soir (air sec la nuit de gel)
    const g = (tab, k) => tab[String(Math.max(-2, Math.min(2, k)))];
    const sunrise = 6.8, sunset = 17.9;
    let tAir;
    if (h >= 6.5 && h < 15) {                       // matin : du minimum de la nuit au maximum du jour
        const x = (h - 6.5) / 8.5;
        tAir = g(TMIN, j - 1) + (g(TMAX, j) - g(TMIN, j - 1)) * Math.sin(Math.PI / 2 * x);
    } else {                                        // de 15 h au lendemain 6 h 30 : refroidissement
        const x = h >= 15 ? (h - 15) / 15.5 : (h + 9) / 15.5;
        const jj = h >= 15 ? j : j - 1;
        const c = (1 - Math.exp(-3 * x)) / (1 - Math.exp(-3));
        tAir = g(TMAX, jj) - (g(TMAX, jj) - g(TMIN, jj)) * c;
    }
    const jn = h >= 15 ? j : j - 1;                 // la nuit en cours / qui vient
    const clear = jn === 0;
    const par = (h > sunrise && h < sunset) ? 1100 * (clear ? 1 : 0.7) * Math.sin(Math.PI * (h - sunrise) / (sunset - sunrise)) : 0;
    return { tAir, par, td: g(TD, jn), night: h < sunrise || h >= sunset, sunrise, sunset, winter: true, clear, day };
}

let state = context.get("state") || {};
if (context.get("sim_version") !== 2) {             // mémoire d'avant les sols par zone (v1) : on repart
    state = {};
    context.set("sim_version", 2);
}
const irrigate = flow.get("irrigation_urgence") || null;              // bouton du dashboard
const out = [];

ticks.forEach((t, k) => {
    const w = weather(t);
    const d = new Date(t);
    const h = d.getUTCHours() + d.getUTCMinutes() / 60;
    const label = `${p2(d.getUTCDate())}/${p2(d.getUTCMonth() + 1)}/${d.getUTCFullYear()} ${p2(d.getUTCHours())}:${p2(d.getUTCMinutes())}`
                + (scenario === "frost" ? " (scénario gel)" : "");
    NODES.forEach((n, i) => {
        const s = state[n.id] || {
            sm: w.winter ? 0.92 * n.fc : (n.scenario === "irrigation_defaillante" ? n.wp + 0.45 * (n.fc - n.wp) : n.fc - 1) + rnd(0.6),
            tsol: w.winter ? 9 : 22, batt: 92 + rnd(5), seq: 0, stuck: 0, stuckValue: 0
        };
        if (s.tsol === undefined) s.tsol = 22;
        // air : écart de la zone (zone chaude le jour ; la nuit, bas-fond plus froid, zone haute plus douce)
        const dayOffset = n.scenario === "zone_chaude" ? 4 : (n.far ? 1.5 : 0);
        const offset = w.winter ? (w.night ? n.place : 0) : dayOffset;
        const tAir = w.tAir + offset + rnd(0.4);
        let rh;
        if (w.td !== null) rh = 100 * es(w.td) / es(tAir) + rnd(2);
        else rh = 95 - 1.9 * (tAir - 15) + rnd(2);
        rh = Math.min(100, Math.max(5, rh));
        const par = Math.max(0, w.par * (1 + rnd(0.05)));
        const vpd = es(tAir) * (1 - rh / 100);

        // eau du sol : évapotranspiration (faible en hiver), irrigation goutte-à-goutte à 06:00 en été
        const drying = w.winter ? 0.004 : 0.012 * (n.fc - n.wp) / 14 * (1 + 1.6 * Math.min(1, vpd / 3) + par / 1900);
        s.sm = Math.max(Math.max(3.5, n.wp - 6), s.sm - drying * (TICK_MINUTES / 10) * 10 / 10);
        if (!w.winter && h >= 6 && h < 6 + TICK_MINUTES / 60) {
            s.sm = n.scenario === "irrigation_defaillante" ? s.sm + 0.25 : n.fc + rnd(0.6);   // ligne fuyarde : apport dérisoire
        }
        if (irrigate === n.id) s.sm = n.fc;
        s.tsol = s.tsol + 0.08 * (tAir - 2 - s.tsol);
        s.batt = Math.min(100, Math.max(5, s.batt + (par > 600 ? 0.02 : -0.015)));
        s.seq += 1;

        let smRead = r1(s.sm + rnd(0.2));
        if (n.scenario === "sonde_sol_defaillante") {                    // valeurs impossibles ou figées
            if (s.stuck > 0) { smRead = s.stuckValue; s.stuck--; }
            else if (Math.random() < 0.03) smRead = [-1, 0, 101][Math.floor(Math.random() * 3)];
            else if (Math.random() < 0.012) { s.stuck = 12; s.stuckValue = smRead; }
        }
        // piézo : « clics » d'émission acoustique (cavitation) plus fréquents quand l'arbre a soif
        const deficit = Math.min(1, Math.max(0, (n.fc - s.sm) / (n.fc - n.wp)));
        const midday = h >= 11 && h < 16;
        let lambda = w.night ? 0.3 : (midday ? 1.0 : 0.8);
        if (!w.winter) lambda *= 1 + 5 * deficit * deficit + (tAir >= 35 ? 1.5 : 0);
        const rms = (w.night ? 3.4 : 5.4) * (1 + rnd(0.12)) + (midday ? 0.6 : 0);
        state[n.id] = s;

        const payload = {
            nodeId: n.id, orchardId: ORCHARD, zone: n.zone, cultivar: n.cultivar, age_years: n.age,
            trees: n.trees, tree_count: n.trees.length, soil: n.soil, field_cap: n.fc, wilting: n.wp,
            firmware: "1.3.0", seq: s.seq, timestamp: new Date(t).toISOString(),
            soil_moisture_pct: smRead,
            soil_temp_c:  Math.round(s.tsol * 16) / 16,                     // DS18B20 : pas de 0,0625 °C
            air_temp_c:   Math.max(0, Math.round(tAir)),                    // DHT11 : °C entiers, jamais sous 0
            humidity_pct: Math.min(90, Math.max(20, Math.round(rh))),       // DHT11 : 20 à 90 %
            light_par:    Math.round(par),
            light_adc:    Math.min(4095, Math.max(0, Math.round(4095 * (1 - Math.exp(-par / 250)) + (par > 0 ? rnd(20) : 0)))),
            vpd_kpa:      Math.round(vpd * 100) / 100,
            battery_pct:  r1(s.batt),
            rssi_dbm:     Math.round(-78 - (n.far ? 12 : 0) + rnd(6)),
            piezo_rms:    Math.round(rms * 100) / 100,
            piezo_events_h: poisson(lambda)
        };
        payload.checksum = checksum(payload);
        out.push({ topic: `farm/${ORCHARD}/${n.id}/telemetry`, payload,
                   lastOfTick: i === NODES.length - 1, simTime: label, backfill: ticks.length > 1 && k < ticks.length - 1 });
    });
});

context.set("clock", ticks[ticks.length - 1]);
if (irrigate) flow.set("irrigation_urgence", null);
context.set("state", state);
const last = new Date(ticks[ticks.length - 1]);
node.status({ fill: scenario === "frost" ? "blue" : "green", shape: "dot",
              text: `${p2(last.getUTCDate())}/${p2(last.getUTCMonth() + 1)} ${p2(last.getUTCHours())}:${p2(last.getUTCMinutes())} · ${scenario === "frost" ? "nuit de gel" : "été"}`
                    + (ticks.length > 1 ? ` · ${ticks.length} pas d'historique envoyés` : "") });
return [out];
