select
    datefromparts(year(date_key), month(date_key), 1) as month_start,
    warehouse_key,
    shipment_type,
    carrier,
    count(*)                                          as shipment_count,
    sum(case when status = 'Delivered' then 1 else 0 end)          as delivered_count,
    sum(case when delivery_performance = 'On Time' then 1 else 0 end) as on_time_count,
    sum(case when is_late = 1 then 1 else 0 end)                    as late_count,
    sum(case when status = 'Cancelled' then 1 else 0 end)          as cancelled_count,
    sum(case when status = 'Returned' then 1 else 0 end)           as returned_count,
    sum(total_items)                                   as total_items,
    sum(total_quantity)                                as total_quantity,
    sum(shipping_cost)                                 as shipping_cost
from {{ ref('fact_shipment') }}
group by
    datefromparts(year(date_key), month(date_key), 1),
    warehouse_key,
    shipment_type,
    carrier

