"""Reusable OpenAPI response documentation for API routes."""

from typing import Any

from app.schemas.error_schema import ErrorResponse


DATABASE_ERROR_EXAMPLE = {
    "error": {
        "code": "database_unavailable",
        "message": "The analytics database is temporarily unavailable.",
    }
}

VALIDATION_ERROR_EXAMPLE = {
    "detail": [
        {
            "type": "greater_than",
            "loc": ["query", "warehouse_id"],
            "msg": "Input should be greater than 0",
            "input": "0",
            "ctx": {"gt": 0},
        }
    ]
}


def documented_responses(
    success_description: str,
    success_example: Any,
    *,
    validation: bool = False,
    database: bool = True,
) -> dict[int, dict[str, Any]]:
    """Build a fresh response map so route decorators cannot share mutable state."""
    responses: dict[int, dict[str, Any]] = {
        200: {
            "description": success_description,
            "content": {"application/json": {"example": success_example}},
        }
    }
    if validation:
        responses[422] = {
            "description": "A query parameter failed validation.",
            "content": {"application/json": {"example": VALIDATION_ERROR_EXAMPLE}},
        }
    if database:
        responses[503] = {
            "model": ErrorResponse,
            "description": "The analytics database could not be reached.",
            "content": {"application/json": {"example": DATABASE_ERROR_EXAMPLE}},
        }
    return responses
