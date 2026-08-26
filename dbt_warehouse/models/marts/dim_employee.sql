with employees as (

    select * from {{ ref('stg_employees') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['employee_id']) }} as employee_key,
        employee_id,
        employee_code,
        full_name,
        email,
        department,
        job_title,
        warehouse_id,
        shift,
        hire_date,
        hourly_rate,
        is_active,

        -- Tenure metrics (calculated at query time)
        datediff(day, hire_date, getdate())  as tenure_days,

        -- Tenure band classification
        case
            when datediff(year, hire_date, getdate()) >= 5 then 'Senior (5+ yrs)'
            when datediff(year, hire_date, getdate()) >= 2 then 'Experienced (2-5 yrs)'
            when datediff(year, hire_date, getdate()) >= 1 then 'Intermediate (1-2 yrs)'
            else                                                 'Junior (< 1 yr)'
        end as tenure_band

    from employees

)

select * from final
