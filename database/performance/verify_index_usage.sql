-- =============================================================================
-- Purpose: Verify the Day 27 indexes and capture representative API query IO.
-- Run in SSMS after dbt build and V003. Review the actual execution plans for
-- Index Seek/Scan operators on the IX_fact_* indexes.
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc,
    COALESCE(s.user_seeks, 0) AS user_seeks,
    COALESCE(s.user_scans, 0) AS user_scans,
    COALESCE(s.user_lookups, 0) AS user_lookups,
    COALESCE(s.user_updates, 0) AS user_updates,
    s.last_user_seek,
    s.last_user_scan
FROM sys.indexes AS i
LEFT JOIN sys.dm_db_index_usage_stats AS s
    ON s.database_id = DB_ID()
   AND s.object_id = i.object_id
   AND s.index_id = i.index_id
WHERE i.name IN (
    'IX_fact_inventory_date_warehouse',
    'IX_fact_shipment_date_warehouse_status',
    'IX_fact_labor_date_warehouse_employee',
    'IX_inventory_snapshot',
    'IX_shipments_ship_date',
    'IX_labor_activity_date'
)
ORDER BY schema_name, table_name, index_name;
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

DECLARE @WarehouseId INT = NULL;

-- Latest inventory snapshot query used by the KPI and inventory endpoints.
SELECT
    SUM(inventory_value_at_cost) AS total_inventory_value,
    SUM(quantity_on_hand) AS total_quantity,
    SUM(CASE WHEN stock_status = 'Out of Stock' THEN 1 ELSE 0 END) AS stockouts
FROM mart.fact_inventory
WHERE date_key = (
    SELECT MAX(date_key)
    FROM mart.fact_inventory
    WHERE @WarehouseId IS NULL OR warehouse_id = @WarehouseId
)
  AND (@WarehouseId IS NULL OR warehouse_id = @WarehouseId)
OPTION (RECOMPILE);

-- Rolling shipment KPI query.
SELECT
    status,
    delivery_performance,
    COUNT(*) AS shipment_count,
    SUM(shipping_cost) AS shipping_cost,
    AVG(actual_transit_days) AS average_transit_days
FROM mart.fact_shipment
WHERE date_key >= DATEADD(MONTH, -1, CAST(GETDATE() AS date))
  AND (@WarehouseId IS NULL OR warehouse_id = @WarehouseId)
GROUP BY status, delivery_performance
OPTION (RECOMPILE);

-- Rolling labor KPI query.
SELECT
    department,
    activity_type,
    SUM(total_hours) AS total_hours,
    SUM(total_units) AS total_units,
    SUM(labor_cost) AS labor_cost
FROM mart.fact_labor
WHERE date_key >= DATEADD(MONTH, -1, CAST(GETDATE() AS date))
  AND (@WarehouseId IS NULL OR warehouse_id = @WarehouseId)
GROUP BY department, activity_type
OPTION (RECOMPILE);
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
