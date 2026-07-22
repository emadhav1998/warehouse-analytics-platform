with products as (

    select * from {{ ref('stg_products') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,
        product_id,
        sku,
        product_name,
        category,
        subcategory,
        unit_cost,
        unit_price,
        unit_margin,
        margin_pct,
        weight_lbs,
        is_hazardous,
        is_perishable,
        reorder_point,
        reorder_quantity,

        -- Price tier classification
        case
            when unit_price >= 200 then 'Premium'
            when unit_price >=  50 then 'Standard'
            else                        'Economy'
        end as price_tier,

        -- Weight class classification
        case
            when weight_lbs >= 50 then 'Heavy'
            when weight_lbs >= 10 then 'Medium'
            else                        'Light'
        end as weight_class

    from products

)

select * from final
