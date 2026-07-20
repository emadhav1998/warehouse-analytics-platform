with source as (

    select * from {{ source('raw', 'products') }}

),

renamed as (

    select
        product_id,
        sku,
        product_name,
        category,
        subcategory,
        unit_cost,
        unit_price,
        weight_lbs,
        cast(is_hazardous  as bit) as is_hazardous,
        cast(is_perishable as bit) as is_perishable,
        reorder_point,
        reorder_quantity,

        -- Derived margin columns
        unit_price - unit_cost as unit_margin,

        case
            when unit_cost > 0
                then round((unit_price - unit_cost) / unit_cost * 100, 2)
            else 0
        end as margin_pct,

        created_at,
        updated_at

    from source

)

select * from renamed
