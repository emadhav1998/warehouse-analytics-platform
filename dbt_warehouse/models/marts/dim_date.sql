with date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2024-01-01' as date)",
        end_date="cast('2027-12-31' as date)"
    ) }}

),

dates as (

    select
        cast(date_day as date)                                                  as date_key,
        year(date_day)                                                          as year,
        month(date_day)                                                         as month_number,
        day(date_day)                                                           as day_of_month,
        datename(month,   date_day)                                             as month_name,
        left(datename(month, date_day), 3)                                      as month_short,
        datename(weekday, date_day)                                             as day_name,
        datepart(weekday, date_day)                                             as day_of_week,
        datepart(dayofyear, date_day)                                           as day_of_year,
        datepart(week,    date_day)                                             as week_of_year,
        datepart(quarter, date_day)                                             as quarter_number,
        'Q' + cast(datepart(quarter, date_day) as varchar)                     as quarter_name,

        cast(year(date_day) as varchar)
            + '-Q' + cast(datepart(quarter, date_day) as varchar)              as year_quarter,

        cast(year(date_day) as varchar)
            + '-' + right('0' + cast(month(date_day) as varchar), 2)           as year_month,

        case
            when datepart(weekday, date_day) in (1, 7) then 1
            else 0
        end                                                                     as is_weekend,

        -- ── Fiscal calendar (year starts July 1) ──────────────────────────
        case
            when month(date_day) >= 7 then year(date_day) + 1
            else                           year(date_day)
        end                                                                     as fiscal_year,

        case
            when month(date_day) >= 7 then month(date_day) - 6
            else                           month(date_day) + 6
        end                                                                     as fiscal_month,

        case
            when month(date_day) between  7 and  9 then 1
            when month(date_day) between 10 and 12 then 2
            when month(date_day) between  1 and  3 then 3
            else                                        4
        end                                                                     as fiscal_quarter

    from date_spine

)

select * from dates
