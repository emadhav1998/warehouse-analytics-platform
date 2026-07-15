-- =============================================================================
-- File    : raw_warehouses.sql
-- Purpose : Create raw.warehouses — source table for warehouse locations
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- Run     : After 01_create_raw_schema.sql
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'warehouses'
)
BEGIN
    CREATE TABLE raw.warehouses (
        warehouse_id        INT           IDENTITY(1,1)  PRIMARY KEY,
        warehouse_code      VARCHAR(20)   NOT NULL        UNIQUE,
        warehouse_name      VARCHAR(100)  NOT NULL,
        address             VARCHAR(255),
        city                VARCHAR(100),
        state               VARCHAR(50),
        country             VARCHAR(50)   NOT NULL        DEFAULT 'USA',
        zip_code            VARCHAR(20),
        capacity_sqft       DECIMAL(12,2),
        -- Distribution, Fulfillment, Cold Storage
        warehouse_type      VARCHAR(50),
        is_active           BIT           NOT NULL        DEFAULT 1,
        created_at          DATETIME2     NOT NULL        DEFAULT GETDATE(),
        updated_at          DATETIME2     NOT NULL        DEFAULT GETDATE()
    );
END
GO

-- Index on warehouse_code for fast lookups from staging joins
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_raw_warehouses_code' AND object_id = OBJECT_ID('raw.warehouses')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_raw_warehouses_code
        ON raw.warehouses (warehouse_code);
END
GO
