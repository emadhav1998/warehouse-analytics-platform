with warehouses as (

    select * from {{ ref('stg_warehouses') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['warehouse_id']) }} as warehouse_key,
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
        is_active,

        -- Derived display label
        city + ', ' + state as city_state,

        -- Size classification
        case
            when capacity_sqft >= 200000 then 'Large'
            when capacity_sqft >= 100000 then 'Medium'
            else                              'Small'
        end as size_category

    from warehouses

)

select * from final
