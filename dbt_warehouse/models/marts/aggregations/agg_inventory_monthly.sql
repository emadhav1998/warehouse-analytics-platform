select
    datefromparts(year(date_key), month(date_key), 1) as month_start,
    warehouse_key,
    product_key,
    sum(quantity_on_hand)                             as quantity_on_hand,
    sum(quantity_reserved)                            as quantity_reserved,
    sum(quantity_available)                           as quantity_available,
    sum(inventory_value_at_cost)                      as inventory_value_at_cost,
    sum(inventory_value_at_retail)                    as inventory_value_at_retail,
    sum(case when stock_status = 'Out of Stock' then 1 else 0 end) as stock_out_records,
    sum(case when needs_reorder = 1 then 1 else 0 end)              as reorder_records,
    count(*)                                          as inventory_records
from {{ ref('fact_inventory') }}
group by
    datefromparts(year(date_key), month(date_key), 1),
    warehouse_key,
    product_key

