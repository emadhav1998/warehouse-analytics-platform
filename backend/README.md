# Warehouse Analytics API

## Local setup

```powershell
cd backend
..\.venv\Scripts\Activate.ps1
Copy-Item .env.example .env
uvicorn app.main:app --reload
```

The default connection uses Windows authentication with SQL Server and ODBC Driver 17. Override `DATABASE_URL`
in `.env` for other environments. Do not commit `.env`.

## Endpoints

- `GET /health`
- `GET /api/v1/kpis/dashboard?warehouse_id=1`
- `GET /api/v1/kpis/definitions`
- `GET /api/v1/inventory/summary?warehouse_id=1`
- `GET /api/v1/inventory/alerts?warehouse_id=1&limit=50`
- `GET /api/v1/shipments/performance?days=30&warehouse_id=1`

Swagger UI is available at `/docs` while the service is running.

