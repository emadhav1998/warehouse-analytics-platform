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
- `GET /api/v1/inventory/warehouses`
- `GET /api/v1/shipments/performance?days=30&warehouse_id=1`
- `GET /api/v1/labor/productivity?warehouse_id=1&department=Picking`
- `GET /api/v1/validation/data-quality`

Swagger UI is available at `/docs` while the service is running.

## Tests

Install development dependencies and run pytest:

```powershell
..\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
..\.venv\Scripts\python.exe -m pytest
```

Database exceptions are returned as a structured HTTP 503 response without exposing connection details.

## Docker

```powershell
docker build -t warehouse-analytics-api .
docker run --rm -p 8000:8000 --env-file .env warehouse-analytics-api
```
