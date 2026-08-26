from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api_docs import documented_responses
from app.database import get_db
from app.schemas.shipment_schema import ShipmentPerformance


router = APIRouter()


@router.get(
    "/performance",
    response_model=list[ShipmentPerformance],
    summary="Analyze carrier performance",
    description="Aggregates delivered shipments by carrier over a configurable rolling window.",
    response_description="Carrier shipment volume, cost, transit time, and OTD rate.",
    operation_id="get_shipment_performance",
    responses=documented_responses("Carrier performance metrics.", [{"carrier": "UPS", "total_shipments": 320, "on_time": 305, "late": 15, "avg_transit_days": 2.75, "total_cost": 8125.5, "avg_cost": 25.39, "otd_rate": 95.31}], validation=True),
)
def get_shipment_performance(
    days: int = Query(default=30, ge=1, le=365, description="Rolling lookback window in days (1–365).", examples=[30]),
    warehouse_id: int | None = Query(default=None, gt=0, description="Positive warehouse ID; omit for all warehouses.", examples=[1]),
    db: Session = Depends(get_db),
) -> list[ShipmentPerformance]:
    query = text("""
        SELECT
            carrier,
            COUNT(*) AS total_shipments,
            SUM(CASE WHEN delivery_performance = 'On Time' THEN 1 ELSE 0 END) AS on_time,
            SUM(CASE WHEN delivery_performance = 'Late' THEN 1 ELSE 0 END) AS late,
            COALESCE(AVG(CAST(actual_transit_days AS DECIMAL(8, 2))), 0) AS avg_transit_days,
            COALESCE(SUM(shipping_cost), 0) AS total_cost,
            COALESCE(AVG(shipping_cost), 0) AS avg_cost
        FROM mart.fact_shipment
        WHERE date_key >= DATEADD(DAY, :lookback_days, CAST(GETDATE() AS date))
          AND status = 'Delivered'
          AND (:wh_id IS NULL OR warehouse_id = :wh_id)
        GROUP BY carrier
        ORDER BY total_shipments DESC
        OPTION (RECOMPILE)
    """)
    rows = db.execute(
        query,
        {"lookback_days": -days, "wh_id": warehouse_id},
    ).mappings().all()
    return [
        ShipmentPerformance(
            **row,
            otd_rate=round(int(row["on_time"] or 0) / max(int(row["total_shipments"]), 1) * 100, 2),
        )
        for row in rows
    ]
