-- Fails when a shipment or shipment item has an invalid parent reference.
select cast(s.shipment_id as varchar(50)) as record_id, 'shipment_warehouse' as violation
from {{ source('raw', 'shipments') }} s
left join {{ source('raw', 'warehouses') }} w on s.warehouse_id = w.warehouse_id
where w.warehouse_id is null and s.warehouse_id is not null

union all

select cast(si.shipment_item_id as varchar(50)) as record_id, 'shipment_item' as violation
from {{ source('raw', 'shipment_items') }} si
left join {{ source('raw', 'shipments') }} s on si.shipment_id = s.shipment_id
where s.shipment_id is null

