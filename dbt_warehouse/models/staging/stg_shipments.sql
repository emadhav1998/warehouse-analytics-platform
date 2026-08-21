with source as (

    select * from {{ source('raw', 'shipments') }}

),

ranked as (

    -- Defensively retain one version per shipment. The source-level uniqueness
    -- test still reports duplicates, while this guard prevents them from
    -- multiplying shipment facts and downstream KPI values.
    select
        *,
        row_number() over (
            partition by shipment_id
            order by updated_at desc, created_at desc
        ) as source_row_number
    from source

),

renamed as (

    select
        shipment_id,
        shipment_number,
        warehouse_id,
        order_number,
        shipment_type,
        status,
        carrier,
        tracking_number,
        total_items,
        total_weight_lbs,
        ship_date,
        expected_delivery,
        actual_delivery,
        origin_address,
        dest_address,
        shipping_cost,

        -- Derived transit-time columns
        datediff(day, ship_date, expected_delivery) as expected_transit_days,

        case
            when actual_delivery is not null
                then datediff(day, ship_date, actual_delivery)
            else null
        end as actual_transit_days,

        -- Derived delivery performance classification
        case
            when status = 'Cancelled'                                         then 'Cancelled'
            when status = 'Delivered'
             and actual_delivery is not null
             and actual_delivery <= expected_delivery                          then 'On Time'
            when status = 'Delivered'
             and actual_delivery is not null
             and actual_delivery >  expected_delivery                          then 'Late'
            else                                                                   'In Progress'
        end as delivery_performance,

        created_at,
        updated_at

    from ranked
    where source_row_number = 1

)

select * from renamed
