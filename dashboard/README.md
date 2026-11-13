# Looz — Admin dashboard

| Folder      | What it is                                   | Address                 |
| ----------- | -------------------------------------------- | ----------------------- |
| `backend/`  | FastAPI (Python) — the API, checks admins    | http://127.0.0.1:8000   |
| `frontend/` | Next.js + Tailwind — the website for admins  | http://127.0.0.1:3000   |

Both listen on **127.0.0.1 only**: nobody on the network can open them.

The frontend uses Supabase **only to log in**. All the data goes through the
backend, which checks that the user is an admin (`profiles.role = 'admin'`)
and queries Supabase with the user's token, so the RLS rules still apply.
Every **change** (accept a box, expert badge, hide a post, regional alert,
price, setting...) calls one checked database function of migration 013 with
the admin's own token: the database checks the rules and writes a line in the
**admin action log** (who, what, when, on what, why). The `service_role` key is
never used for it. With migration 014, the database also keeps the demo
admin ("Connexion démo") on demo data.

## First time only

1. `backend/.env` and `frontend/.env.local`: fill in the Supabase values
   (see the `.env.example` next to each). The `service_role` key goes ONLY
   in `backend/.env`.
2. Make one admin: in Supabase > Table Editor > `profiles`, set
   `role = admin` on your user (roles are never changed from the dashboard).
3. Optional, **"Connexion démo"** (one click, demo accounts only, for the jury and
   the screenshots): `PROJECT_STATUS.md` section 14.

## Start (two terminals, PowerShell)

Terminal 1 — backend:

```powershell
cd dashboard\backend
python -m venv .venv                 # first time only
.venv\Scripts\Activate.ps1
pip install -r requirements.txt      # first time only
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Terminal 2 — frontend:

```powershell
cd dashboard\frontend
npm install                          # first time only
npm run dev                          # = next dev -H 127.0.0.1
```

Open http://127.0.0.1:3000 (or http://localhost:3000). API docs: http://127.0.0.1:8000/docs

After a change in `backend/.env` (for example `DEMO_ADMIN_PASSWORD`), stop the backend (Ctrl+C)
and start it again: `.env` is read only at start.

The dashboard is in **French**. Pages:

- **Vue d'ensemble**: key numbers (farmers, boxes, experts, orchards, regional alerts,
  community, demo payments of the month, installation visits) and the "À faire" list.
- **Agriculteurs** and a farmer's page: orchard plan, gateway (new key, on / off), every box
  live ("Accepter l'installation" / "Retirer"), installation visit, charts of the last 3 days,
  alert log, sensor problems (14 days), admin actions.
- **Utilisateurs**: every account (search, filters), an account's page, the expert badge
  ("Vérifier"), "Bloquer / Débloquer".
- **Communauté**: every post (hidden ones too), a post's page (photo, every answer), "Masquer /
  Afficher de nouveau / Supprimer" with a reason, the reports, the log.
- **Alertes**: regional alerts in Arabic and French (with the preview of the app's screen),
  the sensor alerts of every orchard.
- **Vergers** (read only): every orchard and its plan.
- **Capteurs**: every box (the waiting ones first), the waiting list, the installation visits,
  the gateways, the log of the actions.
- **Abonnements**: packs with their bill, payments, the price of a box, "hectares par boîtier".
- **Réglages**: the switches (each with a warning and a confirmation).
- **Journal des actions**: every admin action, 100 lines at a time.

The data of the boxes comes from Node-RED (`iot/node-red`), see `PROJECT_STATUS.md` section 12.

## Tests (backend)

```powershell
cd dashboard\backend
.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt     # first time only
pytest                                   # no internet: fake tables
pytest tests_live -v                     # REAL Supabase, Node-RED running
```

`pytest tests_live` needs two lines in `backend/.env` (never in git), else it is skipped:
`LIVE_ADMIN_EMAIL=...` and `LIVE_ADMIN_PASSWORD=...` (the admin login of the dashboard).
You may remove them after the test. **The milestones change demo data and put it back**
(each line stays in the admin action log): NODE-04 removed then accepted again (A), the demo
expert 22 123 458 verified (she stays verified) and a demo post hidden then shown again (B), a
heat alert for Sfax created then ended (C), the price 8 → 9 DT then back to 8 DT (D). The app
users are logged in with the app's demo login (it must be on). `test_live_014.py` only reads
(skipped before migration 014). The "Connexion démo" checks are skipped while its switch is off.

Frontend: `npx tsc --noEmit`, `npm run lint`, `npm run build` (from `dashboard/frontend`).
