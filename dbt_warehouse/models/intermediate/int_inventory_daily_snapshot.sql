with inventory as (

    select * from {{ ref('stg_inventory') }}

),

products as (

    select * from {{ ref('stg_products') }}

),

warehouses as (

    select * from {{ ref('stg_warehouses') }}

),

joined as (

    select
        i.snapshot_date,
        i.warehouse_id,
        w.warehouse_name,
        w.warehouse_type,
        i.product_id,
        p.sku,
        p.product_name,
        p.category,
        p.subcategory,

        -- Stock quantities
        i.quantity_on_hand,
        i.quantity_reserved,
        i.quantity_available,
        i.stock_status,

        -- Pricing
        p.unit_cost,
        p.unit_price,

        -- Derived inventory value
        i.quantity_on_hand * p.unit_cost  as inventory_value_at_cost,
        i.quantity_on_hand * p.unit_price as inventory_value_at_retail,

        -- Reorder signal
        p.reorder_point,
        case
            when i.quantity_available <= p.reorder_point then 1
            else 0
        end as needs_reorder,

        -- Expiry monitoring
        i.expiry_date,
        case
            when i.expiry_date is not null
             and i.expiry_date <= dateadd(day, 30, i.snapshot_date)
                then 1
            else 0
        end as expiring_within_30_days

    from inventory    i
    inner join products   p on i.product_id  = p.product_id
    inner join warehouses w on i.warehouse_id = w.warehouse_id

)

select * from joined
