-- =============================================================================
-- File    : 02_create_staging_schema.sql
-- Purpose : Create staging-layer objects (views / tables) in the staging schema
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- Run     : After 01_create_raw_schema.sql
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

-- Staging objects are primarily managed by dbt.
-- This script ensures the schema exists and documents the staging contract.

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA staging';
END
GO

-- ---------------------------------------------------------------------------
-- staging.schema_version — tracks which dbt run last populated staging
-- ---------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = 'staging' AND t.name = 'schema_version'
)
BEGIN
    CREATE TABLE staging.schema_version (
        version_id      INT IDENTITY(1,1) PRIMARY KEY,
        version_label   VARCHAR(50)  NOT NULL,
        applied_at      DATETIME2    NOT NULL DEFAULT GETDATE(),
        applied_by      VARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
        notes           VARCHAR(500)
    );
END
GO
