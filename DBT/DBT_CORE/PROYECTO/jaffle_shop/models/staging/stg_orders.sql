with source as (
    select * from {{ source('jaffle_raw', 'raw_orders') }}
)

select
    id            as order_id,
    user_id       as customer_id,
    order_date::date as order_date,
    status        as order_status
from source
