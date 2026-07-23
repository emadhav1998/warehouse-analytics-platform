with labor as (

    select * from {{ ref('int_labor_productivity') }}

),

dim_wh as (

    select warehouse_key, warehouse_id from {{ ref('dim_warehouse') }}

),

dim_emp as (

    select employee_key, employee_id from {{ ref('dim_employee') }}

),

final as (

    select
        -- ── Surrogate key (composite: date + employee + activity_type) ────
        {{ dbt_utils.generate_surrogate_key([
            'l.activity_date',
            'l.employee_id',
            'l.activity_type'
        ]) }}                               as labor_fact_key,

        -- ── Dimension keys ────────────────────────────────────────────────
        d.warehouse_key,
        e.employee_key,
        l.activity_date                     as date_key,

        -- ── Degenerate dimensions / natural keys ──────────────────────────
        l.employee_id,
        l.warehouse_id,
        l.employee_name,
        l.department,
        l.shift,
        l.activity_type,

        -- ── Activity-count measures ───────────────────────────────────────
        l.activity_count,
        l.total_hours,
        l.total_units,
        l.total_orders,
        l.total_errors,

        -- ── Productivity KPI measures ─────────────────────────────────────
        l.avg_units_per_hour,
        l.error_rate_pct,

        -- ── Cost measures ─────────────────────────────────────────────────
        l.labor_cost,
        l.hourly_rate,

        -- ── Derived productivity tier ─────────────────────────────────────
        case
            when l.avg_units_per_hour >= 100 then 'High'
            when l.avg_units_per_hour >=  50 then 'Medium'
            else                                  'Low'
        end                                 as productivity_tier

    from labor   l
    left join dim_wh  d on l.warehouse_id = d.warehouse_id
    left join dim_emp e on l.employee_id  = e.employee_id

)

select * from final
