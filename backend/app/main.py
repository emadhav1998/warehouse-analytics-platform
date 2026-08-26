from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from app.api_docs import documented_responses
from app.config import settings
from app.routers import inventory, kpis, labor, shipments, validation
from app.schemas.error_schema import ErrorDetail, ErrorResponse, HealthResponse


DESCRIPTION = """
Warehouse Operations Analytics API exposes governed inventory, shipment, labor,
and data-quality metrics from the SQL Server analytics mart.

## Conventions

* All routes are read-only and return JSON.
* Monetary values are expressed in USD unless the response says otherwise.
* KPI dashboard calculations use the latest inventory snapshot and a rolling
  30-day window for shipment and labor metrics.
* Invalid parameters return `422`; an unavailable analytics database returns
  `503` with a stable machine-readable error code.
"""

TAGS_METADATA = [
    {"name": "Health", "description": "API process readiness."},
    {"name": "KPIs", "description": "Governed KPI values and business definitions."},
    {"name": "Inventory", "description": "Warehouse inventory summaries and replenishment alerts."},
    {"name": "Shipments", "description": "Delivered-shipment carrier performance."},
    {"name": "Labor", "description": "Recent labor productivity by department and activity."},
    {"name": "Validation", "description": "Read-only analytics-mart data quality checks."},
]

app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description=DESCRIPTION,
    openapi_tags=TAGS_METADATA,
    contact={"name": "Data Analytics Team", "email": "analytics@company.com"},
    license_info={"name": "Proprietary"},
    debug=settings.debug,
)

allow_all_origins = settings.cors_origins == ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=not allow_all_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(kpis.router, prefix="/api/v1/kpis", tags=["KPIs"])
app.include_router(inventory.router, prefix="/api/v1/inventory", tags=["Inventory"])
app.include_router(shipments.router, prefix="/api/v1/shipments", tags=["Shipments"])
app.include_router(labor.router, prefix="/api/v1/labor", tags=["Labor"])
app.include_router(validation.router, prefix="/api/v1/validation", tags=["Validation"])


@app.exception_handler(SQLAlchemyError)
async def database_exception_handler(
    request: Request,
    exc: SQLAlchemyError,
) -> JSONResponse:
    error = ErrorResponse(
        error=ErrorDetail(
            code="database_unavailable",
            message="The analytics database is temporarily unavailable.",
        )
    )
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content=error.model_dump(),
    )


@app.get(
    "/health",
    tags=["Health"],
    response_model=HealthResponse,
    summary="Check API health",
    description="Confirms that the FastAPI process is running. This check does not query SQL Server.",
    response_description="The API process is healthy.",
    operation_id="check_health",
    responses=documented_responses(
        "The API process is healthy.",
        {"status": "healthy", "app": "Warehouse Analytics API"},
        database=False,
    ),
)
def health_check() -> dict[str, str]:
    return {"status": "healthy", "app": settings.app_name}
