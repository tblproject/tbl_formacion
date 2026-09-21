with orders as (

    select * from {{ ref('stg_orders') }}

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
