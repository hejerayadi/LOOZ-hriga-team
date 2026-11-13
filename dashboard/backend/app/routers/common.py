"""Small helpers shared by the routers."""
from uuid import UUID

from fastapi import HTTPException, status


def uuid_or_404(value: str) -> str:
    """An id of the URL: not a UUID -> 404 at once (the database is not asked)."""
    try:
        return str(UUID(value))
    except ValueError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, {"code": "not_found", "message": "Unknown id"}) from None


def one_row(data) -> dict:
    """A function returning one row: PostgREST sends an object (or a list of one)."""
    if isinstance(data, list):
        return data[0] if data else {}
    return data or {}


def blank(text: str | None) -> str | None:
    """"" or spaces -> None (the database then keeps or skips the value)."""
    return text.strip() or None if text is not None else None


def not_found() -> HTTPException:
    return HTTPException(status.HTTP_404_NOT_FOUND, {"code": "not_found", "message": "Not found"})
