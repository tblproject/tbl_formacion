---
tags:
  - DBT_CORE
---

# Fase 10 – Modelos incrementales

## Objetivo

Construir tablas que **solo procesan las filas nuevas** en cada ejecución, en lugar de reconstruirse enteras. Es la clave para que dbt escale a tablas de hechos grandes.

---

## 1. El problema

Un modelo materializado como `table` se reconstruye **por completo** en cada `dbt run` (`CREATE TABLE ... AS SELECT ...` desde cero). Con miles de filas da igual, pero con cientos de millones es lento y caro. La materialización **`incremental`** procesa únicamente lo que ha cambiado desde la última vez y lo **inserta** (o **fusiona**) en la tabla ya existente.

## 2. Cómo funciona: `is_incremental()`

Un modelo incremental tiene dos comportamientos:

1. **Primera ejecución** (o con `--full-refresh`): la tabla no existe, así que dbt la crea **entera**.
2. **Ejecuciones siguientes**: la tabla ya existe, así que dbt aplica un filtro extra para traer solo lo nuevo.

Ese filtro extra va dentro de un bloque `{% if is_incremental() %}`, que **solo se activa cuando la tabla ya existe**.

## 3. Nuestro modelo incremental

[`models/marts/fct_orders_incremental.sql`](../proyecto/jaffle_shop/models/marts/fct_orders_incremental.sql):

```sql
{{
  config(
    materialized = 'incremental',
    unique_key   = 'order_id'
  )
}}

with orders as (
    select * from {{ ref('fct_orders') }}
    where order_date >= '{{ var("fecha_corte_incremental") }}'
)

select * from orders

{% if is_incremental() %}
  -- Solo pedidos más recientes que el máximo ya cargado en la tabla destino
  where order_date > (select coalesce(max(order_date), '1900-01-01') from {{ this }})
{% endif %}
```

Piezas clave:

- **`materialized = 'incremental'`**: activa el comportamiento.
- **`unique_key = 'order_id'`**: si una fila que ya existía vuelve a aparecer, dbt la **actualiza** en lugar de duplicarla. Sin `unique_key`, las filas solo se añaden (append).
- **`{{ this }}`**: la propia tabla destino. La usamos para preguntar "¿cuál es el `order_date` más alto que ya tengo cargado?".
- **`{{ var(...) }}`**: la variable `fecha_corte_incremental` (definida en `dbt_project.yml`) marca desde qué fecha nos interesan los datos.

## 4. Probar el comportamiento

```bash
cd proyecto/jaffle_shop

# 1a ejecución: crea la tabla entera
dbt run --profiles-dir . -s fct_orders_incremental

# 2a ejecución: solo procesaría filas con order_date mayor al máximo ya cargado
dbt run --profiles-dir . -s fct_orders_incremental
```

En la segunda pasada, como no hay pedidos con fecha posterior al máximo, no inserta nada nuevo: exactamente lo que queremos. Si llegaran pedidos nuevos al origen, solo esos se procesarían.

### Forzar la reconstrucción completa

Cuando cambias la lógica del modelo, la tabla incremental **no** se recalcula sola (solo mira lo nuevo). Para reconstruirla desde cero:

```bash
dbt run --profiles-dir . -s fct_orders_incremental --full-refresh
```

> Regla de oro: cada vez que modifiques el `SELECT` de un modelo incremental, ejecútalo una vez con `--full-refresh`.

## 5. Estrategias incrementales

La opción `incremental_strategy` decide *cómo* se combinan las filas nuevas con la tabla existente. Depende del adaptador:

| Estrategia | Qué hace | Notas |
|------------|----------|-------|
| `append` | Solo inserta las filas nuevas | Rápida, pero puede duplicar si reprocesas. Sin `unique_key`. |
| `delete+insert` | Borra las filas que coinciden con `unique_key` y reinserta | Estrategia habitual en DuckDB. |
| `merge` | `MERGE` (upsert) por `unique_key` | La más limpia; disponible en Snowflake, BigQuery, Databricks, DuckDB… |
| `microbatch` | Procesa por lotes de tiempo (event_time) | Introducida en dbt 1.9 para series temporales grandes. |

Se configura así:

```sql
{{ config(materialized='incremental', incremental_strategy='delete+insert', unique_key='order_id') }}
```

## 6. Buenas prácticas

- Usa incremental **solo cuando lo necesites** (tablas grandes). Para tablas pequeñas, `table` es más simple y siempre está correcto.
- Elige un buen filtro incremental: normalmente una columna de fecha/`event_time` indexable.
- Ten en cuenta los datos que llegan tarde (*late-arriving data*): un filtro `order_date > max(order_date)` podría perder filas antiguas que llegan con retraso. Estrategias como una ventana (`>= max - 3 días`) o `microbatch` lo mitigan.
- Documenta claramente la lógica incremental: es donde más errores sutiles aparecen.

---

## Referencias

- Modelos incrementales: <https://docs.getdbt.com/docs/build/incremental-models>
- Estrategias incrementales: <https://docs.getdbt.com/docs/build/incremental-strategy>
- Microbatch (dbt 1.9): <https://docs.getdbt.com/docs/build/incremental-microbatch>
- `is_incremental()`: <https://docs.getdbt.com/reference/dbt-jinja-functions/this>

## Siguiente paso

➡️ [Fase 11 – Unit tests](11-unit-tests.md)
