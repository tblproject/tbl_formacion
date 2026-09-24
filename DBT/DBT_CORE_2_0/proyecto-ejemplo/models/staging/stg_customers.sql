with source as (

    select * from {{ source('tienda_online_raw', 'raw_customers') }}

),

renamed as (

    select
        customer_id,
        first_name,
        last_name,
        trim(lower(email))     as email,
        country,
        signup_date,
        first_name || ' ' || last_name as full_name

    from source

)

select * from renamed
