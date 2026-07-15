-- =============================================================================
-- File    : 03_create_mart_schema.sql
-- Purpose : Create mart-layer objects (star schema) in the mart schema
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- Run     : After 02_create_staging_schema.sql
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

-- Mart objects are primarily managed by dbt.
-- This script ensures the schema exists and documents the mart contract.

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'mart')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA mart';
END
GO

-- ---------------------------------------------------------------------------
-- mart.schema_version — tracks which dbt run last populated the mart
-- ---------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'mart' AND t.name = 'schema_version'
)
BEGIN
    CREATE TABLE mart.schema_version (
        version_id      INT IDENTITY(1,1) PRIMARY KEY,
        version_label   VARCHAR(50)  NOT NULL,
        applied_at      DATETIME2    NOT NULL DEFAULT GETDATE(),
        applied_by      VARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
        notes           VARCHAR(500)
    );
END
GO
