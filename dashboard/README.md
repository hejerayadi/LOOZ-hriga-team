# Looz — Admin dashboard

| Folder      | What it is                                   | Address                 |
| ----------- | -------------------------------------------- | ----------------------- |
| `backend/`  | FastAPI (Python) — the API, checks admins    | http://localhost:8000   |
| `frontend/` | Next.js + Tailwind — the website for admins  | http://localhost:3000   |

The frontend uses Supabase **only to log in**. All the data goes through the
backend, which checks that the user is an admin (`profiles.role = 'admin'`)
and queries Supabase with the user's token, so the RLS rules still apply.

## First time only

1. `backend/.env` and `frontend/.env.local`: fill in the Supabase values
   (see the `.env.example` next to each). The `service_role` key goes ONLY
   in `backend/.env`.
2. Make one admin: in Supabase > Table Editor > `profiles`, set
   `role = admin` on your user.

## Start (two terminals, PowerShell)

Terminal 1 — backend:

```powershell
cd dashboard\backend
python -m venv .venv                 # first time only
.venv\Scripts\Activate.ps1
pip install -r requirements.txt      # first time only
uvicorn app.main:app --reload --port 8000
```

Terminal 2 — frontend:

```powershell
cd dashboard\frontend
npm install                          # first time only
npm run dev
```

Open http://localhost:3000. API docs: http://localhost:8000/docs
