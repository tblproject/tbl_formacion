select
    product_id,
    product_name,
    category,
    price_eur
from {{ ref('stg_products') }}
