# Módulo 09 · Modelos incrementales y snapshots

## 1. El problema que resuelve `incremental`

`fct_orders` (Módulo 06) es `materialized='table'`: en **cada** `dbt
run`, dbt hace `DROP` + `CREATE TABLE AS` recalculando el 100% de las
filas desde cero. Con 25 pedidos es instantáneo; con 500 millones de
filas, carísimo. Un modelo **incremental** solo procesa las filas
nuevas/modificadas desde la última ejecución y las **inserta/actualiza**
sobre la tabla ya existente.

## 2. `fct_orders_incremental.sql`, explicado por bloques

```sql
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='sync_all_columns'
    )
}}
```

- `materialized='incremental'`: activa la estrategia.
- `unique_key='order_id'`: cuando dbt encuentra un `order_id` que ya
  existe en la tabla destino, lo **actualiza** (merge/upsert) en lugar de
  duplicarlo. Sin `unique_key`, el comportamiento por defecto es solo
  `INSERT` (append).
- `on_schema_change='sync_all_columns'`: si en el futuro añades/quitas
  columnas al modelo, dbt actualiza el esquema de la tabla destino en
  vez de fallar.

```sql
with orders as (

    select * from {{ ref('stg_orders') }}

    {% if is_incremental() %}
    where order_date > (select coalesce(max(order_date), '1900-01-01') from {{ this }})
    {% endif %}

),
```

- `is_incremental()` es `false` la **primera** vez que se ejecuta el
  modelo (la tabla destino aún no existe) → se procesan **todas** las
  filas, como una tabla normal.
- A partir de la segunda ejecución, es `true` → el filtro `where
  order_date > (select max(order_date) from {{ this }})` limita el
  `SELECT` a pedidos posteriores al último ya procesado.
- `{{ this }}` es una referencia especial a la propia tabla que el
  modelo está construyendo — solo tiene sentido dentro de un modelo
  incremental.

## 3. Ejecutarlo: primera carga (full)

```bash
dbt run --select fct_orders_incremental
```

Salida esperada:

```
1 of 1 OK created sql incremental model marts.fct_orders_incremental .. [INSERT 25 in 0.03s]
```

Los 25 pedidos de `raw_orders.csv` se procesan de una sola vez (fue la
primera ejecución, `is_incremental()` fue `false`).

## 4. Simular la llegada de pedidos nuevos

`seeds/raw_orders_batch2.csv` contiene 5 pedidos con fechas posteriores
(mayo 2024). Añádelos al final de `raw_orders.csv` (cópialos a mano o
con el comando siguiente) y vuelve a cargarlos:

```bash
tail -n +2 seeds/raw_orders_batch2.csv >> seeds/raw_orders.csv
dbt seed --select raw_orders
dbt run --select stg_orders fct_orders_incremental
```

Salida esperada en el paso incremental:

```
1 of 1 OK created sql incremental model marts.fct_orders_incremental .. [INSERT 5 in 0.02s]
```

Solo **5 filas**, no 30: el filtro `is_incremental()` ha funcionado.
Compáralo con `fct_orders` (la versión `table`), que sí recalcularía las
30 filas por completo.

## 5. `--full-refresh`: forzar una reconstrucción completa

Necesario cuando cambias la lógica del modelo de forma incompatible con
las filas ya cargadas (p. ej. añades una columna calculada distinta), o
simplemente quieres partir de cero:

```bash
dbt run --select fct_orders_incremental --full-refresh
```

Esto hace un `DROP` + reconstrucción completa, exactamente como si fuera
`materialized='table'`, y a partir de ahí vuelve a comportarse de forma
incremental en las siguientes ejecuciones.

## 6. Estrategias incrementales (avanzado)

DuckDB soporta principalmente la estrategia `delete+insert` (la que
usamos, implícita al declarar `unique_key`). Otros adaptadores (Snowflake,
BigQuery, Databricks) ofrecen además `merge` o `microbatch` — mismo
concepto (procesar solo lo nuevo), distinta implementación SQL bajo el
capó. No es necesario cambiar nada en tu modelo para beneficiarte de la
estrategia por defecto del adaptador.

## 7. Snapshots: histórico de cambios (SCD tipo 2)

Un snapshot resuelve un problema distinto: capturar **cómo cambia una
fila a lo largo del tiempo** en una tabla origen que se sobrescribe
(p. ej., si un cliente cambia de país, quieres poder responder "¿en qué
país estaba este cliente el 3 de marzo?").

`snapshots/customers_snapshot.sql`:

```sql
{% snapshot customers_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='check',
      check_cols=['country', 'email'],
    )
}}

select * from {{ source('tienda_online_raw', 'raw_customers') }}

{% endsnapshot %}
```

- `strategy='check'`: dbt compara los valores de `check_cols` entre la
  última versión guardada y la actual; si cambian, cierra la fila
  antigua (`dbt_valid_to`) y abre una nueva (`dbt_valid_from`). La
  alternativa es `strategy='timestamp'`, que usa una columna
  `updated_at` de la fuente en vez de comparar columna a columna.

Ejecuta:

```bash
dbt snapshot
```

Después, edita `seeds/raw_customers.csv` y cambia el país de un cliente
(por ejemplo, el cliente 3 de `PT` a `ES`), recarga y vuelve a lanzar el
snapshot:

```bash
dbt seed --select raw_customers
dbt snapshot
```

Consulta el resultado:

```bash
python3 -c "
import duckdb
con = duckdb.connect('tienda_online.duckdb')
print(con.sql('select customer_id, country, dbt_valid_from, dbt_valid_to from snapshots.customers_snapshot order by customer_id'))
"
```

Verás **dos filas** para ese cliente: la versión antigua con
`dbt_valid_to` relleno, y la nueva con `dbt_valid_to` nulo (vigente).

## 8. `dbt build` con todo junto

A partir de este módulo ya tiene sentido usar el comando completo:

```bash
dbt build
```

Ejecuta, en el orden correcto del DAG: `seed` → `snapshot` → `run`
(staging → intermediate → marts, incluyendo el modelo incremental) →
`test`, parando en cualquier rama del grafo donde algo falle.
