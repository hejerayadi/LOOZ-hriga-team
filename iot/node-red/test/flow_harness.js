// Runs the flow's main functions OUTSIDE Node-RED (no MQTT, no dashboard, no Supabase):
//   simulator -> gateway (checks) -> rules-v1 (levels) -> codes for Supabase
// with the same code as flows.json (src/*.js). Used by test/flow_test.js and to make
// histories for the ML tests:
//   node test/flow_harness.js <summer|frost> <ticks> <out.json> [seed]
const fs = require("fs");
const path = require("path");

const SRC = path.join(__dirname, "..", "src");

function seeded(seed) {                     // a small PRNG (mulberry32): the same run every time
    let a = seed >>> 0;
    return () => {
        a = (a + 0x6D2B79F5) >>> 0;
        let t = a;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

function store() {
    const m = new Map();
    return { get: k => m.get(k), set: (k, v) => m.set(k, v), keys: () => [...m.keys()] };
}

function makeFn(file) {
    const code = fs.readFileSync(path.join(SRC, file), "utf8");
    // eslint-disable-next-line no-new-func
    return new Function("msg", "context", "flow", "env", "node", code);
}

class Flow {
    constructor(envVars = {}) {
        this.flow = store();
        this.env = { get: k => envVars[k] };
        this.ctx = { sim: store(), gw: store(), rules: store(), codes: store() };
        this.status = {};
        this.warnings = [];
        this.fns = { sim: makeFn("simulator.js"), gw: makeFn("gateway.js"), rules: makeFn("rules.js"), codes: makeFn("codes.js") };
        this.events = [];
    }
    node(name) {
        return { status: s => { this.status[name] = s; }, warn: w => this.warnings.push(`${name}: ${w}`) };
    }
    call(name, msg) {
        return this.fns[name](msg, this.ctx[name], this.flow, this.env, this.node(name));
    }
    tick() {
        const out = this.call("sim", { payload: Date.now() });
        if (!out) return 0;
        for (const m of out[0]) {
            const gw = this.call("gw", JSON.parse(JSON.stringify(m)));
            if (!gw || !gw[0]) continue;
            const r = this.call("rules", gw[0]);
            if (r && r[1]) this.events.push(r[1].payload);
            if (r && r[0]) this.call("codes", r[0]);
        }
        return out[0].length;
    }
    buffer() { return this.flow.get("supabase_buffer") || []; }
}

module.exports = { Flow, seeded };

if (require.main === module) {
    const [scenario = "summer", n = "200", out = "readings.json", seed = "7"] = process.argv.slice(2);
    Math.random = seeded(Number(seed));
    const f = new Flow({ LOOZ_SCENARIO: scenario, LOOZ_TIME_MODE: "demo" });
    for (let i = 0; i < Number(n); i++) f.tick();
    fs.writeFileSync(out, JSON.stringify(f.buffer()));
    console.log(`${f.buffer().length} readings, ${f.events.length} alert events, status: ${f.status.sim && f.status.sim.text}`);
}
