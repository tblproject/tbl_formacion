-- Test singular: no deberia existir ningun pedido cuyo importe pagado
-- supere en mas de 1 centimo el importe del propio pedido.
-- Un test singular es solo una consulta SQL: si devuelve filas, FALLA.
select
    order_id,
    order_amount_eur,
    amount_paid_eur
from {{ ref('fct_orders') }}
where amount_paid_eur > order_amount_eur + 0.01
