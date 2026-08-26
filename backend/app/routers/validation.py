from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api_docs import documented_responses
from app.database import get_db
from app.schemas.validation_schema import DataQualityCheck, DataQualityReport


router = APIRouter()

DATA_QUALITY_QUERY = text("""
    SELECT
        (SELECT COUNT(*) FROM mart.fact_inventory
         WHERE quantity_on_hand < 0 OR quantity_reserved < 0 OR quantity_available < 0)
            AS negative_inventory_quantities,
        (SELECT COUNT(*) FROM mart.fact_inventory
         WHERE quantity_on_hand <> quantity_reserved + quantity_available)
            AS inventory_balance_mismatches,
        (SELECT COUNT(*) FROM mart.fact_inventory fi
         LEFT JOIN mart.dim_warehouse dw ON fi.warehouse_key = dw.warehouse_key
         LEFT JOIN mart.dim_product dp ON fi.product_key = dp.product_key
         WHERE dw.warehouse_key IS NULL OR dp.product_key IS NULL)
            AS orphan_inventory_keys,
        (SELECT COUNT(*) FROM mart.fact_shipment fs
         LEFT JOIN mart.dim_warehouse dw ON fs.warehouse_key = dw.warehouse_key
         WHERE dw.warehouse_key IS NULL)
            AS orphan_shipment_keys,
        (SELECT COUNT(*) FROM mart.fact_labor fl
         LEFT JOIN mart.dim_warehouse dw ON fl.warehouse_key = dw.warehouse_key
         LEFT JOIN mart.dim_employee de ON fl.employee_key = de.employee_key
         WHERE dw.warehouse_key IS NULL OR de.employee_key IS NULL)
            AS orphan_labor_keys,
        (SELECT COUNT(*) FROM mart.fact_labor
         WHERE total_hours < 0 OR total_hours > 24 OR total_units < 0 OR total_errors < 0)
            AS invalid_labor_values
""")

CHECK_LABELS = {
    "negative_inventory_quantities": "Negative inventory quantities",
    "inventory_balance_mismatches": "Inventory balance mismatches",
    "orphan_inventory_keys": "Orphan inventory dimension keys",
    "orphan_shipment_keys": "Orphan shipment dimension keys",
    "orphan_labor_keys": "Orphan labor dimension keys",
    "invalid_labor_values": "Invalid labor values",
}


@router.get(
    "/data-quality",
    response_model=DataQualityReport,
    summary="Run mart data-quality checks",
    description="Runs six read-only integrity and range checks against inventory, shipment, and labor marts.",
    response_description="Overall result plus failed-row counts for every check.",
    operation_id="get_data_quality_report",
    responses=documented_responses("Current data-quality results.", {"status": "Passed", "checked_at": "2026-08-26T14:30:00Z", "checks": [{"check_name": "Negative inventory quantities", "failed_rows": 0, "status": "Passed"}]}),
)
def get_data_quality_report(db: Session = Depends(get_db)) -> DataQualityReport:
    result = db.execute(DATA_QUALITY_QUERY).mappings().one()
    checks = [
        DataQualityCheck(
            check_name=label,
            failed_rows=int(result[key] or 0),
            status="Passed" if int(result[key] or 0) == 0 else "Failed",
        )
        for key, label in CHECK_LABELS.items()
    ]
    return DataQualityReport(
        status="Passed" if all(check.status == "Passed" for check in checks) else "Failed",
        checked_at=datetime.now(timezone.utc),
        checks=checks,
    )
