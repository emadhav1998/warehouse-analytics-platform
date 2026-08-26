# Data Dictionary — Warehouse Operations Analytics

## Scope and conventions

This dictionary covers all 27 SQL/dbt datasets in the raw, staging, intermediate, mart, and aggregate layers. SQL types shown for raw tables come from the DDL. Staging and downstream types are inherited unless a cast or calculation is noted. `PK`, `FK`, and `UK` mean primary, foreign, and unique/business keys.

## 1. Raw tables

### `raw.warehouses`

Physical warehouse master. Grain: one warehouse.

| Column | Type | Description |
|---|---|---|
| `warehouse_id` | `INT` | Identity PK |
| `warehouse_code` | `VARCHAR(20)` | Unique business code |
| `warehouse_name` | `VARCHAR(200)` | Display name |
| `address` | `VARCHAR(255)` | Street address |
| `city` | `VARCHAR(100)` | City |
| `state` | `VARCHAR(50)` | State or province |
| `country` | `VARCHAR(100)` | Country |
| `zip_code` | `VARCHAR(20)` | Postal code |
| `capacity_sqft` | `INT` | Capacity in square feet |
| `warehouse_type` | `VARCHAR(50)` | Operational classification |
| `is_active` | `BIT` | Active flag |
| `created_at`, `updated_at` | `DATETIME2` | Audit timestamps |

### `raw.products`

Product master. Grain: one product/SKU.

| Column | Type | Description |
|---|---|---|
| `product_id` | `INT` | Identity PK |
| `sku` | `VARCHAR(50)` | Unique stock keeping unit |
| `product_name` | `VARCHAR(200)` | Product name |
| `category`, `subcategory` | `VARCHAR(100)` | Product classification |
| `unit_cost`, `unit_price` | `DECIMAL(10,2)` | Unit cost and retail price |
| `weight_lbs` | `DECIMAL(8,2)` | Unit weight in pounds |
| `is_hazardous`, `is_perishable` | `BIT` | Handling flags |
| `reorder_point`, `reorder_quantity` | `INT` | Replenishment threshold and quantity |
| `created_at`, `updated_at` | `DATETIME2` | Audit timestamps |

### `raw.employees`

Employee master. Grain: one employee.

| Column | Type | Description |
|---|---|---|
| `employee_id` | `INT` | Identity PK |
| `employee_code` | `VARCHAR(20)` | Unique business code |
| `first_name`, `last_name` | `VARCHAR(100)` | Employee name components |
| `email` | `VARCHAR(200)` | Email address |
| `department`, `job_title` | `VARCHAR(100)` | Organization assignment |
| `warehouse_id` | `INT` | Nullable FK to warehouse |
| `shift` | `VARCHAR(20)` | Day, Swing, or Night |
| `hire_date` | `DATE` | Employment start date |
| `hourly_rate` | `DECIMAL(8,2)` | Hourly pay rate |
| `is_active` | `BIT` | Active flag |
| `created_at`, `updated_at` | `DATETIME2` | Audit timestamps |

### `raw.inventory`

Inventory snapshots. Grain: warehouse × product × snapshot date.

| Column | Type | Description |
|---|---|---|
| `inventory_id` | `INT` | Identity PK |
| `warehouse_id`, `product_id` | `INT` | FKs to warehouse and product |
| `quantity_on_hand` | `INT` | Physical quantity |
| `quantity_reserved` | `INT` | Reserved quantity |
| `quantity_available` | `INT` | Available quantity |
| `bin_location`, `lot_number` | `VARCHAR(50)` | Storage and lot identifiers |
| `expiry_date`, `last_count_date`, `snapshot_date` | `DATE` | Expiry, count, and snapshot dates |
| `created_at`, `updated_at` | `DATETIME2` | Audit timestamps |

### `raw.shipments`

Shipment headers. Grain: one shipment.

| Column | Type | Description |
|---|---|---|
| `shipment_id` | `INT` | Identity PK |
| `shipment_number` | `VARCHAR(50)` | Unique business shipment number |
| `warehouse_id` | `INT` | Nullable warehouse FK |
| `order_number` | `VARCHAR(50)` | Related order |
| `shipment_type` | `VARCHAR(20)` | Inbound or Outbound |
| `status` | `VARCHAR(30)` | Shipment lifecycle status |
| `carrier` | `VARCHAR(100)` | Carrier name |
| `tracking_number` | `VARCHAR(100)` | Carrier tracking number |
| `total_items` | `INT` | Expected item count |
| `total_weight_lbs` | `DECIMAL(10,2)` | Shipment weight |
| `ship_date`, `expected_delivery`, `actual_delivery` | `DATE` | Shipment milestone dates |
| `origin_address`, `dest_address` | `VARCHAR(255)` | Origin and destination text |
| `shipping_cost` | `DECIMAL(10,2)` | Freight cost |
| `created_at`, `updated_at` | `DATETIME2` | Audit timestamps |

### `raw.shipment_items`

Shipment lines. Grain: one product line per shipment.

| Column | Type | Description |
|---|---|---|
| `shipment_item_id` | `INT` | Identity PK |
| `shipment_id` | `INT` | Required FK to shipment |
| `product_id` | `INT` | Nullable FK to product |
| `quantity` | `INT` | Positive unit quantity |
| `unit_price` | `DECIMAL(10,2)` | Unit price |
| `line_total` | `DECIMAL(12,2)` | Extended line value |
| `created_at` | `DATETIME2` | Creation timestamp |

### `raw.labor_activities`

Employee activity events. Grain: one recorded activity interval.

| Column | Type | Description |
|---|---|---|
| `activity_id` | `INT` | Identity PK |
| `employee_id`, `warehouse_id` | `INT` | Nullable employee and warehouse FKs |
| `activity_type` | `VARCHAR(50)` | Picking, Packing, Receiving, Putaway, Loading, or Cycle Count |
| `activity_date` | `DATE` | Activity date |
| `start_time`, `end_time` | `DATETIME2` | Activity interval |
| `units_processed`, `orders_processed`, `errors_count` | `INT` | Non-negative activity outcomes |
| `notes` | `VARCHAR(500)` | Optional operational notes |
| `created_at` | `DATETIME2` | Creation timestamp |

## 2. Staging models

Staging models are views that retain source grain, standardize types, and add the derived fields listed below.

| Model | Columns (type — description) |
|---|---|
| `stg_warehouses` | `warehouse_id INT` — PK; `warehouse_code VARCHAR` — business key; `warehouse_name VARCHAR` — name; `address VARCHAR`, `city VARCHAR`, `state VARCHAR`, `country VARCHAR`, `zip_code VARCHAR` — location; `capacity_sqft INT` — capacity; `warehouse_type VARCHAR` — type; `is_active BIT` — active flag; `created_at DATETIME2`, `updated_at DATETIME2` — audit timestamps. |
| `stg_products` | `product_id INT` — PK; `sku VARCHAR` — business key; `product_name VARCHAR`, `category VARCHAR`, `subcategory VARCHAR` — classification; `unit_cost DECIMAL`, `unit_price DECIMAL`, `weight_lbs DECIMAL` — pricing/weight; `is_hazardous BIT`, `is_perishable BIT` — flags; `reorder_point INT`, `reorder_quantity INT` — replenishment; `unit_margin DECIMAL` — price minus cost; `margin_pct DECIMAL` — margin relative to cost; `created_at DATETIME2`, `updated_at DATETIME2` — audit. |
| `stg_employees` | `employee_id INT`, `employee_code VARCHAR` — keys; `first_name VARCHAR`, `last_name VARCHAR`, `full_name VARCHAR` — names; `email VARCHAR`; `department VARCHAR`, `job_title VARCHAR`, `warehouse_id INT`, `shift VARCHAR` — assignment; `hire_date DATE`, `hourly_rate DECIMAL`, `is_active BIT`; `created_at DATETIME2`, `updated_at DATETIME2`. |
| `stg_inventory` | `inventory_id INT`, `warehouse_id INT`, `product_id INT` — keys; `quantity_on_hand INT`, `quantity_reserved INT`, `quantity_available INT`; `bin_location VARCHAR`, `lot_number VARCHAR`; `expiry_date DATE`, `last_count_date DATE`, `snapshot_date DATE`; `stock_status VARCHAR` — derived Out of Stock/Fully Reserved/Low Stock/In Stock; `created_at DATETIME2`, `updated_at DATETIME2`. |
| `stg_shipments` | `shipment_id INT`, `shipment_number VARCHAR`, `warehouse_id INT`, `order_number VARCHAR`; `shipment_type VARCHAR`, `status VARCHAR`, `carrier VARCHAR`, `tracking_number VARCHAR`; `total_items INT`, `total_weight_lbs DECIMAL`; `ship_date DATE`, `expected_delivery DATE`, `actual_delivery DATE`; `origin_address VARCHAR`, `dest_address VARCHAR`; `shipping_cost DECIMAL`; `expected_transit_days INT`, `actual_transit_days INT` — derived date differences; `delivery_performance VARCHAR` — derived status; `created_at DATETIME2`, `updated_at DATETIME2`. |
| `stg_shipment_items` | `shipment_item_id INT`, `shipment_id INT`, `product_id INT` — keys; `quantity INT`, `unit_price DECIMAL`, `line_total DECIMAL`; `created_at DATETIME2`. |
| `stg_labor_activities` | `activity_id INT`, `employee_id INT`, `warehouse_id INT`; `activity_type VARCHAR`, `activity_date DATE`; `start_time DATETIME2`, `end_time DATETIME2`; `duration_minutes INT`, `duration_hours DECIMAL` — derived durations; `units_processed INT`, `orders_processed INT`, `errors_count INT`; `units_per_hour DECIMAL` — derived productivity; `notes VARCHAR`; `created_at DATETIME2`. |

## 3. Intermediate models

These models are ephemeral dbt transformations and are not persisted as physical tables.

| Model | Grain | Columns |
|---|---|---|
| `int_inventory_daily_snapshot` | Warehouse × product × snapshot date | `snapshot_date DATE`; `warehouse_id INT`; `warehouse_name VARCHAR`; `warehouse_type VARCHAR`; `product_id INT`; `sku VARCHAR`; `product_name VARCHAR`; `category VARCHAR`; `subcategory VARCHAR`; `quantity_on_hand INT`; `quantity_reserved INT`; `quantity_available INT`; `stock_status VARCHAR`; `unit_cost DECIMAL`; `unit_price DECIMAL`; `inventory_value_at_cost DECIMAL`; `inventory_value_at_retail DECIMAL`; `reorder_point INT`; `needs_reorder BIT`; `expiry_date DATE`; `expiring_within_30_days BIT`. |
| `int_shipment_summary` | Ship date × warehouse × shipment type | `ship_date DATE`; `warehouse_id INT`; `shipment_type VARCHAR`; `total_shipments INT`; `delivered_count INT`; `cancelled_count INT`; `returned_count INT`; `on_time_count INT`; `late_count INT`; `total_items_shipped INT`; `total_weight_shipped DECIMAL`; `total_shipping_cost DECIMAL`; `avg_shipping_cost DECIMAL`; `avg_transit_days DECIMAL`; `on_time_delivery_pct DECIMAL`. |
| `int_labor_productivity` | Employee × date × activity type | `activity_date DATE`; `employee_id INT`; `employee_name VARCHAR`; `department VARCHAR`; `shift VARCHAR`; `warehouse_id INT`; `hourly_rate DECIMAL`; `activity_type VARCHAR`; `activity_count INT`; `total_hours DECIMAL`; `total_units INT`; `total_orders INT`; `total_errors INT`; `avg_units_per_hour DECIMAL`; `error_rate_pct DECIMAL`; `labor_cost DECIMAL`. |

## 4. Mart dimensions

| Model | Columns (type — description) |
|---|---|
| `dim_date` | `date_key DATE` — PK; `year INT`; `month_number INT`; `day_of_month INT`; `month_name VARCHAR`; `month_short VARCHAR`; `day_name VARCHAR`; `day_of_week INT`; `day_of_year INT`; `week_of_year INT`; `quarter_number INT`; `quarter_name VARCHAR`; `year_quarter VARCHAR`; `year_month VARCHAR`; `is_weekend BIT`; `fiscal_year INT`; `fiscal_month INT`; `fiscal_quarter INT`. |
| `dim_warehouse` | `warehouse_key VARCHAR(32)` — surrogate PK; `warehouse_id INT` — natural key; `warehouse_code VARCHAR`; `warehouse_name VARCHAR`; `address VARCHAR`; `city VARCHAR`; `state VARCHAR`; `country VARCHAR`; `zip_code VARCHAR`; `capacity_sqft INT`; `warehouse_type VARCHAR`; `is_active BIT`; `city_state VARCHAR` — display label; `size_category VARCHAR` — capacity band. |
| `dim_product` | `product_key VARCHAR(32)` — surrogate PK; `product_id INT`; `sku VARCHAR`; `product_name VARCHAR`; `category VARCHAR`; `subcategory VARCHAR`; `unit_cost DECIMAL`; `unit_price DECIMAL`; `unit_margin DECIMAL`; `margin_pct DECIMAL`; `weight_lbs DECIMAL`; `is_hazardous BIT`; `is_perishable BIT`; `reorder_point INT`; `reorder_quantity INT`; `price_tier VARCHAR`; `weight_class VARCHAR`. |
| `dim_employee` | `employee_key VARCHAR(32)` — surrogate PK; `employee_id INT`; `employee_code VARCHAR`; `full_name VARCHAR`; `email VARCHAR`; `department VARCHAR`; `job_title VARCHAR`; `warehouse_id INT`; `shift VARCHAR`; `hire_date DATE`; `hourly_rate DECIMAL`; `is_active BIT`; `tenure_days INT`; `tenure_band VARCHAR`. |

## 5. Mart facts

| Model | Columns (type — description) |
|---|---|
| `fact_inventory` | `inventory_fact_key VARCHAR(32)` — PK; `warehouse_key VARCHAR(32)`, `product_key VARCHAR(32)`, `date_key DATE` — FKs; `warehouse_id INT`, `product_id INT`, `warehouse_name VARCHAR`, `category VARCHAR`, `sku VARCHAR` — traceability; `quantity_on_hand INT`, `quantity_reserved INT`, `quantity_available INT`; `stock_status VARCHAR`; `inventory_value_at_cost DECIMAL`, `inventory_value_at_retail DECIMAL`; `reorder_point INT`; `needs_reorder BIT`; `expiring_within_30_days BIT`. |
| `fact_shipment` | `shipment_fact_key VARCHAR(32)` — PK; `warehouse_key VARCHAR(32)`, `date_key DATE` — FKs; `shipment_id INT`, `shipment_number VARCHAR`, `warehouse_id INT`, `order_number VARCHAR`; `shipment_type VARCHAR`, `status VARCHAR`, `carrier VARCHAR`, `delivery_performance VARCHAR`; `total_items INT`, `total_weight_lbs DECIMAL`, `shipping_cost DECIMAL`; `expected_transit_days INT`, `actual_transit_days INT`; `line_item_count INT`, `total_quantity INT`, `total_line_value DECIMAL`; `is_late BIT`; `transit_efficiency_ratio DECIMAL`; `ship_date DATE`, `expected_delivery DATE`, `actual_delivery DATE`. |
| `fact_labor` | `labor_fact_key VARCHAR(32)` — PK; `warehouse_key VARCHAR(32)`, `employee_key VARCHAR(32)`, `date_key DATE` — FKs; `employee_id INT`, `warehouse_id INT`, `employee_name VARCHAR`, `department VARCHAR`, `shift VARCHAR`, `activity_type VARCHAR`; `activity_count INT`; `total_hours DECIMAL`, `total_units INT`, `total_orders INT`, `total_errors INT`; `avg_units_per_hour DECIMAL`, `error_rate_pct DECIMAL`; `labor_cost DECIMAL`, `hourly_rate DECIMAL`; `productivity_tier VARCHAR`. |

## 6. Monthly aggregate tables

| Model | Columns (type — description) |
|---|---|
| `agg_inventory_monthly` | `month_start DATE`, `warehouse_key VARCHAR(32)`, `product_key VARCHAR(32)` — grain; `quantity_on_hand INT`, `quantity_reserved INT`, `quantity_available INT`; `inventory_value_at_cost DECIMAL`, `inventory_value_at_retail DECIMAL`; `stock_out_records INT`, `reorder_records INT`, `inventory_records INT`. |
| `agg_shipment_monthly` | `month_start DATE`, `warehouse_key VARCHAR(32)`, `shipment_type VARCHAR`, `carrier VARCHAR` — grain; `shipment_count INT`, `delivered_count INT`, `on_time_count INT`, `late_count INT`, `cancelled_count INT`, `returned_count INT`; `total_items INT`, `total_quantity INT`; `shipping_cost DECIMAL`. |
| `agg_labor_monthly` | `month_start DATE`, `warehouse_key VARCHAR(32)`, `employee_key VARCHAR(32)`, `activity_type VARCHAR` — grain; `total_hours DECIMAL`, `total_units INT`, `total_orders INT`, `total_errors INT`, `labor_cost DECIMAL`, `labor_records INT`. |

## Ownership and maintenance

- Raw DDL: `database/tables/raw/`
- dbt contracts and tests: `dbt_warehouse/models/**/_*.yml` and `dbt_warehouse/tests/`
- Executable transformations: `dbt_warehouse/models/`
- Frontend dictionary: `frontend/js/data-dictionary.js`

Schema changes must update dbt metadata, the frontend dictionary, and this document in the same change.

