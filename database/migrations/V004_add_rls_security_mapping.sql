-- =============================================================================
-- Purpose: Dynamic Power BI warehouse access mapping
-- Security: No user assignments are seeded; access is denied until provisioned.
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

IF OBJECT_ID('mart.security_user_warehouse', 'U') IS NULL
BEGIN
    CREATE TABLE mart.security_user_warehouse (
        user_email     VARCHAR(320) NOT NULL,
        warehouse_id  INT NOT NULL,
        is_active      BIT NOT NULL
            CONSTRAINT DF_security_user_warehouse_active DEFAULT 1,
        granted_at     DATETIME2 NOT NULL
            CONSTRAINT DF_security_user_warehouse_granted DEFAULT SYSUTCDATETIME(),
        granted_by     VARCHAR(320) NOT NULL
            CONSTRAINT DF_security_user_warehouse_granted_by DEFAULT SYSTEM_USER,
        CONSTRAINT PK_security_user_warehouse
            PRIMARY KEY (user_email, warehouse_id),
        CONSTRAINT FK_security_user_warehouse_warehouse
            FOREIGN KEY (warehouse_id)
            REFERENCES raw.warehouses (warehouse_id)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('mart.security_user_warehouse')
      AND name = 'IX_security_user_warehouse_lookup'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_security_user_warehouse_lookup
        ON mart.security_user_warehouse (user_email, warehouse_id, is_active);
END;
GO

-- Provision access with parameterized administrative tooling, for example:
-- INSERT INTO mart.security_user_warehouse (user_email, warehouse_id)
-- SELECT LOWER(@UserEmail), warehouse_id
-- FROM raw.warehouses
-- WHERE warehouse_code = @WarehouseCode;
