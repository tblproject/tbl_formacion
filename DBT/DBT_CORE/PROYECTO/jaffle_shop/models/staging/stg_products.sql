with source as (
    select * from {{ source('jaffle_raw', 'raw_products') }}
)

select
    id           as product_id,
    name         as product_name,
    category,
    price_cents,
    {{ cents_to_dollars('price_cents') }} as price_eur
from source
