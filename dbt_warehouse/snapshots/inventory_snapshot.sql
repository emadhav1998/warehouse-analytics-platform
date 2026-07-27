{% snapshot inventory_snapshot %}

{{
    config(
        target_schema = 'staging',
        unique_key    = 'inventory_id',
        strategy      = 'check',
        check_cols    = [
            'quantity_on_hand',
            'quantity_reserved',
            'quantity_available',
            'bin_location'
        ]
    )
}}

-- SCD Type 2 snapshot of raw.inventory.
-- dbt will insert a new row whenever any of the check_cols change,
-- preserving the full history of stock movements per warehouse/product.
select * from {{ source('raw', 'inventory') }}

{% endsnapshot %}
