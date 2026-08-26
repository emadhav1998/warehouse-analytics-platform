-- assert_positive_inventory.sql
-- ============================================================
-- Business rule: no inventory record may have a negative
-- quantity_on_hand or quantity_available.
-- A non-empty result set causes this test to FAIL.
-- ============================================================

select
    inventory_fact_key,
    date_key,
    warehouse_id,
    product_id,
    quantity_on_hand,
    quantity_available
from {{ ref('fact_inventory') }}
where quantity_on_hand   < 0
   or quantity_available < 0
