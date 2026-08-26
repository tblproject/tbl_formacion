{#
  Modelo INCREMENTAL: en la primera ejecucion crea la tabla completa; en las
  siguientes solo procesa e inserta los pedidos nuevos (order_date posterior
  al maximo ya cargado). Evita reprocesar todo el historico.

  - unique_key evita duplicados si un pedido se reprocesa.
  - El bloque is_incremental() solo se aplica cuando la tabla YA existe.
#}
{{
  config(
    materialized = 'incremental',
    unique_key   = 'order_id'
  )
}}

with orders as (
    select * from {{ ref('fct_orders') }}
    where order_date >= '{{ var("fecha_corte_incremental") }}'
)

select *
from orders

{% if is_incremental() %}
  -- Solo pedidos mas recientes que el maximo ya cargado en la tabla destino
  where order_date > (select coalesce(max(order_date), '1900-01-01') from {{ this }})
{% endif %}
