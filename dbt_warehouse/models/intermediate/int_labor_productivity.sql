with labor as (

    select * from {{ ref('stg_labor_activities') }}

),

employees as (

    select * from {{ ref('stg_employees') }}

),

daily_productivity as (

    select
        l.activity_date,
        l.employee_id,
        e.full_name       as employee_name,
        e.department,
        e.shift,
        l.warehouse_id,
        e.hourly_rate,
        l.activity_type,

        -- Activity volume
        count(*)                        as activity_count,
        sum(l.duration_hours)           as total_hours,
        sum(l.units_processed)          as total_units,
        sum(l.orders_processed)         as total_orders,
        sum(l.errors_count)             as total_errors,

        -- Productivity: units per hour across all activities for this
        -- employee / day / activity_type combination
        case
            when sum(l.duration_hours) > 0
                then sum(l.units_processed) / sum(l.duration_hours)
            else 0
        end as avg_units_per_hour,

        -- Quality: error rate as % of units processed
        case
            when sum(l.units_processed) > 0
                then cast(sum(l.errors_count)   as decimal(10, 4))
                     / cast(sum(l.units_processed) as decimal(10, 4)) * 100
            else 0
        end as error_rate_pct,

        -- Cost: total labor hours × hourly rate
        sum(l.duration_hours) * e.hourly_rate as labor_cost

    from labor     l
    inner join employees e on l.employee_id = e.employee_id

    group by
        l.activity_date,
        l.employee_id,
        e.full_name,
        e.department,
        e.shift,
        l.warehouse_id,
        e.hourly_rate,
        l.activity_type

)

select * from daily_productivity
