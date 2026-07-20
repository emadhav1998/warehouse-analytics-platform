with source as (

    select * from {{ source('raw', 'inventory') }}

),

renamed as (

    select
        inventory_id,
        warehouse_id,
        product_id,
        quantity_on_hand,
        quantity_reserved,
        quantity_available,
        bin_location,
        lot_number,
        expiry_date,
        last_count_date,
        snapshot_date,

        -- Derived stock status classification
        case
            when quantity_on_hand   = 0  then 'Out of Stock'
            when quantity_available <= 0 then 'Fully Reserved'
            when quantity_on_hand   < 50 then 'Low Stock'
            else                              'In Stock'
        end as stock_status,

        created_at,
        updated_at

    from source

)

select * from renamed
