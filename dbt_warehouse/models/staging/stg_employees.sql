with source as (

    select * from {{ source('raw', 'employees') }}

),

renamed as (

    select
        employee_id,
        employee_code,
        first_name,
        last_name,

        -- Derived full name
        first_name + ' ' + last_name as full_name,

        email,
        department,
        job_title,
        warehouse_id,
        shift,
        hire_date,
        hourly_rate,
        cast(is_active as bit) as is_active,
        created_at,
        updated_at

    from source

)

select * from renamed
