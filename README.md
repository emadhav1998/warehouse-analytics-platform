# Warehouse Analytics Platform

A production-grade data analytics platform for warehouse operations, built with SQL Server, dbt Core, FastAPI, and Power BI. This platform transforms raw warehouse data into actionable KPIs across inventory, shipments, and labor productivity.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  Power BI        │  │  KPI Portal     │  │  SharePoint  │ │
│  │  Dashboards      │  │  (React/HTML)   │  │  Docs        │ │
│  └────────┬─────────┘  └────────┬────────┘  └──────────────┘ │
├───────────┼──────────────────────┼────────────────────────────┤
│           │      API LAYER       │                            │
│           │  ┌───────────────────┴──┐                         │
│           │  │  FastAPI (KPI API)   │                         │
│           │  └───────────┬──────────┘                         │
├───────────┼──────────────┼────────────────────────────────────┤
│           │   TRANSFORM LAYER (dbt Core)                      │
│  ┌────────┴──────────────┴──────────────────────────────────┐ │
│  │  Staging → Intermediate → Marts (Star Schema)            │ │
│  │  dim_warehouse | dim_product | dim_employee | dim_date   │ │
│  │  fact_inventory | fact_shipment | fact_labor              │ │
│  └──────────────────────┬───────────────────────────────────┘ │
├──────────────────────────┼────────────────────────────────────┤
│           SOURCE LAYER   │                                    │
│  ┌───────────────────────┴──────────────────────────────────┐ │
│  │  SQL Server / Azure SQL Database                         │ │
│  │  Raw Tables: inventory, shipments, employees, warehouses │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer        | Technology                          |
|--------------|-------------------------------------|
| Source DB    | SQL Server / Azure SQL Database     |
| Transform    | dbt Core                            |
| API          | FastAPI (Python)                    |
| Frontend     | HTML / CSS / JavaScript             |
| BI / Reports | Power BI Desktop & Service          |
| CI/CD        | GitHub Actions                      |
| Containers   | Docker                              |

---

## Repository Structure

```
warehouse-analytics-platform/
├── .github/workflows/         # CI/CD pipeline definitions
├── database/
│   ├── schemas/               # Schema creation scripts
│   ├── tables/raw/            # Raw table DDL
│   └── migrations/            # Flyway/manual migrations
├── dbt_warehouse/
│   ├── models/
│   │   ├── staging/           # Source cleaning & renaming
│   │   ├── intermediate/      # Business logic joins
│   │   └── marts/             # Star schema dims & facts
│   ├── macros/                # Reusable Jinja macros
│   ├── seeds/                 # Static reference CSVs
│   ├── tests/                 # Custom dbt tests
│   └── snapshots/             # SCD Type 2 snapshots
├── backend/app/               # FastAPI application
│   ├── models/                # SQLAlchemy ORM models
│   ├── routers/               # API route handlers
│   ├── services/              # Business logic
│   └── schemas/               # Pydantic schemas
├── frontend/                  # KPI Portal (HTML/JS)
├── powerbi/                   # .pbix file & DAX measures
├── docs/                      # Data dictionary, KPI defs, ERD
└── scripts/                   # Data generation & deployment
```

---

## Key KPIs

- **Inventory Turnover Rate** — units moved / avg inventory
- **Order Fill Rate** — orders shipped on time vs. total orders
- **Shipment Cycle Time** — time from order creation to delivery
- **Labor Productivity** — units processed per labor hour
- **Warehouse Utilization** — capacity used vs. total capacity

---

## Getting Started

### Prerequisites

- SQL Server 2019+ or Azure SQL Database
- Python 3.10+
- dbt Core (`pip install dbt-sqlserver`)
- Node.js 18+ (optional, for frontend dev)
- Power BI Desktop

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/emadhav1998/warehouse-analytics-platform.git
   cd warehouse-analytics-platform
   ```

2. **Configure the database**
   ```bash
   # Run schema and table creation scripts in order
   sqlcmd -S <server> -d <db> -i database/schemas/01_create_raw_schema.sql
   sqlcmd -S <server> -d <db> -i database/schemas/02_create_staging_schema.sql
   sqlcmd -S <server> -d <db> -i database/schemas/03_create_mart_schema.sql
   ```

3. **Set up dbt**
   ```bash
   cd dbt_warehouse
   pip install dbt-sqlserver
   dbt deps
   dbt seed
   dbt run
   dbt test
   ```

4. **Run the FastAPI backend**
   ```bash
   cd backend
   pip install -r requirements.txt
   uvicorn app.main:app --reload
   ```

5. **Open the frontend**
   Open `frontend/index.html` in a browser or serve with a local HTTP server.

---

## Branch Strategy

| Branch         | Purpose                              |
|----------------|--------------------------------------|
| `main`         | Production-ready, tagged releases    |
| `develop`      | Integration branch for features      |
| `feature/*`    | Individual feature development       |

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
