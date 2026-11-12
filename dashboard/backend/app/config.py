"""Settings of the API, read from the .env file (never written in the code)."""
from functools import lru_cache
from pathlib import Path
from urllib.parse import urlsplit

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

# backend/.env — found the same way wherever you start the server from.
ENV_FILE = Path(__file__).resolve().parent.parent / ".env"

# The demo admin (migration 013: an admin whose e-mail ends like this).
DEMO_ADMIN_DOMAIN = "@looz-demo.invalid"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ENV_FILE, extra="ignore")

    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    frontend_url: str = "http://localhost:3000"
    # true = talk to Supabase over IPv4 only. For a network where IPv6 is
    # broken: Python then waits about 40 s on every call before falling
    # back to IPv4 (seen on 11 November 2026). Harmless when IPv4 works.
    supabase_ipv4_only: bool = False
    # "Connexion démo" of the dashboard: the backend logs in with this
    # account. The password stays HERE (never in the browser, never in git).
    # The button also needs the switch app_settings.demo_admin_login_enabled.
    demo_admin_email: str = "admin-demo" + DEMO_ADMIN_DOMAIN
    demo_admin_password: SecretStr = SecretStr("")

    @property
    def cors_origins(self) -> list[str]:
        """FRONTEND_URL, and the same address with localhost <-> 127.0.0.1
        (the dashboard is opened with either)."""
        url = self.frontend_url.rstrip("/")
        parts = urlsplit(url)
        twin = {"localhost": "127.0.0.1", "127.0.0.1": "localhost"}.get(parts.hostname or "")
        origins = [url]
        if twin:
            netloc = twin + (f":{parts.port}" if parts.port else "")
            origins.append(f"{parts.scheme}://{netloc}")
        return origins

    @property
    def demo_login_configured(self) -> bool:
        return bool(self.demo_admin_email and self.demo_admin_password.get_secret_value())


@lru_cache
def get_settings() -> Settings:
    """Reads the .env file once, then reuses the same settings."""
    return Settings()
