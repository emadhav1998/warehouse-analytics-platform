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

Interactive Swagger UI is available at `/docs`, ReDoc at `/redoc`, and the raw
OpenAPI 3 document at `/openapi.json` while the service is running. Every
operation documents parameter constraints, success payloads, validation errors,
and database availability errors.

Import `postman/Warehouse_Analytics_API.postman_collection.json` into Postman to
run all preconfigured requests. Set the collection-level `base_url` and filter
variables as needed. The API is currently read-only and intentionally uses no
authentication; protect it with an API gateway before exposing it publicly.

## Tests

Install development dependencies and run pytest:

```powershell
..\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
..\.venv\Scripts\python.exe -m pytest
```

Database exceptions return HTTP `503` without exposing connection details:

```json
{"error":{"code":"database_unavailable","message":"The analytics database is temporarily unavailable."}}
```

FastAPI parameter validation errors return HTTP `422` with a `detail` array that
identifies the invalid query parameter and violated constraint.

## Docker

```powershell
docker build -t warehouse-analytics-api .
docker run --rm -p 8000:8000 --env-file .env warehouse-analytics-api
```
