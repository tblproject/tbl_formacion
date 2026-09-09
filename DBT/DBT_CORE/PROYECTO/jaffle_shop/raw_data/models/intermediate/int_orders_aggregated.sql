{#
  Agrega las lineas de cada pedido: numero de articulos e importe total.
#}
with items as (
    select * from {{ ref('int_order_items_priced') }}
)

select
    order_id,
    count(*)                       as number_of_items,
    sum(quantity)                  as total_units,
    round(sum(line_amount_eur), 2) as order_amount_eur
from items
group by order_id
