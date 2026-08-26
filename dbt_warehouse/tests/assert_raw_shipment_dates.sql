-- Fails when an expected delivery date precedes its ship date.
select shipment_id
from {{ source('raw', 'shipments') }}
where ship_date > expected_delivery

