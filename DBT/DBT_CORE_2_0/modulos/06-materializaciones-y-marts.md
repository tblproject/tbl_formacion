# Módulo 06 · Materializaciones y marts

## 1. ¿Qué es una materialización?

Es la estrategia que usa dbt para convertir el `SELECT` de tu modelo en
un objeto físico (o no) dentro de la base de datos. Se configura con
`materialized` en `dbt_project.yml` (por carpeta) o dentro del propio
`.sql` con un bloque `{{ config(...) }}` (por modelo, y siempre gana el
config del modelo sobre el de la carpeta).

| Materialización | Qué genera | Cuándo usarla |
|---|---|---|
| `view` | `CREATE VIEW` | Capa staging: barata, siempre actualizada, sin duplicar datos. |
| `table` | `CREATE TABLE AS` (drop + recreate en cada `dbt run`) | Marts pequeñas/medianas que se consultan mucho y no cambian de esquema constantemente. |
| `ephemeral` | Nada físico: se inyecta como CTE en los modelos que lo referencian | Lógica de apoyo intermedia que no necesitas consultar directamente (nuestra `int_order_items_enriched`). |
| `incremental` | Tabla que solo se actualiza con las filas nuevas/cambiadas | Tablas grandes de hechos, donde recalcular todo en cada ejecución es caro. Ver Módulo 09. |

## 2. Configurarlo por carpeta (ya lo tienes hecho)

```yaml
# dbt_project.yml
models:
  tienda_online:
    staging:
      +materialized: view
    intermediate:
      +materialized: ephemeral
    marts:
      core:
        +materialized: table
        +schema: marts
```

## 3. Configurarlo por modelo

También se puede fijar (o sobrescribir) dentro del propio fichero:

```sql
{{ config(materialized='table') }}

select ...
```

Es lo que hacemos en `fct_orders_incremental.sql` (Módulo 09), donde
necesitamos una configuración distinta al resto de `marts/core`.

## 4. La capa intermedia: `int_order_items_enriched`

Abre `models/intermediate/int_order_items_enriched.sql`. Combina líneas
de pedido con el catálogo de productos para calcular el importe de cada
línea:

```sql
with order_items as (
    select * from {{ ref('stg_order_items') }}
),
products as (
    select * from {{ ref('stg_products') }}
),
enriched as (
    select
        order_items.order_item_id,
        order_items.order_id,
        products.product_name,
        products.category,
        order_items.quantity,
        products.unit_price_eur,
        round(order_items.quantity * products.unit_price_eur, 2) as line_amount_eur
    from order_items
    left join products
        on order_items.product_id = products.product_id
)
select * from enriched
```

Como es `ephemeral`, **no verás ninguna tabla ni vista** llamada
`int_order_items_enriched` en la base de datos tras un `dbt run`. Su SQL
se "pega" como CTE dentro de cada modelo que hace
`{{ ref('int_order_items_enriched') }}` — en nuestro caso, `fct_orders`.

## 5. La capa marts: modelos `dim_` y `fct_`

- `dim_customers.sql`: una fila por cliente + métricas agregadas de
  pedidos (número de pedidos, primera/última fecha).
- `dim_products.sql`: catálogo de productos, prácticamente 1:1 con
  staging (a veces una dimensión es así de simple, no pasa nada).
- `fct_orders.sql`: una fila por pedido, con importe total y nº de
  artículos — combina `stg_orders` con la capa intermedia.

Fíjate en cómo `fct_orders` referencia el modelo ephemeral exactamente
igual que referenciaría cualquier otro modelo:

```sql
order_items as (
    select * from {{ ref('int_order_items_enriched') }}
),
```

dbt resuelve en tiempo de compilación si eso se traduce en un `JOIN`
contra una tabla real o en un CTE embebido — **para quien escribe el
`SELECT` es transparente**. Esta es la gran ventaja de `ref()` frente a
escribir nombres de tabla a mano.

## 6. Ejecutar toda la cadena

```bash
dbt run --select staging+
```

El `+` al final indica "este nodo y todo lo que depende de él". Deberías
ver 4 vistas (staging) + 3 tablas (`dim_customers`, `dim_products`,
`fct_orders`) — `int_order_items_enriched` no aparece como paso propio
porque es ephemeral.

Comprueba el resultado:

```bash
python3 -c "
import duckdb
con = duckdb.connect('tienda_online.duckdb')
print(con.sql('select * from marts.fct_orders order by order_total_eur desc limit 5'))
"
```

## 7. Esquemas personalizados: `generate_schema_name`

Habrás notado que las tablas de marts caen en un esquema `marts` y las
de staging en `staging`, en vez de todas ir al esquema `main` por
defecto. Eso lo controla `+schema: marts` combinado con el macro
`generate_schema_name` que sobrescribimos en
`macros/generate_schema_name.sql` — lo explicamos con detalle en el
Módulo 08 (Macros y Jinja), ya que es el ejemplo perfecto de macro que
dbt invoca automáticamente en cada ejecución.

## 8. Resumen del DAG hasta ahora

```
raw_customers ─┐
raw_orders ─────┼─► stg_* (view) ──► int_order_items_enriched (ephemeral) ──► fct_orders (table)
raw_products ───┤                                                          
raw_order_items ┘                     stg_customers ──► dim_customers (table)
                                       stg_products  ──► dim_products (table)
```

Visualízalo tú mismo:

```bash
dbt docs generate && dbt docs serve
```

(lo retomamos con más detalle en el Módulo 10).
