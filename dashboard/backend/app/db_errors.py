"""When a checked database function (migration 013) refuses an action.

The database answers in English, for developers ("Reason: 3 to 300
letters"). The API sends back a short CODE with it; the dashboard shows the
French text of that code (frontend lib/labels.ts, ACTION_ERROR):

    {"detail": {"code": "reason", "message": "Reason: 3 to 300 letters"}}
"""
from contextlib import contextmanager

import httpx
from fastapi import HTTPException, status
from postgrest.exceptions import APIError

# (start of the database message, code, HTTP status). The first match wins.
MESSAGES: list[tuple[str, str, int]] = [
    ("Reason:", "reason", 422),
    ("Device code:", "device_code", 422),
    ("The device code", "device_code_taken", 409),
    ("Give the device code", "device_code_missing", 422),
    ("Not with the demo admin account", "demo_not_allowed", 403),
    ("The demo admin acts only on demo", "demo_only", 403),
    ("Admins only", "admin_only", 403),
    ("Unknown box (or its zone was removed)", "box_zone_removed", 404),
    ("Unknown", "not_found", 404),
    ("This visit is closed", "visit_closed", 409),
    ("Status:", "visit_status", 422),
    ("Note:", "note", 422),
]

# When the message is not in the list: by Postgres error code.
CODES: dict[str, tuple[str, int]] = {
    "42501": ("forbidden", 403),
    "22023": ("invalid", 422),
    "P0002": ("not_found", 404),
    "23505": ("conflict", 409),
    "PT429": ("too_many", 429),
}


def http_error(error: APIError) -> HTTPException:
    message = error.message or ""
    for start, code, http_status in MESSAGES:
        if message.startswith(start):
            return HTTPException(http_status, {"code": code, "message": message})
    code, http_status = CODES.get(error.code or "", ("database", 502))
    return HTTPException(http_status, {"code": code, "message": message})


@contextmanager
def checked_call():
    """Runs a database call; its refusals become clear API errors."""
    try:
        yield
    except APIError as e:
        raise http_error(e) from None
    except httpx.HTTPError:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Supabase unreachable") from None
