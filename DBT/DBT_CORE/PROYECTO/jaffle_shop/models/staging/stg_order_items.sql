with source as (
    select * from {{ source('jaffle_raw', 'raw_order_items') }}
)

select
    id          as order_item_id,
    order_id,
    product_id,
    quantity
from source
