with source as (

    select * from {{ source('tienda_online_raw', 'raw_order_items') }}

),

renamed as (

    select
        order_item_id,
        order_id,
        product_id,
        quantity

    from source

)

select * from renamed
