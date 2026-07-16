-- =============================================================================
-- File    : raw_shipment_items.sql
-- Purpose : Create raw.shipment_items — line-item detail per shipment
-- Author  : Madhav Eadala
-- Date    : 2026-07-16
-- Run     : After raw_shipments.sql and raw_products.sql (FK dependencies)
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'shipment_items'
)
BEGIN
    CREATE TABLE raw.shipment_items (
        shipment_item_id    INT           IDENTITY(1,1)  PRIMARY KEY,
        shipment_id         INT           NOT NULL
            CONSTRAINT FK_shipment_items_shipment
            REFERENCES raw.shipments(shipment_id)
            ON DELETE CASCADE,
        product_id          INT
            CONSTRAINT FK_shipment_items_product
            REFERENCES raw.products(product_id)
            ON DELETE SET NULL,
        quantity            INT           NOT NULL,
        unit_price          DECIMAL(10,2) NOT NULL        DEFAULT 0.00,
        line_total          DECIMAL(12,2) NOT NULL        DEFAULT 0.00,
        created_at          DATETIME2     NOT NULL        DEFAULT GETDATE(),

        -- Enforce positive quantities and non-negative prices
        CONSTRAINT CHK_shipment_items_qty        CHECK (quantity    > 0),
        CONSTRAINT CHK_shipment_items_price      CHECK (unit_price >= 0),
        CONSTRAINT CHK_shipment_items_total      CHECK (line_total >= 0)
    );
END
GO

-- Index: shipment_id — primary access pattern (all items for a shipment)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_shipment_items_shipment' AND object_id = OBJECT_ID('raw.shipment_items')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_shipment_items_shipment
        ON raw.shipment_items (shipment_id)
        INCLUDE (product_id, quantity, unit_price, line_total);
END
GO

-- Index: product_id — for product-level shipment history analysis
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_shipment_items_product' AND object_id = OBJECT_ID('raw.shipment_items')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_shipment_items_product
        ON raw.shipment_items (product_id)
        INCLUDE (quantity, line_total);
END
GO
