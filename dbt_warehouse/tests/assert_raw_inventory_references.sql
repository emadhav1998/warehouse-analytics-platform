-- Fails when an inventory record references a missing warehouse or product.
select i.inventory_id
from {{ source('raw', 'inventory') }} i
left join {{ source('raw', 'warehouses') }} w on i.warehouse_id = w.warehouse_id
left join {{ source('raw', 'products') }} p on i.product_id = p.product_id
where w.warehouse_id is null
   or p.product_id is null

