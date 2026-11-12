/**
 * LOOZ — settings of the farm gateway's Node-RED (this folder = its userDir).
 *
 * Start it FROM THIS FOLDER with:   node-red -u .
 *   - editor     http://127.0.0.1:1881
 *   - dashboard  http://127.0.0.1:1881/dashboard
 *
 * - Only THIS laptop can open it (uiHost 127.0.0.1): nobody on the Wi-Fi.
 * - The secrets (the gateway key) come from the file .env next to this one
 *   (never in flows.json, never in git). See .env.example.
 * - The memory of the flow (simulated clock, sensor history, readings
 *   waiting for Supabase) is saved on disk in context/: a restart continues
 *   where it stopped.
 */
const fs = require("fs");
const path = require("path");

// .env -> process.env (KEY=VALUE lines, # = comment). A value already set in
// the shell wins.
(function loadEnv() {
    const file = path.join(__dirname, ".env");
    if (!fs.existsSync(file)) {
        console.warn("[LOOZ] No .env file: copy .env.example to .env (the data will not reach Supabase).");
        return;
    }
    for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
        if (/^\s*#/.test(line)) continue;
        const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
        if (m && process.env[m[1]] === undefined) {
            process.env[m[1]] = m[2].replace(/^(['"])(.*)\1$/, "$2");
        }
    }
})();

module.exports = {
    flowFile: "flows.json",
    flowFilePretty: true,

    // This flow has no passwords (MQTT on localhost, the key comes from .env).
    credentialSecret: false,

    // Only this laptop. Port 1881 (PORT in .env), so it never fights with
    // another Node-RED on 1880.
    uiHost: "127.0.0.1",
    uiPort: Number(process.env.PORT) || 1881,

    // Keep the memory of the flow on disk (context/ folder).
    contextStorage: {
        default: { module: "localfilesystem" },
    },

    diagnostics: { enabled: false, ui: false },
    runtimeState: { enabled: false, ui: false },
    telemetry: { enabled: false, updateNotification: false },

    logging: {
        console: { level: "info", metrics: false, audit: false },
    },

    exportGlobalContextKeys: false,
    functionExternalModules: false,
    functionTimeout: 0,
    debugMaxLength: 1000,
    mqttReconnectTime: 15000,

    editorTheme: {
        projects: { enabled: false },
        tours: false,
    },
};
