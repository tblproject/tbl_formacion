with source as (

    select * from {{ source('tienda_online_raw', 'raw_products') }}

),

renamed as (

    select
        product_id,
        product_name,
        category,
        {{ cents_to_euros('unit_price_cents') }} as unit_price_eur,
        is_active

    from source

)

select * from renamed
