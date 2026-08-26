-- =============================================================================
-- File    : V003_add_performance_indexes.sql
-- Purpose : Add idempotent covering indexes for dbt and API query patterns
-- Run     : After V002 and after the first dbt mart build
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

IF OBJECT_ID('mart.fact_inventory', 'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID('mart.fact_inventory')
         AND name = 'IX_fact_inventory_date_warehouse'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_inventory_date_warehouse
        ON mart.fact_inventory (date_key, warehouse_id)
        INCLUDE (
            warehouse_key, product_key, quantity_on_hand, quantity_reserved,
            quantity_available, stock_status, needs_reorder,
            inventory_value_at_cost
        );
END;
GO

IF OBJECT_ID('mart.fact_shipment', 'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID('mart.fact_shipment')
         AND name = 'IX_fact_shipment_date_warehouse_status'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_shipment_date_warehouse_status
        ON mart.fact_shipment (
            date_key, warehouse_id, status, delivery_performance
        )
        INCLUDE (carrier, shipping_cost, actual_transit_days);
END;
GO

IF OBJECT_ID('mart.fact_labor', 'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID('mart.fact_labor')
         AND name = 'IX_fact_labor_date_warehouse_employee'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_labor_date_warehouse_employee
        ON mart.fact_labor (date_key, warehouse_id, employee_id)
        INCLUDE (
            department, activity_type, total_hours, total_units,
            total_errors, labor_cost
        );
END;
GO

IF OBJECT_ID('raw.inventory', 'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID('raw.inventory')
         AND name = 'IX_inventory_snapshot'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_inventory_snapshot
        ON raw.inventory (snapshot_date, warehouse_id, product_id)
        INCLUDE (
            quantity_on_hand, quantity_reserved, quantity_available,
            expiry_date
        );
END;
GO

IF OBJECT_ID('raw.shipments', 'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID('raw.shipments')
         AND name = 'IX_shipments_ship_date'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_shipments_ship_date
        ON raw.shipments (ship_date, warehouse_id, status)
        INCLUDE (
            shipment_id, shipping_cost,
            actual_delivery, expected_delivery
        );
END;
GO

IF OBJECT_ID('raw.labor_activities', 'U') IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID('raw.labor_activities')
         AND name = 'IX_labor_activity_date'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_labor_activity_date
        ON raw.labor_activities (activity_date, warehouse_id, employee_id)
        INCLUDE (
            activity_type, start_time, end_time, units_processed,
            errors_count
        );
END;
GO
