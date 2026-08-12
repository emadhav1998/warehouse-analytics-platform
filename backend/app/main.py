from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from app.config import settings
from app.routers import inventory, kpis, labor, shipments, validation
from app.schemas.error_schema import ErrorDetail, ErrorResponse


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description="API for Warehouse Operations Analytics and KPI Governance",
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


@app.get("/health", tags=["Health"])
def health_check() -> dict[str, str]:
    return {"status": "healthy", "app": settings.app_name}
