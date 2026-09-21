{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='sync_all_columns'
    )
}}

with orders as (

    select * from {{ ref('stg_orders') }}

    {% if is_incremental() %}
    -- Solo se compilan estas líneas cuando ya existe la tabla destino.
    -- Módulo 09: filtramos por fecha para procesar solo pedidos nuevos.
    where order_date > (select coalesce(max(order_date), '1900-01-01') from {{ this }})
    {% endif %}

),

order_items as (

    select * from {{ ref('int_order_items_enriched') }}

),

order_totals as (

    select
        order_id,
        sum(line_amount_eur)   as order_total_eur,
        sum(quantity)          as total_items
    from order_items
    group by 1

),

final as (

    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.status,
        coalesce(order_totals.total_items, 0)      as total_items,
        coalesce(order_totals.order_total_eur, 0)  as order_total_eur

    from orders
    left join order_totals
        on orders.order_id = order_totals.order_id

)

select * from final
