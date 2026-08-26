{#
  Dimension de clientes: atributos del cliente + metricas de negocio derivadas
  (numero de pedidos, valor de vida / lifetime value, primera y ultima compra).
#}
with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

order_totals as (
    select * from {{ ref('int_orders_aggregated') }}
),

customer_orders as (
    select
        o.customer_id,
        min(o.order_date)                 as first_order_date,
        max(o.order_date)                 as most_recent_order_date,
        count(distinct o.order_id)         as number_of_orders,
        round(sum(coalesce(ot.order_amount_eur, 0)), 2) as lifetime_value_eur
    from orders o
    left join order_totals ot on o.order_id = ot.order_id
    group by o.customer_id
)

select
    c.customer_id,
    c.full_name,
    c.email,
    c.registered_at,
    co.first_order_date,
    co.most_recent_order_date,
    coalesce(co.number_of_orders, 0)   as number_of_orders,
    coalesce(co.lifetime_value_eur, 0) as lifetime_value_eur
from customers c
left join customer_orders co on c.customer_id = co.customer_id
