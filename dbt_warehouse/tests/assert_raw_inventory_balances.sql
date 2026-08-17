-- Fails for negative quantities or an invalid on-hand balance.
select inventory_id
from {{ source('raw', 'inventory') }}
where quantity_on_hand < 0
   or quantity_reserved < 0
   or quantity_available < 0
   or quantity_on_hand <> quantity_reserved + quantity_available

