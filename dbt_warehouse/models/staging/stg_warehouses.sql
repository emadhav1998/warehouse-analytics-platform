with source as (

    select * from {{ source('raw', 'warehouses') }}

),

renamed as (

    select
        warehouse_id,
        warehouse_code,
        warehouse_name,
        address,
        city,
        state,
        country,
        zip_code,
        capacity_sqft,
        warehouse_type,
        cast(is_active  as bit)      as is_active,
        cast(created_at as datetime2) as created_at,
        cast(updated_at as datetime2) as updated_at

    from source

)

select * from renamed
