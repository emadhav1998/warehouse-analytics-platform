-- assert_valid_shipment_status.sql
-- ============================================================
-- Business rule: every shipment whose status is 'Delivered'
-- must have a non-null actual_delivery date.
-- A non-empty result set causes this test to FAIL.
-- ============================================================

select
    shipment_fact_key,
    shipment_id,
    shipment_number,
    warehouse_id,
    status,
    actual_delivery
from {{ ref('fact_shipment') }}
where status          = 'Delivered'
  and actual_delivery is null
