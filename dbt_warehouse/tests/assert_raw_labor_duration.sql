-- Fails for incomplete, negative, or greater-than-24-hour activity intervals.
select activity_id
from {{ source('raw', 'labor_activities') }}
where (start_time is null and end_time is not null)
   or (start_time is not null and end_time is null)
   or datediff(minute, start_time, end_time) < 0
   or datediff(minute, start_time, end_time) > 1440

