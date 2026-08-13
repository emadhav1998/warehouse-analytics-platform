from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.inventory_schema import InventoryAlert, WarehouseOption
from app.schemas.kpi_schema import InventorySummary


router = APIRouter()


@router.get("/warehouses", response_model=list[WarehouseOption])
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


@router.get("/summary", response_model=list[InventorySummary])
def get_inventory_summary(
    warehouse_id: int | None = Query(default=None, gt=0),
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
    """)
    rows = db.execute(query, {"wh_id": warehouse_id}).mappings().all()
    return [InventorySummary(**row) for row in rows]


@router.get("/alerts", response_model=list[InventoryAlert])
def get_inventory_alerts(
    warehouse_id: int | None = Query(default=None, gt=0),
    limit: int = Query(default=50, ge=1, le=200),
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
    """)
    rows = db.execute(query, {"wh_id": warehouse_id, "limit": limit}).mappings().all()
    return [InventoryAlert(**row) for row in rows]
