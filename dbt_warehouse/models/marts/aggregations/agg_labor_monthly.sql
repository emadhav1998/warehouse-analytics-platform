select
    datefromparts(year(date_key), month(date_key), 1) as month_start,
    warehouse_key,
    employee_key,
    activity_type,
    sum(total_hours)                                  as total_hours,
    sum(total_units)                                  as total_units,
    sum(total_orders)                                 as total_orders,
    sum(total_errors)                                 as total_errors,
    sum(labor_cost)                                   as labor_cost,
    count(*)                                          as labor_records
from {{ ref('fact_labor') }}
group by
    datefromparts(year(date_key), month(date_key), 1),
    warehouse_key,
    employee_key,
    activity_type

