from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.shipment_schema import ShipmentPerformance


router = APIRouter()


@router.get("/performance", response_model=list[ShipmentPerformance])
def get_shipment_performance(
    days: int = Query(default=30, ge=1, le=365, description="Number of days to look back"),
    warehouse_id: int | None = Query(default=None, gt=0),
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

