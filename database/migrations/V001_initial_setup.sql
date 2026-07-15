-- =============================================================================
-- File    : V001_initial_setup.sql
-- Purpose : Flyway-compatible migration — runs all Day-1 DDL in dependency order
-- Version : V001
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- =============================================================================
-- Execution order:
--   1. Create database & schemas   → database/schemas/01_create_raw_schema.sql
--   2. Dimension tables (no FKs)   → raw.warehouses, raw.products
--   3. Tables with FK to above     → raw.employees, raw.inventory, raw.shipments
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

-- ── 1. Schemas ────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')
    EXEC sp_executesql N'CREATE SCHEMA raw';
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC sp_executesql N'CREATE SCHEMA staging';
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'mart')
    EXEC sp_executesql N'CREATE SCHEMA mart';
GO

-- ── 2a. raw.warehouses ────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'warehouses'
)
    EXEC sp_executesql N'
    CREATE TABLE raw.warehouses (
        warehouse_id    INT           IDENTITY(1,1) PRIMARY KEY,
        warehouse_code  VARCHAR(20)   NOT NULL UNIQUE,
        warehouse_name  VARCHAR(100)  NOT NULL,
        address         VARCHAR(255),
        city            VARCHAR(100),
        state           VARCHAR(50),
        country         VARCHAR(50)   NOT NULL DEFAULT ''USA'',
        zip_code        VARCHAR(20),
        capacity_sqft   DECIMAL(12,2),
        warehouse_type  VARCHAR(50),
        is_active       BIT           NOT NULL DEFAULT 1,
        created_at      DATETIME2     NOT NULL DEFAULT GETDATE(),
        updated_at      DATETIME2     NOT NULL DEFAULT GETDATE()
    )';
GO

-- ── 2b. raw.products ──────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'products'
)
    EXEC sp_executesql N'
    CREATE TABLE raw.products (
        product_id       INT          IDENTITY(1,1) PRIMARY KEY,
        sku              VARCHAR(50)  NOT NULL UNIQUE,
        product_name     VARCHAR(200) NOT NULL,
        category         VARCHAR(100),
        subcategory      VARCHAR(100),
        unit_cost        DECIMAL(10,2),
        unit_price       DECIMAL(10,2),
        weight_lbs       DECIMAL(8,2),
        is_hazardous     BIT          NOT NULL DEFAULT 0,
        is_perishable    BIT          NOT NULL DEFAULT 0,
        reorder_point    INT,
        reorder_quantity INT,
        created_at       DATETIME2    NOT NULL DEFAULT GETDATE(),
        updated_at       DATETIME2    NOT NULL DEFAULT GETDATE()
    )';
GO

-- ── 3a. raw.employees ─────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'employees'
)
    EXEC sp_executesql N'
    CREATE TABLE raw.employees (
        employee_id   INT          IDENTITY(1,1) PRIMARY KEY,
        employee_code VARCHAR(20)  NOT NULL UNIQUE,
        first_name    VARCHAR(100) NOT NULL,
        last_name     VARCHAR(100) NOT NULL,
        email         VARCHAR(200),
        department    VARCHAR(100),
        job_title     VARCHAR(100),
        warehouse_id  INT REFERENCES raw.warehouses(warehouse_id) ON DELETE SET NULL,
        shift         VARCHAR(20),
        hire_date     DATE,
        hourly_rate   DECIMAL(8,2),
        is_active     BIT          NOT NULL DEFAULT 1,
        created_at    DATETIME2    NOT NULL DEFAULT GETDATE(),
        updated_at    DATETIME2    NOT NULL DEFAULT GETDATE()
    )';
GO

-- ── 3b. raw.inventory ─────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'inventory'
)
    EXEC sp_executesql N'
    CREATE TABLE raw.inventory (
        inventory_id       INT       IDENTITY(1,1) PRIMARY KEY,
        warehouse_id       INT REFERENCES raw.warehouses(warehouse_id) ON DELETE SET NULL,
        product_id         INT REFERENCES raw.products(product_id)    ON DELETE SET NULL,
        quantity_on_hand   INT       NOT NULL DEFAULT 0,
        quantity_reserved  INT       NOT NULL DEFAULT 0,
        quantity_available INT       NOT NULL DEFAULT 0,
        bin_location       VARCHAR(50),
        lot_number         VARCHAR(50),
        expiry_date        DATE,
        last_count_date    DATE,
        snapshot_date      DATE      NOT NULL,
        created_at         DATETIME2 NOT NULL DEFAULT GETDATE(),
        updated_at         DATETIME2 NOT NULL DEFAULT GETDATE(),
        CONSTRAINT UQ_inventory_snapshot  UNIQUE (warehouse_id, product_id, snapshot_date),
        CONSTRAINT CHK_inventory_qty_on_hand   CHECK (quantity_on_hand   >= 0),
        CONSTRAINT CHK_inventory_qty_reserved  CHECK (quantity_reserved  >= 0),
        CONSTRAINT CHK_inventory_qty_available CHECK (quantity_available >= 0)
    )';
GO

-- ── 3c. raw.shipments ─────────────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'shipments'
)
    EXEC sp_executesql N'
    CREATE TABLE raw.shipments (
        shipment_id        INT           IDENTITY(1,1) PRIMARY KEY,
        shipment_number    VARCHAR(50)   NOT NULL UNIQUE,
        warehouse_id       INT REFERENCES raw.warehouses(warehouse_id) ON DELETE SET NULL,
        order_number       VARCHAR(50),
        shipment_type      VARCHAR(20),
        status             VARCHAR(30),
        carrier            VARCHAR(100),
        tracking_number    VARCHAR(100),
        total_items        INT,
        total_weight_lbs   DECIMAL(10,2),
        ship_date          DATE,
        expected_delivery  DATE,
        actual_delivery    DATE,
        origin_address     VARCHAR(255),
        dest_address       VARCHAR(255),
        shipping_cost      DECIMAL(10,2),
        created_at         DATETIME2     NOT NULL DEFAULT GETDATE(),
        updated_at         DATETIME2     NOT NULL DEFAULT GETDATE(),
        CONSTRAINT CHK_shipments_type   CHECK (shipment_type IN (''Inbound'',  ''Outbound'')),
        CONSTRAINT CHK_shipments_status CHECK (status        IN (''Pending'', ''In Transit'', ''Delivered'', ''Cancelled'', ''Returned'')),
        CONSTRAINT CHK_shipments_dates  CHECK (actual_delivery IS NULL OR actual_delivery >= ship_date)
    )';
GO

PRINT 'V001_initial_setup completed successfully.';
GO
