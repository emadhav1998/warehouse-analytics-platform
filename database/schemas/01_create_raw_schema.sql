-- =============================================================================
-- File    : 01_create_raw_schema.sql
-- Purpose : Create WarehouseAnalyticsDB database and raw, staging, mart schemas
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- =============================================================================

-- Create database if it does not exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'WarehouseAnalyticsDB')
BEGIN
    CREATE DATABASE WarehouseAnalyticsDB;
END
GO

USE WarehouseAnalyticsDB;
GO

-- ── raw schema ────────────────────────────────────────────────────────────────
-- Holds source data exactly as ingested, with no business transformations.
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA raw';
END
GO

-- ── staging schema ────────────────────────────────────────────────────────────
-- Holds cleaned / renamed views of raw data produced by dbt staging models.
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA staging';
END
GO

-- ── mart schema ───────────────────────────────────────────────────────────────
-- Holds the star-schema dimension and fact tables consumed by Power BI & API.
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'mart')
BEGIN
    EXEC sp_executesql N'CREATE SCHEMA mart';
END
GO
