-- Materialización "ephemeral": no crea objeto en la base de datos,
-- se inyecta como CTE en los modelos que hacen ref() de este modelo.
-- Ver Módulo 06 (Materializaciones).

with order_items as (

    select * from {{ ref('stg_order_items') }}

),

products as (

    select * from {{ ref('stg_products') }}

),

enriched as (

    select
        order_items.order_item_id,
        order_items.order_id,
        order_items.product_id,
        products.product_name,
        products.category,
        order_items.quantity,
        products.unit_price_eur,
        round(order_items.quantity * products.unit_price_eur, 2) as line_amount_eur

    from order_items
    left join products
        on order_items.product_id = products.product_id

)

select * from enriched
