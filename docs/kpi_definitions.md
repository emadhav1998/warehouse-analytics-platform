# KPI Definitions — Warehouse Operations Analytics

## Overview

This document is the governed reference for KPIs used by Power BI, the FastAPI catalog, and the frontend portal. Measure names follow `KPI Name | Unit` in Power BI. Unless stated otherwise, calculations respect the active date, warehouse, product, employee, and report filter context.

Targets marked **Monitor** do not receive a RAG assessment. The API catalog is maintained in `backend/app/services/kpi_catalog.py`; executable DAX is maintained under `powerbi/measures/`.

## RAG rules

| Direction | Green | Yellow | Red |
|---|---|---|---|
| Higher is better | Actual ≥ target | Actual ≥ 90% of target | Actual < 90% of target |
| Lower is better | Actual ≤ target | Actual ≤ 150% of target in the API; governance scorecard uses 110% | Above yellow threshold |
| Monitor | No RAG target | — | — |

> The API and Power BI governance scorecard currently use different yellow tolerances for lower-is-better KPIs. Consumers must state which surface supplied the status.

## 1. Inventory KPIs

| # | KPI | Formula / business logic | Target | Owner | Frequency |
|---:|---|---|---|---|---|
| 1.1 | **Total Inventory Value (Cost)** | `SUM(fact_inventory[inventory_value_at_cost])`. Values on-hand inventory at cost. Dashboard/API snapshots use the latest available inventory date. | Monitor | Inventory Manager | Daily |
| 1.2 | **Total Inventory Value (Retail)** | `SUM(fact_inventory[inventory_value_at_retail])`. Values on-hand inventory at retail price. | Monitor | Inventory Manager | Daily |
| 1.3 | **Total Quantity On Hand** | `SUM(quantity_on_hand)`. Physical recorded stock before reservations. | Monitor | Inventory Manager | Daily |
| 1.4 | **Total Quantity Available** | `SUM(quantity_available)`. Stock available after reservations. | Monitor | Inventory Manager | Daily |
| 1.5 | **Inventory Utilization** | `(Total Quantity On Hand - Total Quantity Available) / Total Quantity On Hand × 100`. Returns zero when on-hand quantity is zero. | ≥ 85% | Inventory Manager | Daily |
| 1.6 | **Stock Out Rate** | `COUNT(stock_status = 'Out of Stock') / COUNT(inventory records) × 100`. Evaluated at the selected snapshot grain. | ≤ 2% | Inventory Manager | Daily |
| 1.7 | **Items Below Reorder Point** | `COUNT(needs_reorder = 1)`. `needs_reorder` is set when available quantity is at or below the product reorder point. | 0 | Replenishment Manager | Daily |
| 1.8 | **Inventory Accuracy** | `COUNT(quantity_on_hand = quantity_reserved + quantity_available) / COUNT(records) × 100`. | ≥ 99% | Inventory Control | Daily |
| 1.9 | **Days of Supply** | `Total Quantity On Hand / AVERAGEX(distinct snapshot dates, quantity_on_hand)`. This is the implemented inventory-snapshot proxy; it is not consumption-based until an outbound-usage fact is introduced. | ≥ 30 days | Inventory Planning | Daily |
| 1.10 | **Expiring Items (30 Days)** | `COUNT(expiring_within_30_days = 1)`. The flag includes non-null expiry dates on or before snapshot date + 30 days. | 0 | Inventory Control | Daily |
| 1.11 | **Inventory Value MoM Change** | `(Current Inventory Value at Cost - Prior Month Value) / Prior Month Value × 100`, using `DATEADD` on `dim_date[date_key]`. | Monitor | Inventory Manager | Monthly |

## 2. Shipment KPIs

| # | KPI | Formula / business logic | Target | Owner | Frequency |
|---:|---|---|---|---|---|
| 2.1 | **Total Shipments** | `COUNTROWS(fact_shipment)`. One mart row represents one shipment. | Monitor | Logistics Manager | Daily |
| 2.2 | **On-Time Delivery Rate** | `COUNT(delivery_performance = 'On Time') / COUNT(status = 'Delivered') × 100`. Cancelled and in-progress shipments are excluded from the denominator. | ≥ 95% | Logistics Manager | Daily |
| 2.3 | **Late Shipment Count** | `COUNT(is_late = 1)`, where actual transit days exceed expected transit days. | 0 | Logistics Manager | Daily |
| 2.4 | **Average Transit Days** | `AVERAGE(actual_transit_days)`. Null transit values are ignored by DAX. | ≤ 3 days | Logistics Manager | Daily |
| 2.5 | **Total Shipping Cost** | `SUM(shipping_cost)`. | Monitor | Transportation Manager | Daily |
| 2.6 | **Cost Per Shipment** | `Total Shipping Cost / Total Shipments`. Returns zero when there are no shipments. | ≤ $25/shipment | Transportation Manager | Daily |
| 2.7 | **Shipment Fill Rate** | `SUM(total_quantity) / SUM(total_items) × 100`. Depends on consistent source definitions for expected items and shipped quantity. | ≥ 98% | Logistics Manager | Daily |
| 2.8 | **Cancellation Rate** | `COUNT(status = 'Cancelled') / Total Shipments × 100`. | ≤ 1% | Logistics Manager | Daily |
| 2.9 | **Return Rate** | `COUNT(status = 'Returned') / Total Shipments × 100`. | ≤ 2% | Customer Operations | Daily |
| 2.10 | **Inbound vs Outbound Ratio** | `COUNT(Inbound) / COUNT(Outbound)`. Returns zero when no outbound shipments exist. | Monitor | Logistics Manager | Daily |
| 2.11 | **Shipments YTD** | `CALCULATE(Total Shipments, DATESYTD(dim_date[date_key]))`. Calendar-year calculation. | Monitor | Logistics Manager | Daily |
| 2.12 | **Shipping Cost YTD** | `CALCULATE(Total Shipping Cost, DATESYTD(dim_date[date_key]))`. Calendar-year calculation. | Monitor | Transportation Manager | Daily |

## 3. Labor KPIs

| # | KPI | Formula / business logic | Target | Owner | Frequency |
|---:|---|---|---|---|---|
| 3.1 | **Total Labor Hours** | `SUM(fact_labor[total_hours])`. Source intervals are validated between zero and 24 hours. | Monitor | Operations Manager | Daily |
| 3.2 | **Total Labor Cost** | `SUM(labor_cost)`, where the intermediate model calculates hours × hourly rate. | Monitor | Finance | Daily |
| 3.3 | **Total Units Processed** | `SUM(total_units)` across labor activities. | Monitor | Operations Manager | Daily |
| 3.4 | **Average Units Per Hour** | `Total Units Processed / Total Labor Hours`. This weighted rate is preferred over averaging row-level rates. | ≥ 75 units/hour | Operations Manager | Daily |
| 3.5 | **Labor Efficiency Index** | `AVERAGE(avg_units_per_hour) / 75 × 100`. Uses the implemented 75-UPH benchmark. | ≥ 100% | Operations Manager | Daily |
| 3.6 | **Error Rate** | `SUM(total_errors) / Total Units Processed × 100`. | ≤ 1% | Quality Manager | Daily |
| 3.7 | **Cost Per Unit Processed** | `Total Labor Cost / Total Units Processed`. | ≤ $2/unit | Finance | Daily |
| 3.8 | **Headcount (Active)** | `DISTINCTCOUNT(employee_id)` within filtered labor activity. This measures participating headcount, not the employee master active flag. | Monitor | Operations Manager | Daily |
| 3.9 | **Average Hours Per Employee** | `Total Labor Hours / Headcount (Active)`. | ≤ 8 hours/employee | Operations Manager | Daily |
| 3.10 | **Overtime Indicator** | Count of employee-date combinations whose summed labor hours exceed eight. | 0 employee-days | Operations Manager | Daily |
| 3.11 | **High Performers Count** | Count of labor fact records classified `productivity_tier = 'High'` (row rate ≥ 100 UPH). This is a record count, not distinct employees. | Monitor | Operations Manager | Daily |
| 3.12 | **Labor Cost MTD** | `CALCULATE(Total Labor Cost, DATESMTD(dim_date[date_key]))`. Calendar month-to-date. | Monitor | Finance | Daily |
| 3.13 | **Labor Cost QTD** | `CALCULATE(Total Labor Cost, DATESQTD(dim_date[date_key]))`. Calendar quarter-to-date. | Monitor | Finance | Daily |
| 3.14 | **Labor Cost YTD** | `CALCULATE(Total Labor Cost, DATESYTD(dim_date[date_key]))`. Calendar year-to-date. | Monitor | Finance | Daily |
| 3.15 | **Units Processed YTD** | `CALCULATE(Total Units Processed, DATESYTD(dim_date[date_key]))`. | Monitor | Operations Manager | Daily |

## Core executive scorecard

The 13 core operational KPIs are: Total Inventory Value (Cost), Stock Out Rate, Items Below Reorder Point, Inventory Accuracy, Days of Supply, On-Time Delivery Rate, Cost Per Shipment, Cancellation Rate, Average Transit Days, Average Units Per Hour, Error Rate, Cost Per Unit Processed, and Labor Efficiency Index.

## Calculation governance

- `dim_date[date_key]` must be marked as the model date table for time intelligence.
- Percent measures return percentage points because the implemented DAX multiplies by 100; format them as `0.00`, not `0.00%`.
- Divide-by-zero cases return zero through `DIVIDE(..., 0)`.
- API dashboard KPIs use the latest inventory snapshot and a rolling 30-day shipment/labor window; Power BI measures use the active report context.
- Changes to a KPI require synchronized updates to DAX, `backend/app/services/kpi_catalog.py`, tests, and this document.

