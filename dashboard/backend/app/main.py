"""Entry point of the Looz admin API.

Start it (from the backend/ folder) with:
    uvicorn app.main:app --reload --port 8000
Then open http://localhost:8000/docs to see and try every route.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .routers import me

app = FastAPI(title="Looz Admin API")

# CORS: the browser only lets OUR dashboard (FRONTEND_URL) call this API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[get_settings().frontend_url],
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# One router per area (users, community, alerts... will be added here).
app.include_router(me.router)


@app.get("/api/health", tags=["health"])
def health() -> dict[str, str]:
    """Public check that the server is running (no login needed)."""
    return {"status": "ok"}
