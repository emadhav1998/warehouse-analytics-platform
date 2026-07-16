-- =============================================================================
-- File    : V002_add_labor_and_shipment_items.sql
-- Purpose : Flyway-compatible migration — adds labor_activities & shipment_items
-- Version : V002
-- Author  : Madhav Eadala
-- Date    : 2026-07-16
-- Run     : After V001_initial_setup.sql
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

-- ── raw.labor_activities ──────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'labor_activities'
)
    EXEC sp_executesql N'
    CREATE TABLE raw.labor_activities (
        activity_id      INT           IDENTITY(1,1) PRIMARY KEY,
        employee_id      INT REFERENCES raw.employees(employee_id)  ON DELETE SET NULL,
        warehouse_id     INT REFERENCES raw.warehouses(warehouse_id) ON DELETE SET NULL,
        activity_type    VARCHAR(50)   NOT NULL,
        activity_date    DATE          NOT NULL,
        start_time       DATETIME2,
        end_time         DATETIME2,
        units_processed  INT           NOT NULL DEFAULT 0,
        orders_processed INT           NOT NULL DEFAULT 0,
        errors_count     INT           NOT NULL DEFAULT 0,
        notes            VARCHAR(500),
        created_at       DATETIME2     NOT NULL DEFAULT GETDATE(),
        CONSTRAINT CHK_labor_activity_type CHECK (
            activity_type IN (''Picking'',''Packing'',''Receiving'',''Putaway'',''Loading'',''Cycle Count'')
        ),
        CONSTRAINT CHK_labor_time_order  CHECK (end_time IS NULL OR start_time IS NULL OR end_time >= start_time),
        CONSTRAINT CHK_labor_units       CHECK (units_processed  >= 0),
        CONSTRAINT CHK_labor_orders      CHECK (orders_processed >= 0),
        CONSTRAINT CHK_labor_errors      CHECK (errors_count     >= 0)
    )';
GO

-- ── raw.shipment_items ────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'shipment_items'
)
    EXEC sp_executesql N'
    CREATE TABLE raw.shipment_items (
        shipment_item_id INT           IDENTITY(1,1) PRIMARY KEY,
        shipment_id      INT           NOT NULL REFERENCES raw.shipments(shipment_id) ON DELETE CASCADE,
        product_id       INT REFERENCES raw.products(product_id) ON DELETE SET NULL,
        quantity         INT           NOT NULL,
        unit_price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        line_total       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        created_at       DATETIME2     NOT NULL DEFAULT GETDATE(),
        CONSTRAINT CHK_shipment_items_qty   CHECK (quantity   > 0),
        CONSTRAINT CHK_shipment_items_price CHECK (unit_price >= 0),
        CONSTRAINT CHK_shipment_items_total CHECK (line_total >= 0)
    )';
GO

PRINT 'V002_add_labor_and_shipment_items completed successfully.';
GO
