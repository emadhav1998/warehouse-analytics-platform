with source as (

    select * from {{ source('raw', 'shipment_items') }}

),

renamed as (

    select
        shipment_item_id,
        shipment_id,
        product_id,
        quantity,
        unit_price,
        line_total,
        created_at

    from source

)

select * from renamed
