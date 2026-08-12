from contextlib import contextmanager

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import SQLAlchemyError

from app.database import get_db
from app.main import app


class FakeResult:
    def __init__(self, rows):
        self.rows = rows if isinstance(rows, list) else [rows]

    def mappings(self):
        return self

    def all(self):
        return self.rows

    def one(self):
        assert len(self.rows) == 1
        return self.rows[0]


class FakeSession:
    def __init__(self, rows):
        self.rows = rows
        self.calls = []

    def execute(self, statement, params=None):
        self.calls.append((str(statement), params or {}))
        return FakeResult(self.rows)


class FailingSession:
    def execute(self, statement, params=None):
        raise SQLAlchemyError("server and credentials must not leak")


@contextmanager
def override_database(session):
    def dependency_override():
        yield session

    app.dependency_overrides[get_db] = dependency_override
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


def test_labor_productivity_filters_and_response():
    session = FakeSession([
        {
            "department": "Operations",
            "activity_type": "Picking",
            "headcount": 8,
            "total_hours": 64.0,
            "total_units": 6400,
            "avg_uph": 100.0,
            "total_errors": 4,
            "total_cost": 1600.0,
        }
    ])
    with override_database(session) as client:
        response = client.get(
            "/api/v1/labor/productivity",
            params={"warehouse_id": 1, "department": " Operations "},
        )

    assert response.status_code == 200
    assert response.json()[0]["avg_uph"] == 100.0
    assert session.calls[0][1] == {"wh_id": 1, "department": "Operations"}
    assert "fl.department = :department" in session.calls[0][0]


@pytest.mark.parametrize(
    ("params", "invalid_field"),
    [
        ({"warehouse_id": 0}, "warehouse_id"),
        ({"department": "Operations; DROP TABLE x"}, "department"),
        ({"department": "   "}, "department"),
    ],
)
def test_labor_request_validation(params, invalid_field):
    with TestClient(app) as client:
        response = client.get("/api/v1/labor/productivity", params=params)

    assert response.status_code == 422
    assert invalid_field in response.text


def test_data_quality_report_failed_and_passed_checks():
    session = FakeSession(
        {
            "negative_inventory_quantities": 0,
            "inventory_balance_mismatches": 2,
            "orphan_inventory_keys": 0,
            "orphan_shipment_keys": 0,
            "orphan_labor_keys": 0,
            "invalid_labor_values": 0,
        }
    )
    with override_database(session) as client:
        response = client.get("/api/v1/validation/data-quality")

    body = response.json()
    assert response.status_code == 200
    assert body["status"] == "Failed"
    assert len(body["checks"]) == 6
    assert next(c for c in body["checks"] if c["failed_rows"] == 2)["status"] == "Failed"


def test_database_error_is_structured_and_sanitized():
    with override_database(FailingSession()) as client:
        response = client.get("/api/v1/labor/productivity")

    assert response.status_code == 503
    assert response.json() == {
        "error": {
            "code": "database_unavailable",
            "message": "The analytics database is temporarily unavailable.",
        }
    }
    assert "credentials" not in response.text


def test_openapi_includes_day19_routes_and_validation_responses():
    with TestClient(app) as client:
        schema = client.get("/openapi.json").json()

    assert "/api/v1/labor/productivity" in schema["paths"]
    assert "/api/v1/validation/data-quality" in schema["paths"]
    labor_responses = schema["paths"]["/api/v1/labor/productivity"]["get"]["responses"]
    assert "422" in labor_responses
