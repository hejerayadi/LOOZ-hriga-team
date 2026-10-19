"""Settings of the API, read from the .env file (never written in the code)."""
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# backend/.env — found the same way wherever you start the server from.
ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ENV_FILE, extra="ignore")

    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    frontend_url: str = "http://localhost:3000"


@lru_cache
def get_settings() -> Settings:
    """Reads the .env file once, then reuses the same settings."""
    return Settings()
