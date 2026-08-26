-- Fails when a labor activity references a missing employee or warehouse.
select la.activity_id
from {{ source('raw', 'labor_activities') }} la
left join {{ source('raw', 'employees') }} e on la.employee_id = e.employee_id
left join {{ source('raw', 'warehouses') }} w on la.warehouse_id = w.warehouse_id
where (e.employee_id is null and la.employee_id is not null)
   or (w.warehouse_id is null and la.warehouse_id is not null)

