{% test row_count_anomaly(
    model,
    date_column,
    lookback_days=14,
    max_deviation_pct=0.50,
    min_baseline_days=3
) %}

{#
  Returns the latest daily partition when its row count differs from the
  preceding partitions' average by more than max_deviation_pct. The test is
  intentionally silent until enough baseline days are available.
#}

with daily_counts as (

    select
        cast({{ date_column }} as date) as date_day,
        count_big(*) as row_count
    from {{ model }}
    where cast({{ date_column }} as date) >= dateadd(
        day,
        -{{ lookback_days }},
        (select max(cast({{ date_column }} as date)) from {{ model }})
    )
    group by cast({{ date_column }} as date)

),

latest_date as (

    select max(date_day) as date_day
    from daily_counts

),

latest_count as (

    select
        daily_counts.date_day,
        daily_counts.row_count
    from daily_counts
    inner join latest_date
        on daily_counts.date_day = latest_date.date_day

),

baseline as (

    select
        count(*) as baseline_days,
        avg(cast(daily_counts.row_count as decimal(38, 4))) as average_row_count
    from daily_counts
    cross join latest_date
    where daily_counts.date_day < latest_date.date_day

)

select
    latest_count.date_day,
    latest_count.row_count,
    baseline.average_row_count,
    abs(latest_count.row_count - baseline.average_row_count)
        / nullif(baseline.average_row_count, 0) as deviation_pct
from latest_count
cross join baseline
where baseline.baseline_days >= {{ min_baseline_days }}
  and baseline.average_row_count > 0
  and abs(latest_count.row_count - baseline.average_row_count)
        / nullif(baseline.average_row_count, 0) > {{ max_deviation_pct }}

{% endtest %}
