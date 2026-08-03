# Fase 05 – Modelos: intermediate y marts

## Objetivo

Completar el DAG construyendo las capas **intermediate** (lógica de negocio) y **marts** (modelo dimensional listo para consumo), y dominar la **selección de nodos**.

---

## 1. El patrón de capas de dbt

dbt Labs recomienda organizar los modelos en tres capas. Cada una tiene una responsabilidad clara:

```
staging/        Limpieza 1:1 con el origen (Fase 04)
   ▼
intermediate/   Lógica de negocio reutilizable: joins, cálculos, agregaciones parciales
   ▼
marts/          Modelo final orientado a negocio: dimensiones (dim_) y hechos (fct_)
```

Ventaja: cada capa depende solo de la anterior, el código es modular y el linaje se lee de izquierda a derecha.

## 2. Capa intermediate

Contiene transformaciones que **no** son el producto final pero se reutilizan. Convención de nombres: `int_...`.

[`int_order_items_priced.sql`](../proyecto/jaffle_shop/models/intermediate/int_order_items_priced.sql) — une líneas de pedido con el catálogo para calcular el importe de cada línea:

```sql
with order_items as ( select * from {{ ref('stg_order_items') }} ),
     products    as ( select * from {{ ref('stg_products') }} )

select
    oi.order_item_id,
    oi.order_id,
    p.product_name,
    oi.quantity,
    p.price_eur,
    round(oi.quantity * p.price_eur, 2) as line_amount_eur
from order_items oi
inner join products p on oi.product_id = p.product_id
```

[`int_orders_aggregated.sql`](../proyecto/jaffle_shop/models/intermediate/int_orders_aggregated.sql) — agrega las líneas para obtener el total de cada pedido:

```sql
select
    order_id,
    count(*)                       as number_of_items,
    round(sum(line_amount_eur), 2) as order_amount_eur
from {{ ref('int_order_items_priced') }}
group by order_id
```

Observa cómo `int_orders_aggregated` referencia a `int_order_items_priced` con `ref()`: dbt encadena las dependencias solo.

## 3. Capa marts: el modelo en estrella

Los **marts** son el producto final que consumen los analistas y los dashboards. Seguimos un **esquema en estrella** clásico: tablas de **hechos** (`fct_`, eventos medibles) rodeadas de **dimensiones** (`dim_`, el contexto descriptivo).

[`dim_customers.sql`](../proyecto/jaffle_shop/models/marts/dim_customers.sql) — dimensión de clientes con métricas derivadas (nº de pedidos, valor de vida):

```sql
customer_orders as (
    select
        o.customer_id,
        min(o.order_date)          as first_order_date,
        count(distinct o.order_id) as number_of_orders,
        round(sum(coalesce(ot.order_amount_eur,0)),2) as lifetime_value_eur
    from {{ ref('stg_orders') }} o
    left join {{ ref('int_orders_aggregated') }} ot on o.order_id = ot.order_id
    group by o.customer_id
)
select c.*, co.first_order_date, co.number_of_orders, co.lifetime_value_eur
from {{ ref('stg_customers') }} c
left join customer_orders co on c.customer_id = co.customer_id
```

[`fct_orders.sql`](../proyecto/jaffle_shop/models/marts/fct_orders.sql) — tabla de hechos, un pedido por fila con importe, nº de artículos, estado y si está pagado. Además une el seed de referencia con `{{ ref('seed_status_map') }}` para añadir `status_description` e `is_final_status` (ejemplo de cómo un seed se integra en el DAG). También tenemos [`dim_products.sql`](../proyecto/jaffle_shop/models/marts/dim_products.sql).

El DAG completo queda así:

```
raw_* (sources) ─▶ stg_* ─▶ int_* ─▶ dim_customers / fct_orders / dim_products
```

## 4. Construir todo

```bash
dbt run --profiles-dir .
```

```
Found 11 models, 6 seeds, 5 sources, 1 snapshot ...
... OK created sql table model marts.fct_orders
Completed successfully
Done. PASS=11 WARN=0 ERROR=0
```

> Recuerda: si es la primera vez sobre una base de datos vacía, ejecuta antes `dbt seed --profiles-dir .` (ver [Fase 04](04-sources-y-staging.md)).

## 5. Selección de nodos (node selection)

Casi nunca quieres ejecutar *todo*. dbt tiene una sintaxis muy expresiva con `-s` (o `--select`) y `--exclude`:

| Sintaxis | Significa |
|----------|-----------|
| `-s dim_customers` | solo ese modelo |
| `-s staging` | todos los modelos de la carpeta staging |
| `-s stg_orders+` | `stg_orders` y **todo lo que depende de él** (aguas abajo) |
| `-s +fct_orders` | `fct_orders` y **todo de lo que depende** (aguas arriba) |
| `-s +fct_orders+` | los antepasados **y** descendientes de `fct_orders` |
| `-s tag:finanzas` | todos los modelos con ese tag |
| `-s marts.*` | por ruta/paquete |
| `--exclude stg_payments` | todo menos ese |
| `-s state:modified+` | lo que cambió respecto a una ejecución previa (CI, Fase 12) |

Ejemplos:

```bash
dbt run --profiles-dir . -s +fct_orders      # reconstruir fct_orders y sus dependencias
dbt run --profiles-dir . -s marts             # solo la capa marts
dbt ls  --profiles-dir . -s staging           # LISTAR (sin ejecutar) qué seleccionaría
```

`dbt ls` es tu amigo para comprobar qué afectaría un selector **antes** de ejecutarlo.

## 6. `{{ config() }}` dentro de un modelo

Además de configurar por carpeta en `dbt_project.yml`, puedes sobreescribir la configuración de un modelo concreto en su cabecera:

```sql
{{ config(materialized='table', tags=['finanzas']) }}
select ...
```

---

## Referencias

- Cómo estructurar un proyecto: <https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview>
- Marts: <https://docs.getdbt.com/best-practices/how-we-structure/4-marts>
- Sintaxis de selección de nodos: <https://docs.getdbt.com/reference/node-selection/syntax>
- Modelado dimensional (Kimball): libro *The Data Warehouse Toolkit* (Kimball & Ross).

## Siguiente paso

➡️ [Fase 06 – dbt Tests (calidad de datos)](06-dbt-tests.md)
