{#
  kpi_calculations.sql
  =====================
  Reusable Jinja macros for KPI calculations used across mart models.
  Import with: {{ calculate_fill_rate(fulfilled_col, ordered_col) }}
#}


{# ── Fill Rate ──────────────────────────────────────────────────────────────
   Measures the percentage of order demand that was fulfilled.
   fill_rate = (fulfilled_qty / ordered_qty) × 100
   Returns 0 when ordered_qty = 0 to prevent division-by-zero.
#}
{% macro calculate_fill_rate(fulfilled_qty, ordered_qty) %}
    case
        when {{ ordered_qty }} > 0
            then cast({{ fulfilled_qty }} as decimal(12, 4))
                 / cast({{ ordered_qty }} as decimal(12, 4)) * 100
        else 0
    end
{% endmacro %}


{# ── Inventory Turnover ─────────────────────────────────────────────────────
   Measures how many times inventory is sold or used in a period.
   turnover = COGS / average_inventory_value
   Returns 0 when avg_inventory = 0 to prevent division-by-zero.
#}
{% macro calculate_inventory_turnover(cogs, avg_inventory) %}
    case
        when {{ avg_inventory }} > 0
            then {{ cogs }} / {{ avg_inventory }}
        else 0
    end
{% endmacro %}


{# ── Dock-to-Stock Hours ────────────────────────────────────────────────────
   Measures the elapsed time (in decimal hours) between receiving a shipment
   at the dock and completing the putaway in the warehouse.
   dock_to_stock_hours = DATEDIFF(minute, received_time, putaway_time) / 60.0
#}
{% macro calculate_dock_to_stock_hours(received_time, putaway_time) %}
    cast(
        datediff(minute, {{ received_time }}, {{ putaway_time }})
        as decimal(10, 2)
    ) / 60.0
{% endmacro %}


{# ── Perfect Order Rate ─────────────────────────────────────────────────────
   Measures the percentage of orders that are delivered complete, on time,
   undamaged, and with correct documentation.
   perfect_order_rate = (perfect_orders / total_orders) × 100
   Returns 0 when total_orders = 0 to prevent division-by-zero.
#}
{% macro calculate_perfect_order_rate(perfect_orders, total_orders) %}
    case
        when {{ total_orders }} > 0
            then cast({{ perfect_orders }} as decimal(12, 4))
                 / cast({{ total_orders }} as decimal(12, 4)) * 100
        else 0
    end
{% endmacro %}
