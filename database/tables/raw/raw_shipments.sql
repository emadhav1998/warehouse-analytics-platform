-- =============================================================================
-- File    : raw_shipments.sql
-- Purpose : Create raw.shipments — inbound and outbound shipment tracking
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- Run     : After raw_warehouses.sql (FK dependency)
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'shipments'
)
BEGIN
    CREATE TABLE raw.shipments (
        shipment_id         INT           IDENTITY(1,1)  PRIMARY KEY,
        shipment_number     VARCHAR(50)   NOT NULL        UNIQUE,
        warehouse_id        INT
            CONSTRAINT FK_shipments_warehouse
            REFERENCES raw.warehouses(warehouse_id)
            ON DELETE SET NULL,
        order_number        VARCHAR(50),
        -- Inbound, Outbound
        shipment_type       VARCHAR(20),
        -- Pending, In Transit, Delivered, Cancelled, Returned
        status              VARCHAR(30),
        carrier             VARCHAR(100),
        tracking_number     VARCHAR(100),
        total_items         INT,
        total_weight_lbs    DECIMAL(10,2),
        ship_date           DATE,
        expected_delivery   DATE,
        actual_delivery     DATE,
        origin_address      VARCHAR(255),
        dest_address        VARCHAR(255),
        shipping_cost       DECIMAL(10,2),
        created_at          DATETIME2     NOT NULL        DEFAULT GETDATE(),
        updated_at          DATETIME2     NOT NULL        DEFAULT GETDATE(),

        -- Validate allowed values
        CONSTRAINT CHK_shipments_type
            CHECK (shipment_type IN ('Inbound', 'Outbound')),
        CONSTRAINT CHK_shipments_status
            CHECK (status IN ('Pending', 'In Transit', 'Delivered', 'Cancelled', 'Returned')),

        -- Delivery date must not precede ship date
        CONSTRAINT CHK_shipments_dates
            CHECK (actual_delivery IS NULL OR actual_delivery >= ship_date)
    );
END
GO

-- Index on warehouse + status for operational dashboards
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_raw_shipments_wh_status' AND object_id = OBJECT_ID('raw.shipments')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_raw_shipments_wh_status
        ON raw.shipments (warehouse_id, status)
        INCLUDE (ship_date, actual_delivery, expected_delivery);
END
GO

-- Index on ship_date for time-series analysis
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_raw_shipments_ship_date' AND object_id = OBJECT_ID('raw.shipments')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_raw_shipments_ship_date
        ON raw.shipments (ship_date DESC);
END
GO
