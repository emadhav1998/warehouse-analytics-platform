from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api_docs import documented_responses
from app.database import get_db
from app.schemas.inventory_schema import InventoryAlert, WarehouseOption
from app.schemas.kpi_schema import InventorySummary


router = APIRouter()


@router.get("/warehouses", response_model=list[WarehouseOption], summary="List active warehouses", description="Returns active warehouse options for client filters.", response_description="Active warehouses ordered by name.", operation_id="list_warehouses", responses=documented_responses("Active warehouse options.", [{"warehouse_id": 1, "warehouse_code": "ATL-01", "warehouse_name": "Atlanta Distribution Center", "city_state": "Atlanta, GA"}]))
def get_warehouses(db: Session = Depends(get_db)) -> list[WarehouseOption]:
    query = text("""
        SELECT
            warehouse_id,
            warehouse_code,
            warehouse_name,
            city_state
        FROM mart.dim_warehouse
        WHERE is_active = 1
        ORDER BY warehouse_name
    """)
    rows = db.execute(query).mappings().all()
    return [WarehouseOption(**row) for row in rows]


@router.get("/summary", response_model=list[InventorySummary], summary="Summarize current inventory", description="Aggregates the latest inventory snapshot by warehouse, optionally for one warehouse.", response_description="Latest inventory totals by warehouse.", operation_id="get_inventory_summary", responses=documented_responses("Latest inventory totals by warehouse.", [{"warehouse_name": "Atlanta Distribution Center", "total_skus": 1280, "total_quantity": 48250, "total_value": 2450125.75, "stockout_count": 12, "reorder_count": 43}], validation=True))
def get_inventory_summary(
    warehouse_id: int | None = Query(default=None, gt=0, description="Positive warehouse ID; omit to return every warehouse.", examples=[1]),
    db: Session = Depends(get_db),
) -> list[InventorySummary]:
    query = text("""
        SELECT
            dw.warehouse_name,
            COUNT(DISTINCT fi.product_id) AS total_skus,
            COALESCE(SUM(fi.quantity_on_hand), 0) AS total_quantity,
            COALESCE(SUM(fi.inventory_value_at_cost), 0) AS total_value,
            COALESCE(SUM(CASE WHEN fi.stock_status = 'Out of Stock' THEN 1 ELSE 0 END), 0) AS stockout_count,
            COALESCE(SUM(fi.needs_reorder), 0) AS reorder_count
        FROM mart.fact_inventory fi
        JOIN mart.dim_warehouse dw ON fi.warehouse_key = dw.warehouse_key
        WHERE fi.date_key = (
            SELECT MAX(fi_latest.date_key)
            FROM mart.fact_inventory fi_latest
            WHERE (:wh_id IS NULL OR fi_latest.warehouse_id = :wh_id)
        )
          AND (:wh_id IS NULL OR fi.warehouse_id = :wh_id)
        GROUP BY dw.warehouse_name
        ORDER BY total_value DESC
        OPTION (RECOMPILE)
    """)
    rows = db.execute(query, {"wh_id": warehouse_id}).mappings().all()
    return [InventorySummary(**row) for row in rows]


@router.get("/alerts", response_model=list[InventoryAlert], summary="List inventory alerts", description="Returns the lowest-availability products that require reorder or are out of stock in the latest snapshot.", response_description="Prioritized replenishment alerts.", operation_id="list_inventory_alerts", responses=documented_responses("Prioritized replenishment alerts.", [{"warehouse": "Atlanta Distribution Center", "sku": "SKU-10042", "product": "Safety Gloves", "on_hand": 5, "available": 0, "status": "Out of Stock", "reorder_point": 20}], validation=True))
def get_inventory_alerts(
    warehouse_id: int | None = Query(default=None, gt=0, description="Positive warehouse ID; omit for all warehouses.", examples=[1]),
    limit: int = Query(default=50, ge=1, le=200, description="Maximum alerts to return (1–200).", examples=[50]),
    db: Session = Depends(get_db),
) -> list[InventoryAlert]:
    query = text("""
        SELECT TOP (:limit)
            dw.warehouse_name AS warehouse,
            dp.sku,
            dp.product_name AS product,
            fi.quantity_on_hand AS on_hand,
            fi.quantity_available AS available,
            fi.stock_status AS status,
            dp.reorder_point
        FROM mart.fact_inventory fi
        JOIN mart.dim_warehouse dw ON fi.warehouse_key = dw.warehouse_key
        JOIN mart.dim_product dp ON fi.product_key = dp.product_key
        WHERE fi.date_key = (
            SELECT MAX(fi_latest.date_key)
            FROM mart.fact_inventory fi_latest
            WHERE (:wh_id IS NULL OR fi_latest.warehouse_id = :wh_id)
        )
          AND (:wh_id IS NULL OR fi.warehouse_id = :wh_id)
          AND (fi.needs_reorder = 1 OR fi.stock_status = 'Out of Stock')
        ORDER BY fi.quantity_available ASC, dp.sku ASC
        OPTION (RECOMPILE)
    """)
    rows = db.execute(query, {"wh_id": warehouse_id, "limit": limit}).mappings().all()
    return [InventoryAlert(**row) for row in rows]
