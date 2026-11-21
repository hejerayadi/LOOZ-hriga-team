// Offline test of the flow's code (src/*.js = flows.json): node test/flow_test.js
const assert = require("assert");
const { Flow, seeded } = require("./flow_harness");

let passed = 0;
function check(name, fn) {
    fn();
    passed++;
    console.log("PASS " + name);
}
const iso = t => new Date(t).toISOString();
const local = r => new Date(Date.parse(r.measured_at) + 3600000);           // Tunisia time

Math.random = seeded(11);

// ---------- summer (default) ----------
const f = new Flow({ LOOZ_TIME_MODE: "demo" });
f.tick();
let buf = f.buffer();
check("first start: 36 h of history at once (145 steps x 4 boxes)", () => assert.strictEqual(buf.length, 145 * 4));
check("the clock: 15 June 2026 05:00 (Tunisia time)", () => {
    assert.strictEqual(iso(f.ctx.sim.get("clock")), "2026-06-15T05:00:00.000Z");
    assert.strictEqual(buf[buf.length - 1].measured_at, "2026-06-15T04:00:00.000Z");     // sent as real UTC
});
check("every reading has the raw channels of the models", () => {
    for (const r of buf) {
        for (const k of ["soil_moisture_pct", "soil_temp_c", "air_temp_c", "humidity_pct", "light_adc", "piezo_rms", "piezo_events_h"])
            assert.ok(typeof r[k] === "number", k);
        assert.ok(Number.isInteger(r.air_temp_c) && r.air_temp_c >= 0, "DHT11: whole degrees, never below 0");
        assert.ok(Number.isInteger(r.humidity_pct) && r.humidity_pct >= 20 && r.humidity_pct <= 90, "DHT11 20..90 %");
        assert.ok(Number.isInteger(r.soil_temp_c * 16), "DS18B20: steps of 1/16 °C");
        assert.ok(r.light_adc >= 0 && r.light_adc <= 4095 && Number.isInteger(r.light_adc), "12-bit light");
        assert.ok(Number.isInteger(r.piezo_events_h) && r.piezo_events_h >= 0, "piezo events");
    }
});
check("light: dark at night, saturated at noon", () => {
    const night = buf.filter(r => local(r).getUTCHours() === 2), noon = buf.filter(r => local(r).getUTCHours() === 13);
    assert.ok(night.every(r => r.light_adc === 0) && noon.every(r => r.light_adc >= 3900));
});
for (let i = 0; i < 300; i++) f.tick();
buf = f.buffer();
const last = dev => buf.filter(r => r.device === dev);
check("then 4 readings per step, the clock goes on 15 min a step", () => {
    assert.strictEqual(buf.length, (145 + 300) * 4);
    assert.strictEqual(iso(f.ctx.sim.get("clock")), iso(Date.UTC(2026, 5, 15, 5, 0) + 300 * 15 * 60000));
});
check("NODE-01 (sandy loam, watered at 06:00): soil between 20 and 26 %", () => {
    const sm = last("NODE-01").slice(-96).map(r => r.soil_moisture_pct);
    assert.ok(Math.min(...sm) > 19 && Math.max(...sm) < 26.5, `${Math.min(...sm)} ${Math.max(...sm)}`);
});
check("NODE-02 (leaking line): below the wilting point (11 %) after 3 days, level critical", () => {
    const r = last("NODE-02").slice(-1)[0];
    assert.ok(r.soil_moisture_pct < 11, r.soil_moisture_pct);
    assert.ok(last("NODE-02").some(x => x.level === "critical"));
});
check("NODE-03 (hot zone): hours at 35 °C and more every day", () => {
    const hot = last("NODE-03").slice(-96).filter(r => r.air_temp_c >= 35).length;
    assert.ok(hot >= 16, hot);                                                   // >= 4 h (16 steps of 15 min)
});
check("NODE-04 (faulty probe): readings flagged 'sensor'", () => {
    assert.ok(last("NODE-04").some(r => r.level === "sensor"));
    assert.ok(last("NODE-04").some(r => r.faults.length > 0));
});
check("trees under water stress: more piezo clicks (NODE-02) than watered trees (NODE-01)", () => {
    const sum = dev => last(dev).slice(-96).reduce((s, r) => s + r.piezo_events_h, 0);
    assert.ok(sum("NODE-02") > 1.5 * sum("NODE-01"), `${sum("NODE-02")} vs ${sum("NODE-01")}`);
});

// ---------- the frost-night scenario ----------
const before = f.ctx.sim.get("clock");
f.flow.set("scenario", "frost");
const n0 = f.buffer().length;
f.tick();
check("frost switch: the clock goes FORWARD to 18 February 18:00, with 36 h of history", () => {
    assert.strictEqual(iso(f.ctx.sim.get("clock")), "2027-02-18T18:00:00.000Z");
    assert.ok(f.ctx.sim.get("clock") > before);
    assert.strictEqual(f.buffer().length - n0, 145 * 4);
});
for (let i = 0; i < 60; i++) f.tick();                                          // to 19 February 09:00
const frost = f.buffer().slice(n0);
const at = (dev, hh) => frost.filter(r => r.device === dev && local(r).getUTCDate() === 19 && local(r).getUTCHours() === hh);
check("the frost night: the low spot (zone D) reads 0 °C at 4 h, the high zone (C) stays above", () => {
    assert.ok(at("NODE-04", 4).every(r => r.air_temp_c === 0), JSON.stringify(at("NODE-04", 4).map(r => r.air_temp_c)));
    assert.ok(at("NODE-03", 4).every(r => r.air_temp_c >= 1));
});
check("dry air that night (humidity under 75 % in the evening)", () => {
    const eve = frost.filter(r => r.device === "NODE-01" && local(r).getUTCDate() === 18 && local(r).getUTCHours() === 20);
    assert.ok(eve.every(r => r.humidity_pct < 75), JSON.stringify(eve.map(r => r.humidity_pct)));
});
check("winter: no irrigation, the soil stays moist", () => {
    assert.ok(frost.filter(r => r.device === "NODE-01").every(r => r.soil_moisture_pct > 20));
});
f.flow.set("scenario", "summer");
f.tick();
check("back to summer: the clock goes forward again (15 June 2027)", () =>
    assert.strictEqual(iso(f.ctx.sim.get("clock")), "2027-06-15T05:00:00.000Z"));

// ---------- an old memory (before this version) ----------
const old = new Flow({ LOOZ_TIME_MODE: "demo" });
old.ctx.sim.set("clock", Date.UTC(2026, 5, 20, 10, 0));
old.ctx.sim.set("state", { "NODE-01": { sm: 33, tsol: 25, batt: 90, seq: 77 } });
old.tick();
check("a memory of the old version: the clock goes on (no jump, no history), the soil starts again", () => {
    assert.strictEqual(old.buffer().length, 4);
    assert.strictEqual(iso(old.ctx.sim.get("clock")), "2026-06-20T10:15:00.000Z");
    assert.ok(old.buffer()[0].soil_moisture_pct < 27);
});
old.flow.set("simulation_active", false);
check("paused: nothing", () => { assert.strictEqual(old.tick(), 0); });

console.log(`\n${passed} / ${passed} checks pass`);
