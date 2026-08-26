{#
  Une las lineas de pedido con el catalogo de productos para calcular
  el importe de cada linea (precio * cantidad).
#}
with order_items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
)

select
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    p.product_name,
    p.category,
    oi.quantity,
    p.price_eur,
    round(oi.quantity * p.price_eur, 2) as line_amount_eur
from order_items oi
inner join products p on oi.product_id = p.product_id
