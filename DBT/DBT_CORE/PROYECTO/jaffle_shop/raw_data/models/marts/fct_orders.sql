{#
  Tabla de hechos de pedidos: una fila por pedido con su importe, numero de
  articulos, estado y si esta pagado. Se enriquece con la descripcion del
  estado usando el seed de referencia seed_status_map (referenciado con ref).
#}
with orders as (
    select * from {{ ref('stg_orders') }}
),

order_totals as (
    select * from {{ ref('int_orders_aggregated') }}
),

status_map as (
    select * from {{ ref('seed_status_map') }}
),

payments as (
    select
        order_id,
        round(sum(amount_eur), 2) as amount_paid_eur,
        count(*)                  as number_of_payments
    from {{ ref('stg_payments') }}
    group by order_id
)

select
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    sm.status_description,
    sm.is_final                      as is_final_status,
    coalesce(ot.number_of_items, 0)  as number_of_items,
    coalesce(ot.order_amount_eur, 0) as order_amount_eur,
    coalesce(p.amount_paid_eur, 0)   as amount_paid_eur,
    (p.order_id is not null)         as is_paid
from orders o
left join order_totals ot on o.order_id = ot.order_id
left join status_map sm on o.order_status = sm.order_status
left join payments p on o.order_id = p.order_id
