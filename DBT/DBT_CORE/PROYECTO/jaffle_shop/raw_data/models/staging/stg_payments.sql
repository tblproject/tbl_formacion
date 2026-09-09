with source as (
    select * from {{ source('jaffle_raw', 'raw_payments') }}
)

select
    id              as payment_id,
    order_id,
    payment_method,
    amount_cents,
    {{ cents_to_dollars('amount_cents') }} as amount_eur,
    created_at::date as paid_at
from source
