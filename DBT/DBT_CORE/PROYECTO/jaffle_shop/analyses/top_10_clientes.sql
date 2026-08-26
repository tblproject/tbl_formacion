-- Analisis: no crea ninguna tabla; con `dbt compile` se genera el SQL final
-- en target/ para copiarlo y ejecutarlo manualmente (informes ad-hoc).
select
    customer_id,
    full_name,
    number_of_orders,
    lifetime_value_eur
from {{ ref('dim_customers') }}
order by lifetime_value_eur desc
limit 10
