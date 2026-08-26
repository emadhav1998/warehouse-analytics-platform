-- =============================================================================
-- File    : raw_labor_activities.sql
-- Purpose : Create raw.labor_activities — warehouse workforce activity tracking
-- Author  : Madhav Eadala
-- Date    : 2026-07-16
-- Run     : After raw_employees.sql and raw_warehouses.sql (FK dependencies)
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'labor_activities'
)
BEGIN
    CREATE TABLE raw.labor_activities (
        activity_id         INT           IDENTITY(1,1)  PRIMARY KEY,
        employee_id         INT
            CONSTRAINT FK_labor_employee
            REFERENCES raw.employees(employee_id)
            ON DELETE SET NULL,
        warehouse_id        INT
            CONSTRAINT FK_labor_warehouse
            REFERENCES raw.warehouses(warehouse_id)
            ON DELETE SET NULL,
        -- Picking, Packing, Receiving, Putaway, Loading, Cycle Count
        activity_type       VARCHAR(50)   NOT NULL,
        activity_date       DATE          NOT NULL,
        start_time          DATETIME2,
        end_time            DATETIME2,
        units_processed     INT           NOT NULL        DEFAULT 0,
        orders_processed    INT           NOT NULL        DEFAULT 0,
        errors_count        INT           NOT NULL        DEFAULT 0,
        notes               VARCHAR(500),
        created_at          DATETIME2     NOT NULL        DEFAULT GETDATE(),

        -- Validate allowed activity types
        CONSTRAINT CHK_labor_activity_type CHECK (
            activity_type IN ('Picking', 'Packing', 'Receiving', 'Putaway', 'Loading', 'Cycle Count')
        ),

        -- End time must not be before start time
        CONSTRAINT CHK_labor_time_order CHECK (
            end_time IS NULL OR start_time IS NULL OR end_time >= start_time
        ),

        -- Counts must be non-negative
        CONSTRAINT CHK_labor_units          CHECK (units_processed   >= 0),
        CONSTRAINT CHK_labor_orders         CHECK (orders_processed  >= 0),
        CONSTRAINT CHK_labor_errors         CHECK (errors_count      >= 0)
    );
END
GO

-- Index: employee + date for individual productivity queries
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_labor_employee_date' AND object_id = OBJECT_ID('raw.labor_activities')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_labor_employee_date
        ON raw.labor_activities (employee_id, activity_date DESC)
        INCLUDE (activity_type, units_processed, orders_processed);
END
GO

-- Index: warehouse + date for facility-level labor analytics
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_labor_warehouse_date' AND object_id = OBJECT_ID('raw.labor_activities')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_labor_warehouse_date
        ON raw.labor_activities (warehouse_id, activity_date DESC)
        INCLUDE (activity_type, units_processed, errors_count);
END
GO

-- Index: activity_type for cross-warehouse type aggregations
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_labor_activity_type' AND object_id = OBJECT_ID('raw.labor_activities')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_labor_activity_type
        ON raw.labor_activities (activity_type, activity_date DESC);
END
GO
