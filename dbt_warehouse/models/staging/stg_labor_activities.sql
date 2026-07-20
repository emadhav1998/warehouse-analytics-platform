with source as (

    select * from {{ source('raw', 'labor_activities') }}

),

renamed as (

    select
        activity_id,
        employee_id,
        warehouse_id,
        activity_type,
        activity_date,
        start_time,
        end_time,

        -- Derived duration columns
        datediff(minute, start_time, end_time) as duration_minutes,

        cast(datediff(minute, start_time, end_time) as decimal(8, 2)) / 60.0
            as duration_hours,

        units_processed,
        orders_processed,
        errors_count,

        -- Derived productivity metric: units produced per hour worked
        case
            when datediff(minute, start_time, end_time) > 0
                then cast(units_processed as decimal(10, 2))
                     / (cast(datediff(minute, start_time, end_time) as decimal(10, 2)) / 60.0)
            else 0
        end as units_per_hour,

        notes,
        created_at

    from source

)

select * from renamed
