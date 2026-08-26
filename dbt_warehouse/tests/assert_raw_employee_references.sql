-- Fails when an employee references a missing warehouse.
select e.employee_id
from {{ source('raw', 'employees') }} e
left join {{ source('raw', 'warehouses') }} w on e.warehouse_id = w.warehouse_id
where w.warehouse_id is null
  and e.warehouse_id is not null

