# Star Schema ERD — Warehouse Operations Analytics

## Logical model

```mermaid
erDiagram
    DIM_DATE ||--o{ FACT_INVENTORY : "date_key"
    DIM_DATE ||--o{ FACT_SHIPMENT : "date_key"
    DIM_DATE ||--o{ FACT_LABOR : "date_key"
    DIM_WAREHOUSE ||--o{ FACT_INVENTORY : "warehouse_key"
    DIM_WAREHOUSE ||--o{ FACT_SHIPMENT : "warehouse_key"
    DIM_WAREHOUSE ||--o{ FACT_LABOR : "warehouse_key"
    DIM_PRODUCT ||--o{ FACT_INVENTORY : "product_key"
    DIM_EMPLOYEE ||--o{ FACT_LABOR : "employee_key"

    DIM_DATE {
        date date_key PK
        int year
        varchar year_month
        int fiscal_year
    }
    DIM_WAREHOUSE {
        varchar warehouse_key PK
        int warehouse_id UK
        varchar warehouse_name
        varchar city_state
    }
    DIM_PRODUCT {
        varchar product_key PK
        int product_id UK
        varchar sku UK
        varchar category
    }
    DIM_EMPLOYEE {
        varchar employee_key PK
        int employee_id UK
        varchar full_name
        varchar department
    }
    FACT_INVENTORY {
        varchar inventory_fact_key PK
        date date_key FK
        varchar warehouse_key FK
        varchar product_key FK
        int quantity_on_hand
        decimal inventory_value_at_cost
    }
    FACT_SHIPMENT {
        varchar shipment_fact_key PK
        date date_key FK
        varchar warehouse_key FK
        varchar shipment_number
        decimal shipping_cost
    }
    FACT_LABOR {
        varchar labor_fact_key PK
        date date_key FK
        varchar warehouse_key FK
        varchar employee_key FK
        decimal total_hours
        int total_units
    }
```

## Fact grains

| Fact | Grain | Primary identifier | Dimensions |
|---|---|---|---|
| `mart.fact_inventory` | One product × warehouse × snapshot date | `inventory_fact_key` | Date, Warehouse, Product |
| `mart.fact_shipment` | One shipment | `shipment_fact_key` | Ship Date, Warehouse |
| `mart.fact_labor` | One employee × activity type × activity date | `labor_fact_key` | Activity Date, Warehouse, Employee |

## Relationship rules

- All relationships are one-to-many from dimension to fact and use single-direction filtering.
- Surrogate keys are generated with `dbt_utils.generate_surrogate_key`; natural IDs remain available for traceability.
- `fact_shipment` intentionally has no product relationship. Shipment items are aggregated to shipment grain before loading the fact.
- `dim_date` spans 2024-01-01 through 2027-12-31 and contains calendar and July-start fiscal attributes.
- Facts retain selected degenerate dimensions such as shipment status, carrier, activity type, and stock status.

## Aggregate layer

```mermaid
flowchart LR
    FI["fact_inventory"] --> AI["agg_inventory_monthly"]
    FS["fact_shipment"] --> AS["agg_shipment_monthly"]
    FL["fact_labor"] --> AL["agg_labor_monthly"]
    DW["dim_warehouse"] --> AI
    DW --> AS
    DW --> AL
    DP["dim_product"] --> AI
    DE["dim_employee"] --> AL
```

| Aggregate | Grain | Intended use |
|---|---|---|
| `agg_inventory_monthly` | Month × warehouse × product | Inventory value and stock trends |
| `agg_shipment_monthly` | Month × warehouse × shipment type × carrier | Shipment volume, service, and cost trends |
| `agg_labor_monthly` | Month × warehouse × employee × activity type | Labor cost and productivity trends |

## Physical pipeline

`raw source tables → staging views → ephemeral intermediate models → mart dimensions/facts → monthly aggregates → Power BI/API`

Referential integrity is enforced where possible in SQL Server and checked independently by `scripts/validate_data.py` and dbt singular tests.

