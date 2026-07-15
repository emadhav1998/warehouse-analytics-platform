-- =============================================================================
-- File    : raw_products.sql
-- Purpose : Create raw.products — source table for product catalog
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- Run     : After 01_create_raw_schema.sql
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'products'
)
BEGIN
    CREATE TABLE raw.products (
        product_id          INT           IDENTITY(1,1)  PRIMARY KEY,
        sku                 VARCHAR(50)   NOT NULL        UNIQUE,
        product_name        VARCHAR(200)  NOT NULL,
        category            VARCHAR(100),
        subcategory         VARCHAR(100),
        unit_cost           DECIMAL(10,2),
        unit_price          DECIMAL(10,2),
        weight_lbs          DECIMAL(8,2),
        is_hazardous        BIT           NOT NULL        DEFAULT 0,
        is_perishable       BIT           NOT NULL        DEFAULT 0,
        reorder_point       INT,
        reorder_quantity    INT,
        created_at          DATETIME2     NOT NULL        DEFAULT GETDATE(),
        updated_at          DATETIME2     NOT NULL        DEFAULT GETDATE()
    );
END
GO

-- Index on SKU for fast lookups from staging joins
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_raw_products_sku' AND object_id = OBJECT_ID('raw.products')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_raw_products_sku
        ON raw.products (sku);
END
GO

-- Index on category/subcategory for analytical filtering
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_raw_products_category' AND object_id = OBJECT_ID('raw.products')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_raw_products_category
        ON raw.products (category, subcategory);
END
GO
