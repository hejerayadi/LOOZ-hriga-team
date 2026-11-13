"""Entry point of the Looz admin API.

Start it (from the backend/ folder) with:
    uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
(127.0.0.1 = this computer only: nobody on the network can reach it.)
Then open http://127.0.0.1:8000/docs to see and try every route.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .routers import admin_settings, alerts, community, demo_login, farmers, me, orchards, overview, sensors, users

app = FastAPI(title="Looz Admin API")

# CORS: the browser only lets OUR dashboard (FRONTEND_URL, opened with
# localhost or 127.0.0.1) call this API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origins,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# One router per area of the dashboard.
app.include_router(me.router)
app.include_router(demo_login.router)
app.include_router(overview.router)
app.include_router(farmers.router)
app.include_router(sensors.router)
app.include_router(users.router)
app.include_router(community.router)
app.include_router(alerts.router)
app.include_router(orchards.router)
app.include_router(admin_settings.router)


@app.get("/api/health", tags=["health"])
def health() -> dict[str, str]:
    """Public check that the server is running (no login needed)."""
    return {"status": "ok"}
