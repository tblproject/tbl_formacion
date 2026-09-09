with source as (
    select * from {{ source('jaffle_raw', 'raw_customers') }}
)

select
    id            as customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name as full_name,
    lower(email)  as email,
    created_at::date as registered_at
from source
