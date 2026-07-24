-- assert_labor_hours_range.sql
-- ============================================================
-- Business rule: total_hours for any single labor grouping
-- (employee + activity_type + date) must be in the range
-- [0, 24]. Values outside this range indicate bad source data
-- or a calculation error.
-- A non-empty result set causes this test to FAIL.
-- ============================================================

select
    labor_fact_key,
    employee_id,
    employee_name,
    activity_date,
    activity_type,
    total_hours
from {{ ref('fact_labor') }}
where total_hours < 0
   or total_hours > 24
