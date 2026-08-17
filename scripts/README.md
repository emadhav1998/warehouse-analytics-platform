# Data validation

Run all raw-layer integrity and quality checks from the repository root:

```powershell
.\.venv\Scripts\python.exe scripts\validate_data.py
```

The script reads `WAREHOUSE_DB_CONNECTION_STRING` when set; otherwise it connects to the local
`WarehouseAnalyticsDB` using ODBC Driver 17 and Windows authentication. A JSON report is written to
`scripts/reports/data_validation_report.json` by default. Override it with `--report <path>`.

Exit codes are suitable for CI: `0` means all checks passed, `1` means one or more data checks failed,
and `2` means the connection or a validation query failed.

Equivalent raw-layer singular tests live in `dbt_warehouse/tests`. Run them with:

```powershell
cd dbt_warehouse
dbt test --select test_type:singular
```

