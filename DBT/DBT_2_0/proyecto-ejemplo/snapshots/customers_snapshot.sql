{% snapshot customers_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='check',
      check_cols=['country', 'email'],
    )
}}

select * from {{ source('tienda_online_raw', 'raw_customers') }}

{% endsnapshot %}
