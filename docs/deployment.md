# Warehouse Analytics deployment

## Overview

Run deployments from the repository root with `scripts/deploy.ps1`. The script performs migrations, a dbt build, raw-data
validation, an optional API image build, and dbt documentation generation. It stops immediately when a native command
returns a nonzero exit code and writes a deployment result under `scripts/reports/`.

Environment defaults are stored in `config/environments/*.psd1`. These files contain no credentials. Supply secrets through
the deployment host's secret manager as environment variables.

## Required variables

| Variable | Required | Purpose |
|---|---:|---|
| `SQL_SERVER` | Staging/prod | SQL Server hostname or instance |
| `SQL_DATABASE` | No | Overrides `WarehouseAnalyticsDB` |
| `SQL_USER`, `SQL_PASSWORD` | SQL authentication | Migration credentials |
| `DBT_USER`, `DBT_PASSWORD` | Staging/prod | dbt SQL credentials; also act as sqlcmd fallback credentials |
| `DBT_DRIVER` | No | Overrides the environment's ODBC driver |
| `WAREHOUSE_DB_CONNECTION_STRING` | No | Explicit validation-script connection string |

Use dedicated least-privileged deployment identities. Never store passwords in `.psd1`, `.env`, command history, or Git.

## Preflight and deployment

Review a deployment without executing commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy.ps1 -Environment dev -PlanOnly
```

Run an incremental development deployment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy.ps1 -Environment dev
```

Run production with an automatic pre-deployment backup and restore-on-failure:

```powershell
$env:SQL_SERVER = "prod-sql.company.net"
$env:DBT_USER = "warehouse_deployer"
# DBT_PASSWORD is injected into the process environment by the deployment secret manager.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy.ps1 `
    -Environment prod -RollbackOnFailure -BackupDirectory "/var/opt/mssql/backup"
```

The script passes SQL authentication to `sqlcmd` through `SQLCMDPASSWORD`, not a visible `-P` command-line argument.

Use `-FullRefresh` only for an intentional rebuild. Normal deployments preserve the incremental inventory fact table.
Use `-SkipDocker` when the API image is built by a separate release pipeline.

## Dynamic warehouse RLS

Migration `V004_add_rls_security_mapping.sql` creates `mart.security_user_warehouse` without seeding access. Provision
lowercase Power BI user principal names through parameterized administrative tooling. Import that table into the semantic
model, keep it disconnected, and configure roles from `powerbi/rls/roles.json` and `warehouse_rls.dax`.

Before publishing, test these cases in Power BI Desktop and Service:

- mapped user sees only assigned warehouses;
- multi-warehouse user sees the union of assignments;
- inactive and unmapped users see no data;
- unrestricted administrators see all warehouses;
- Date, Category, drill-through, tooltip, and bookmark interactions do not reveal data outside the warehouse filter.

## Recovery

`-RollbackOnFailure` creates a SQL Server `COPY_ONLY` backup before the first migration. If a later step fails, the script
restores that backup using `WITH REPLACE`. The backup path is interpreted by SQL Server and must be writable by the SQL
Server service account. This option takes the database temporarily offline during restore and should run only in an
approved maintenance window.

Without `-RollbackOnFailure`, migrations are idempotent and the script stops at the failed step. Correct the failure and
rerun the deployment. Docker images are local build artifacts and are not pushed by this script.
