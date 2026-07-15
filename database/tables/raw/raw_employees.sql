-- =============================================================================
-- File    : raw_employees.sql
-- Purpose : Create raw.employees — source table for warehouse workforce data
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- Run     : After raw_warehouses.sql (FK dependency)
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'raw' AND t.name = 'employees'
)
BEGIN
    CREATE TABLE raw.employees (
        employee_id         INT           IDENTITY(1,1)  PRIMARY KEY,
        employee_code       VARCHAR(20)   NOT NULL        UNIQUE,
        first_name          VARCHAR(100)  NOT NULL,
        last_name           VARCHAR(100)  NOT NULL,
        -- Stored as a one-way hash; never store plaintext passwords here
        email               VARCHAR(200),
        -- Receiving, Picking, Packing, Shipping, Management
        department          VARCHAR(100),
        job_title           VARCHAR(100),
        warehouse_id        INT
            CONSTRAINT FK_employees_warehouse
            REFERENCES raw.warehouses(warehouse_id)
            ON DELETE SET NULL,
        -- Day, Swing, Night
        shift               VARCHAR(20),
        hire_date           DATE,
        hourly_rate         DECIMAL(8,2),
        is_active           BIT           NOT NULL        DEFAULT 1,
        created_at          DATETIME2     NOT NULL        DEFAULT GETDATE(),
        updated_at          DATETIME2     NOT NULL        DEFAULT GETDATE()
    );
END
GO

-- Index on warehouse_id for join performance
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_raw_employees_warehouse' AND object_id = OBJECT_ID('raw.employees')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_raw_employees_warehouse
        ON raw.employees (warehouse_id);
END
GO

-- Index on department/shift for labor analytics
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_raw_employees_dept_shift' AND object_id = OBJECT_ID('raw.employees')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_raw_employees_dept_shift
        ON raw.employees (department, shift);
END
GO
