-- =============================================================================
-- File    : raw_inventory.sql
-- Purpose : Create raw.inventory — daily stock-level snapshots per warehouse/product
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- Run     : After raw_warehouses.sql and raw_products.sql (FK dependencies)
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'inventory'
)
BEGIN
    CREATE TABLE raw.inventory (
        inventory_id        INT           IDENTITY(1,1)  PRIMARY KEY,
        warehouse_id        INT
            CONSTRAINT FK_inventory_warehouse
            REFERENCES raw.warehouses(warehouse_id)
            ON DELETE SET NULL,
        product_id          INT
            CONSTRAINT FK_inventory_product
            REFERENCES raw.products(product_id)
            ON DELETE SET NULL,
        quantity_on_hand    INT           NOT NULL        DEFAULT 0,
        quantity_reserved   INT           NOT NULL        DEFAULT 0,
        quantity_available  INT           NOT NULL        DEFAULT 0,
        bin_location        VARCHAR(50),
        lot_number          VARCHAR(50),
        expiry_date         DATE,
        last_count_date     DATE,
        -- Each row is a point-in-time snapshot; one row per warehouse/product/day
        snapshot_date       DATE          NOT NULL,
        created_at          DATETIME2     NOT NULL        DEFAULT GETDATE(),
        updated_at          DATETIME2     NOT NULL        DEFAULT GETDATE(),

        -- Enforce one snapshot per warehouse+product+date combination
        CONSTRAINT UQ_inventory_snapshot
            UNIQUE (warehouse_id, product_id, snapshot_date),

        -- Quantities must be non-negative
        CONSTRAINT CHK_inventory_qty_on_hand    CHECK (quantity_on_hand   >= 0),
        CONSTRAINT CHK_inventory_qty_reserved   CHECK (quantity_reserved  >= 0),
        CONSTRAINT CHK_inventory_qty_available  CHECK (quantity_available >= 0)
    );
END
GO

-- Composite index supporting the most common analytical query pattern
-- (filter by warehouse, join to product, range scan over snapshot_date)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_raw_inventory_wh_prod_date' AND object_id = OBJECT_ID('raw.inventory')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_raw_inventory_wh_prod_date
        ON raw.inventory (warehouse_id, product_id, snapshot_date DESC);
END
GO
