"""Test helpers: a FAKE Supabase client (tables in memory), so the tests
never touch the real database and need no internet.

    cd dashboard/backend
    .venv\\Scripts\\Activate.ps1
    pip install -r requirements-dev.txt      (first time only)
    pytest
"""
import os
from types import SimpleNamespace

# Dummy settings: the real .env is never needed by these tests.
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "test-public-key")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "test-secret-key")
os.environ.setdefault("FRONTEND_URL", "http://localhost:3000")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.auth import CurrentAdmin, get_current_admin  # noqa: E402
from app.main import app  # noqa: E402
from app.schemas import Profile  # noqa: E402


class FakeQuery:
    """The few query methods of supabase-py the API uses."""

    def __init__(self, db: "FakeDB", table: str):
        if table not in db.tables:
            raise AssertionError(f"unknown table {table}")
        self.db, self.table = db, table
        self.rows = [dict(r) for r in db.tables[table]]
        self.columns: list[str] | None = None
        self.ordering: tuple[str, bool] | None = None
        self.window: tuple[int, int] | None = None
        self.max_rows: int | None = None

    def select(self, columns: str):
        if columns.strip() != "*":
            self.columns = [c.strip() for c in columns.split(",")]
            known = set().union(*(r.keys() for r in self.db.tables[self.table])) if self.db.tables[self.table] else None
            for c in self.columns:
                if known is not None and c not in known:
                    raise AssertionError(f"unknown column {self.table}.{c}")
        return self

    def eq(self, column, value):
        self.rows = [r for r in self.rows if r.get(column) == value]
        return self

    def in_(self, column, values):
        self.rows = [r for r in self.rows if r.get(column) in values]
        return self

    def gte(self, column, value):
        self.rows = [r for r in self.rows if r.get(column) is not None and str(r.get(column)) >= str(value)]
        return self

    def is_(self, column, value):
        assert value == "null"
        self.rows = [r for r in self.rows if r.get(column) is None]
        return self

    def order(self, column, desc=False):
        self.ordering = (column, desc)
        return self

    def range(self, start, end):
        self.window = (start, end)
        return self

    def limit(self, n):
        self.max_rows = n
        return self

    def execute(self):
        rows = self.rows
        if self.ordering:
            col, desc = self.ordering
            rows = sorted(rows, key=lambda r: (r.get(col) is None, r.get(col) or ""), reverse=desc)
        # Like Supabase: at most 1000 rows per answer.
        start, end = self.window or (0, 999)
        rows = rows[start : min(end, start + 999) + 1]
        if self.max_rows is not None:
            rows = rows[: self.max_rows]
        if self.columns:
            rows = [{c: r.get(c) for c in self.columns} for r in rows]
        self.db.calls.append(self.table)
        return SimpleNamespace(data=rows)


class FakeRpc:
    def __init__(self, db: "FakeDB", name: str, params: dict):
        self.db, self.name, self.params = db, name, params

    def execute(self):
        self.db.rpc_calls.append((self.name, self.params))
        handler = self.db.rpcs.get(self.name)
        if handler is None:
            raise AssertionError(f"unknown function {self.name}")
        return SimpleNamespace(data=handler(**self.params))


class FakeDB:
    """rpcs = {function name: python function(**params) -> data, or raises
    postgrest APIError like the database}."""

    def __init__(self, tables: dict[str, list[dict]], rpcs: dict | None = None):
        self.tables = tables
        self.rpcs = rpcs or {}
        self.calls: list[str] = []
        self.rpc_calls: list[tuple[str, dict]] = []

    def table(self, name: str) -> FakeQuery:
        return FakeQuery(self, name)

    def rpc(self, name: str, params: dict) -> FakeRpc:
        return FakeRpc(self, name, params)


def db_error(code: str, message: str):
    """The error postgrest raises when a database function refuses."""
    from postgrest.exceptions import APIError

    return APIError({"code": code, "message": message, "details": None, "hint": None})


ADMIN = Profile(id="ad000000-0000-4000-8000-000000000001", role="admin", name="Hajer", email="admin@example.com")
DEMO_ADMIN = Profile(id="ad000000-0000-4000-8000-000000000002", role="admin", name="Démo Admin",
                     email="admin-demo@looz-demo.invalid", demo_admin=True)


@pytest.fixture
def client_with():
    """client_with(tables, rpcs=None, demo=False) -> a TestClient where the
    logged-in admin's Supabase client is a FakeDB with these tables and
    database functions. demo=True: the demo admin ("Connexion démo")."""
    def make(tables, rpcs=None, demo=False):
        db = FakeDB(tables, rpcs)
        profile = DEMO_ADMIN if demo else ADMIN
        app.dependency_overrides[get_current_admin] = lambda: CurrentAdmin(profile=profile, db=db)
        client = TestClient(app)
        client.db = db
        return client

    yield make
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    """A TestClient with the REAL admin check (no override)."""
    app.dependency_overrides.clear()
    return TestClient(app)
