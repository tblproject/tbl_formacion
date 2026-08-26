{#
  Snapshot (SCD tipo 2): guarda el historico de cambios de estado de cada
  pedido. Cada vez que ejecutas `dbt snapshot`, si el estado de un pedido ha
  cambiado, dbt cierra la fila anterior (dbt_valid_to) y crea una nueva.
  Estrategia 'check': detecta cambios comparando las columnas de check_cols.
#}
{% snapshot orders_snapshot %}

{{
  config(
    target_schema='snapshots',
    unique_key='order_id',
    strategy='check',
    check_cols=['order_status']
  )
}}

select
    order_id,
    customer_id,
    order_date,
    order_status
from {{ ref('stg_orders') }}

{% endsnapshot %}
