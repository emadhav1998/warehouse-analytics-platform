from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import inventory, kpis, shipments


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


@app.get("/health", tags=["Health"])
def health_check() -> dict[str, str]:
    return {"status": "healthy", "app": settings.app_name}

