from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api_docs import documented_responses
from app.database import get_db
from app.schemas.kpi_schema import KPIDashboard, KPIDefinition, KPIValue
from app.services.kpi_catalog import KPI_DEFINITIONS


router = APIRouter()


INVENTORY_KPI_QUERY = text("""
    WITH latest_date AS (
        SELECT MAX(date_key) AS date_key
        FROM mart.fact_inventory
        WHERE (:wh_id IS NULL OR warehouse_id = :wh_id)
    ),
    daily_inventory AS (
        SELECT
            date_key,
            SUM(quantity_on_hand) AS daily_quantity
        FROM mart.fact_inventory
        WHERE (:wh_id IS NULL OR warehouse_id = :wh_id)
          AND date_key >= DATEADD(MONTH, -1, CAST(GETDATE() AS date))
        GROUP BY date_key
    )
    SELECT
        MAX(dw.warehouse_name) AS warehouse_name,
        COALESCE(SUM(fi.inventory_value_at_cost), 0) AS total_value,
        COALESCE(SUM(CASE WHEN fi.stock_status = 'Out of Stock' THEN 1 ELSE 0 END), 0) AS stockout_count,
        COUNT(*) AS total_records,
        COALESCE(SUM(CASE WHEN fi.needs_reorder = 1 THEN 1 ELSE 0 END), 0) AS reorder_count,
        COALESCE(SUM(CASE
            WHEN fi.quantity_on_hand = fi.quantity_reserved + fi.quantity_available THEN 1
            ELSE 0
        END), 0) AS accurate_count,
        COALESCE(SUM(fi.quantity_on_hand), 0) AS quantity_on_hand,
        COALESCE((SELECT AVG(CAST(daily_quantity AS DECIMAL(19, 4))) FROM daily_inventory), 0)
            AS average_daily_quantity,
        MAX(fi.date_key) AS as_of_date
    FROM mart.fact_inventory fi
    JOIN mart.dim_warehouse dw ON fi.warehouse_key = dw.warehouse_key
    CROSS JOIN latest_date ld
    WHERE fi.date_key = ld.date_key
      AND (:wh_id IS NULL OR fi.warehouse_id = :wh_id)
    OPTION (RECOMPILE)
""")

SHIPMENT_KPI_QUERY = text("""
    SELECT
        COALESCE(
            SUM(CASE
                WHEN status = 'Delivered' AND delivery_performance = 'On Time' THEN 1.0
                ELSE 0
            END) * 100.0
            / NULLIF(SUM(CASE WHEN status = 'Delivered' THEN 1.0 ELSE 0 END), 0),
            0
        ) AS otd_rate,
        COUNT(*) AS total_shipments,
        COALESCE(SUM(shipping_cost), 0) AS total_shipping_cost,
        COALESCE(SUM(CASE WHEN status = 'Cancelled' THEN 1.0 ELSE 0 END), 0) AS cancelled_shipments,
        COALESCE(AVG(CASE
            WHEN status = 'Delivered' THEN CAST(actual_transit_days AS DECIMAL(8, 2))
        END), 0) AS avg_transit
    FROM mart.fact_shipment
    WHERE date_key >= DATEADD(MONTH, -1, CAST(GETDATE() AS date))
      AND (:wh_id IS NULL OR warehouse_id = :wh_id)
    OPTION (RECOMPILE)
""")

LABOR_KPI_QUERY = text("""
    SELECT
        COALESCE(SUM(total_units) / NULLIF(SUM(total_hours), 0), 0) AS avg_uph,
        COALESCE(SUM(labor_cost), 0) AS total_labor_cost,
        COALESCE(SUM(total_errors) * 100.0 / NULLIF(SUM(total_units), 0), 0) AS error_rate,
        COALESCE(SUM(labor_cost) / NULLIF(SUM(total_units), 0), 0) AS cost_per_unit
    FROM mart.fact_labor
    WHERE date_key >= DATEADD(MONTH, -1, CAST(GETDATE() AS date))
      AND (:wh_id IS NULL OR warehouse_id = :wh_id)
    OPTION (RECOMPILE)
""")


def _rag_status(value: float, target: float | None, lower_is_better: bool = False) -> str | None:
    if target is None:
        return None
    if lower_is_better:
        if value <= target:
            return "Green"
        return "Yellow" if value <= target * 1.5 else "Red"
    if value >= target:
        return "Green"
    return "Yellow" if value >= target * 0.9 else "Red"


@router.get(
    "/dashboard",
    response_model=KPIDashboard,
    summary="Get the governed KPI dashboard",
    description="Returns 13 standardized KPIs. Inventory uses the latest available snapshot; shipment and labor measures use the trailing 30 days.",
    response_description="Current KPI values and RAG statuses.",
    operation_id="get_kpi_dashboard",
    responses=documented_responses(
        "Current KPI values and RAG statuses.",
        {"warehouse_id": 1, "warehouse_name": "Atlanta Distribution Center", "kpis": [{"kpi_name": "On-Time Delivery Rate", "value": 96.25, "unit": "%", "target": 95.0, "status": "Green", "as_of_date": "2026-08-26"}]},
        validation=True,
    ),
)
def get_kpi_dashboard(
    warehouse_id: int | None = Query(default=None, gt=0, description="Positive warehouse ID; omit for the enterprise view.", examples=[1]),
    db: Session = Depends(get_db),
) -> KPIDashboard:
    params = {"wh_id": warehouse_id}
    inventory = db.execute(INVENTORY_KPI_QUERY, params).mappings().one()
    shipments = db.execute(SHIPMENT_KPI_QUERY, params).mappings().one()
    labor = db.execute(LABOR_KPI_QUERY, params).mappings().one()

    as_of_date = inventory["as_of_date"] or date.today()
    total_records = int(inventory["total_records"] or 0)
    stockout_rate = (
        float(inventory["stockout_count"] or 0) / total_records * 100
        if total_records
        else 0.0
    )
    inventory_accuracy = (
        float(inventory["accurate_count"] or 0) / total_records * 100
        if total_records
        else 0.0
    )
    days_of_supply = (
        float(inventory["quantity_on_hand"] or 0)
        / float(inventory["average_daily_quantity"] or 0)
        if inventory["average_daily_quantity"]
        else 0.0
    )
    total_shipments = int(shipments["total_shipments"] or 0)
    cost_per_shipment = (
        float(shipments["total_shipping_cost"] or 0) / total_shipments
        if total_shipments
        else 0.0
    )
    cancellation_rate = (
        float(shipments["cancelled_shipments"] or 0) / total_shipments * 100
        if total_shipments
        else 0.0
    )
    avg_uph = float(labor["avg_uph"] or 0)

    definitions = [
        ("Total Inventory Value", float(inventory["total_value"] or 0), "USD", 15_000_000.0, False),
        ("Stock-Out Rate", stockout_rate, "%", 3.0, True),
        ("Items Below Reorder Point", float(inventory["reorder_count"] or 0), "Items", 50.0, True),
        ("Inventory Accuracy", inventory_accuracy, "%", 99.0, False),
        ("Days of Supply", days_of_supply, "Days", 30.0, False),
        ("On-Time Delivery Rate", float(shipments["otd_rate"] or 0), "%", 95.0, False),
        ("Cost Per Shipment", cost_per_shipment, "USD/Shipment", 25.0, True),
        ("Cancellation Rate", cancellation_rate, "%", 2.0, True),
        ("Average Transit Days", float(shipments["avg_transit"] or 0), "Days", 5.0, True),
        ("Average Units Per Hour", avg_uph, "Units/Hour", 80.0, False),
        ("Error Rate", float(labor["error_rate"] or 0), "%", 2.0, True),
        ("Cost Per Unit Processed", float(labor["cost_per_unit"] or 0), "USD/Unit", 0.5, True),
        ("Labor Efficiency Index", avg_uph / 75 * 100, "%", 100.0, False),
    ]
    kpis = [
        KPIValue(
            kpi_name=name,
            value=round(value, 4 if name == "Error Rate" else 2),
            unit=unit,
            target=target,
            status=_rag_status(value, target, lower_is_better),
            as_of_date=as_of_date,
        )
        for name, value, unit, target, lower_is_better in definitions
    ]

    return KPIDashboard(
        warehouse_id=warehouse_id,
        warehouse_name=inventory["warehouse_name"] if warehouse_id else None,
        kpis=kpis,
    )


@router.get(
    "/definitions",
    response_model=list[KPIDefinition],
    summary="List governed KPI definitions",
    description="Returns the KPI catalog used by Power BI, the API, and the governance portal.",
    response_description="Canonical formulas, targets, owners, and refresh frequencies.",
    operation_id="list_kpi_definitions",
    responses=documented_responses("Canonical KPI definitions.", [{"kpi_name": "Stock-Out Rate", "domain": "Inventory", "description": "Share of inventory records that are out of stock.", "formula": "COUNT(Out of Stock) / COUNT(All Items) × 100", "unit": "%", "target": 3.0, "frequency": "Daily", "owner": "Inventory Manager"}], database=False),
)
def get_kpi_definitions() -> list[KPIDefinition]:
    return [KPIDefinition(**definition) for definition in KPI_DEFINITIONS]
