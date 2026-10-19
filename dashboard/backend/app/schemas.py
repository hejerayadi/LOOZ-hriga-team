"""Shapes of the data the API sends back (same columns as the database)."""
from datetime import datetime

from pydantic import BaseModel


class Profile(BaseModel):
    """One row of the "profiles" table, plus the login e-mail."""

    id: str
    role: str
    name: str
    email: str | None = None
    phone: str | None = None
    language: str | None = None
    zone: str | None = None
    farm_name: str | None = None
    speciality: str | None = None
    verified: bool | None = None
    created_at: datetime | None = None
