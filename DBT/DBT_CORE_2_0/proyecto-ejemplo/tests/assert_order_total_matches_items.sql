-- Test singular (Módulo 07): comprueba una regla de negocio muy concreta.
-- El test PASA si la query no devuelve ninguna fila.
--
-- Regla: si un pedido tiene artículos (total_items > 0), su importe
-- (order_total_eur) también debe ser mayor que cero.

select
    order_id,
    total_items,
    order_total_eur
from {{ ref('fct_orders') }}
where total_items > 0
  and order_total_eur <= 0
