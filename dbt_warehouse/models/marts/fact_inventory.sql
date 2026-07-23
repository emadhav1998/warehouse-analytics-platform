with inventory as (

    select * from {{ ref('int_inventory_daily_snapshot') }}

),

dim_wh as (

    select warehouse_key, warehouse_id from {{ ref('dim_warehouse') }}

),

dim_prod as (

    select product_key, product_id from {{ ref('dim_product') }}

),

final as (

    select
        -- ── Surrogate key (composite: date + warehouse + product) ──────────
        {{ dbt_utils.generate_surrogate_key([
            'i.snapshot_date',
            'i.warehouse_id',
            'i.product_id'
        ]) }}                               as inventory_fact_key,

        -- ── Dimension keys ────────────────────────────────────────────────
        d.warehouse_key,
        p.product_key,
        i.snapshot_date                     as date_key,

        -- ── Degenerate dimensions / natural keys ──────────────────────────
        i.warehouse_id,
        i.product_id,
        i.warehouse_name,
        i.category,
        i.sku,

        -- ── Stock-level measures ──────────────────────────────────────────
        i.quantity_on_hand,
        i.quantity_reserved,
        i.quantity_available,
        i.stock_status,

        -- ── Value measures ────────────────────────────────────────────────
        i.inventory_value_at_cost,
        i.inventory_value_at_retail,

        -- ── Operational flags ─────────────────────────────────────────────
        i.reorder_point,
        i.needs_reorder,
        i.expiring_within_30_days

    from inventory  i
    left join dim_wh   d on i.warehouse_id = d.warehouse_id
    left join dim_prod p on i.product_id   = p.product_id

)

select * from final
