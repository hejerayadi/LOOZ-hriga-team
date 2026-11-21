# LOOZ — Node-RED of the farm gateway

The flow **Almond Smart Farm** (copied from the default Node-RED on 11 November 2026):

| Step | What it does |
| --- | --- |
| L1 | 4 simulated sensor boxes (ESP32), one per zone, with every raw channel of the ML models (soil %, DS18B20 soil °C, DHT11 air °C + %, 12-bit light, piezo RMS + clicks per hour) and the soil of each zone. **Frost-night scenario** (bloom, 18 → 19 February): the switch "Scénario : nuit de gel (floraison)" on the dashboard or `LOOZ_SCENARIO=frost` in `.env` (the clock jumps forward, 36 h of history sent at once). Boxes: **NODE-01 … NODE-04 in zones A … D**. Every 5 s = 15 simulated minutes (from 15 June 2026, 05:00). NODE-02: the irrigation line leaks. NODE-03: hot zone. NODE-04: faulty soil probe. |
| L2/L3 | The gateway checks each packet (checksum, ranges, sequence, stuck probe, battery, signal). |
| L4 | Memory of each box, water / heat stress (0–100), anomaly, level OK / INFO / WATCH / WARNING / CRITICAL / CAPTEUR (rules-v1), alert when the level changes. |
| L5 | Its own French dashboard: http://127.0.0.1:1881/dashboard |
| L6 | **Supabase**: each scored reading becomes codes (no sentences), waits in memory, and one batch per minute goes to the Edge Function `iot-ingest`. If Supabase does not answer, the readings wait (up to 5000) and leave with the next batch. |
| MQTT | Still published on the local Mosquitto (localhost:1883): `farm/VERGER-NORD/validated`, `farm/VERGER-NORD/<box>/health`, `farm/VERGER-NORD/alerts`. The input for real boxes (`farm/+/+/telemetry`) stays off. |

The zones are named **A to D** everywhere (here, in Supabase, in the admin dashboard and in the app).

## First time

```powershell
cd "D:\IEEE\aotn chalenge\AOTN-TSYP-chalenge\iot\node-red"
copy .env.example .env      # then fill in LOOZ_INGEST_URL and LOOZ_GATEWAY_KEY
npm install
```

The gateway key: Supabase › SQL Editor › `select public.iot_gateway_new_key('GW-01');` → paste the
`lgw_…` value after `LOOZ_GATEWAY_KEY=` in `.env`. A new key stops the old one at once.

## Start

```powershell
cd "D:\IEEE\aotn chalenge\AOTN-TSYP-chalenge\iot\node-red"
node-red -u .
```

- Editor: http://127.0.0.1:1881 — the node **Réponse Supabase** shows the last batch
  (`✓ 10:21:05 · 48 acceptée(s)`), or why it failed.
- Dashboard: http://127.0.0.1:1881/dashboard — line **Envoi à Supabase** in the Simulation group.
- Only this laptop can open them (`uiHost: 127.0.0.1` in `settings.js`).

Settings (`.env`): `LOOZ_BATCH_SECONDS=60` (20 for a demo in front of a jury), `PORT=1881`,
`LOOZ_TIME_MODE=demo`.

## Start again from zero

The memory of the flow (simulated clock, history, readings waiting) is in `context/`. To restart
the simulation on 15 June: stop Node-RED, delete the `context` folder, start again. Supabase then
starts the history of the 4 boxes again by itself (its clock went back).

## The code of the flow

The function nodes that matter are in `src/` (`simulator.js`, `gateway.js`, `rules.js`, `codes.js`): edit them there,
then `python tools/build_flows.py` (Node-RED stopped) writes them into `flows.json`. Test without Node-RED:
`node test/flow_test.js` (17 checks).

## Files

| File | In git |
| --- | --- |
| `flows.json`, `settings.js`, `package.json`, `.env.example`, this README | yes |
| `.env` (the key), `context/`, `node_modules/`, `.config.*.json`, `flows_cred.json` | **no** |
