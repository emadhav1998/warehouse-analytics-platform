{{
    config(
        post_hook="{{ ensure_nonclustered_index(
            this,
            'IX_fact_shipment_date_warehouse_status',
            ['date_key', 'warehouse_id', 'status', 'delivery_performance'],
            ['carrier', 'shipping_cost', 'actual_transit_days']
        ) }}"
    )
}}

with shipments as (

    select * from {{ ref('stg_shipments') }}

),

items as (

    -- Pre-aggregate line items to one row per shipment
    select
        shipment_id,
        count(*)        as line_item_count,
        sum(quantity)   as total_quantity,
        sum(line_total) as total_line_value
    from {{ ref('stg_shipment_items') }}
    group by shipment_id

),

dim_wh as (

    select warehouse_key, warehouse_id from {{ ref('dim_warehouse') }}

),

final as (

    select
        -- ── Surrogate key (one row per shipment) ──────────────────────────
        {{ dbt_utils.generate_surrogate_key(['s.shipment_id']) }}
                                                as shipment_fact_key,

        -- ── Dimension keys ────────────────────────────────────────────────
        d.warehouse_key,
        s.ship_date                             as date_key,

        -- ── Degenerate dimensions / natural keys ──────────────────────────
        s.shipment_id,
        s.shipment_number,
        s.warehouse_id,
        s.order_number,
        s.shipment_type,
        s.status,
        s.carrier,
        s.delivery_performance,

        -- ── Volume measures ───────────────────────────────────────────────
        s.total_items,
        s.total_weight_lbs,
        s.shipping_cost,

        -- ── Transit-time measures ─────────────────────────────────────────
        s.expected_transit_days,
        s.actual_transit_days,

        -- ── Line-item aggregates (from stg_shipment_items) ────────────────
        coalesce(i.line_item_count,  0)         as line_item_count,
        coalesce(i.total_quantity,   0)         as total_quantity,
        coalesce(i.total_line_value, 0)         as total_line_value,

        -- ── Derived lateness flag ─────────────────────────────────────────
        case
            when s.status = 'Delivered'
             and s.actual_transit_days > s.expected_transit_days then 1
            else 0
        end                                     as is_late,

        -- ── Transit efficiency ratio (actual / expected) ──────────────────
        case
            when s.actual_transit_days   is not null
             and s.expected_transit_days >  0
                then cast(s.actual_transit_days   as decimal(8, 2))
                     / cast(s.expected_transit_days as decimal(8, 2))
            else null
        end                                     as transit_efficiency_ratio,

        -- ── Date attributes (kept as degenerate dims for filtering) ───────
        s.ship_date,
        s.expected_delivery,
        s.actual_delivery

    from shipments s
    left join items  i on s.shipment_id  = i.shipment_id
    left join dim_wh d on s.warehouse_id = d.warehouse_id

)

select * from final
