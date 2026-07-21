with shipments as (

    select * from {{ ref('stg_shipments') }}

),

daily_summary as (

    select
        ship_date,
        warehouse_id,
        shipment_type,

        -- Volume counts
        count(*)                                                                   as total_shipments,
        sum(case when status             = 'Delivered' then 1 else 0 end)          as delivered_count,
        sum(case when status             = 'Cancelled' then 1 else 0 end)          as cancelled_count,
        sum(case when status             = 'Returned'  then 1 else 0 end)          as returned_count,

        -- Delivery performance counts
        sum(case when delivery_performance = 'On Time' then 1 else 0 end)          as on_time_count,
        sum(case when delivery_performance = 'Late'    then 1 else 0 end)          as late_count,

        -- Weight and cost aggregates
        sum(total_items)                                                            as total_items_shipped,
        sum(total_weight_lbs)                                                       as total_weight_shipped,
        sum(shipping_cost)                                                          as total_shipping_cost,
        avg(shipping_cost)                                                          as avg_shipping_cost,

        -- Transit time (only for delivered shipments)
        avg(cast(actual_transit_days as decimal(8, 2)))                             as avg_transit_days,

        -- On-time delivery rate (% of delivered shipments that were on time)
        case
            when sum(case when status = 'Delivered' then 1 else 0 end) > 0
                then cast(
                         sum(case when delivery_performance = 'On Time' then 1 else 0 end)
                         as decimal(8, 4)
                     )
                     / cast(
                         sum(case when status = 'Delivered' then 1 else 0 end)
                         as decimal(8, 4)
                     ) * 100
            else 0
        end as on_time_delivery_pct

    from shipments
    group by
        ship_date,
        warehouse_id,
        shipment_type

)

select * from daily_summary
