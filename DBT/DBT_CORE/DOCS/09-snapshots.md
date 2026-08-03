---
tags:
  - DBT_CORE
---

# Fase 09 – Snapshots (SCD tipo 2)

## Objetivo

Capturar el **histórico de cambios** de una tabla que se sobreescribe en origen, usando los snapshots de dbt (dimensiones de cambio lento, *Slowly Changing Dimensions* tipo 2).

---

## 1. El problema que resuelven

Imagina la tabla `raw_orders`: el campo `status` de un pedido cambia con el tiempo (`placed` → `shipped` → `completed`). Pero en el origen **solo se guarda el estado actual**: cada vez que cambia, se sobreescribe y pierdes la historia. Si mañana quieres responder *"¿cuántos pedidos estaban en `shipped` el 1 de marzo?"*, no puedes: esa información ya no existe.

Un **snapshot** resuelve esto. Cada vez que lo ejecutas, dbt compara el estado actual con lo que guardó la última vez y, si algo cambió, **conserva la versión antigua** y añade la nueva, con marcas de validez temporal.

## 2. Estrategias de detección de cambios

- **`timestamp`** (recomendada si existe): dbt mira una columna de fecha de actualización (`updated_at`). Si es más reciente que la guardada, hay cambio. Es la más fiable y eficiente.
- **`check`**: dbt compara el valor de una lista de columnas (`check_cols`). Si alguna cambió, registra una versión nueva. Se usa cuando **no** hay columna de fecha de actualización fiable, como en nuestro caso.

## 3. Nuestro snapshot

[`snapshots/orders_snapshot.sql`](../proyecto/jaffle_shop/snapshots/orders_snapshot.sql) — registra el histórico del estado de cada pedido:

```sql
{% snapshot orders_snapshot %}

{{
  config(
    target_schema='snapshots',
    unique_key='order_id',
    strategy='check',
    check_cols=['order_status']
  )
}}

select order_id, customer_id, order_date, order_status
from {{ ref('stg_orders') }}

{% endsnapshot %}
```

Claves de la configuración:

- **`unique_key`**: identifica cada entidad (el pedido). No confundir con clave primaria de la tabla histórica.
- **`strategy='check'`** + **`check_cols=['order_status']`**: vigila cambios en `order_status`.
- **`target_schema='snapshots'`**: dónde se guarda la tabla histórica.

## 4. Ejecutar el snapshot

```bash
cd proyecto/jaffle_shop
dbt snapshot --profiles-dir .
```

```
Done. PASS=1 WARN=0 ERROR=0 SKIP=0 TOTAL=1
```

## 5. Qué añade dbt: las columnas `dbt_*`

La tabla `snapshots.orders_snapshot` incluye columnas de auditoría que genera dbt:

| Columna | Significado |
|---------|-------------|
| `dbt_scd_id` | Identificador único de cada versión de la fila. |
| `dbt_valid_from` | Momento en que esta versión empezó a ser válida. |
| `dbt_valid_to` | Momento en que dejó de serlo. **`NULL` = versión vigente ahora.** |
| `dbt_updated_at` | Cuándo la procesó dbt por última vez. |

**Ejemplo del comportamiento**: si ejecutas el snapshot hoy (pedido 5 = `placed`) y mañana el pedido cambia a `shipped` y vuelves a ejecutarlo, tendrás **dos filas** para el pedido 5:

```
order_id | order_status | dbt_valid_from | dbt_valid_to
   5      | placed       | 2026-07-29     | 2026-07-30      <- versión cerrada
   5      | shipped      | 2026-07-30     | NULL            <- versión vigente
```

Para consultar el estado "tal como era" en una fecha concreta, filtras por el rango `dbt_valid_from`/`dbt_valid_to`.

## 6. Buenas prácticas

- Los snapshots deben leer de una fuente **lo más cruda posible** (aquí `stg_orders`, que es una vista ligera); no de modelos que reprocesan y cambian a menudo.
- Ejecútalos **con la frecuencia con la que quieras capturar cambios** (a diario, por hora…). Si no lo ejecutas, no capturas nada: solo ves el estado en los momentos en que corrió el snapshot.
- Nunca borres ni edites a mano la tabla del snapshot: es tu registro histórico.
- En dbt ≥ 1.9 los snapshots también pueden definirse en **YAML** (además de en `.sql`), lo que muchos equipos prefieren. Aquí usamos la forma `.sql` clásica por ser la más extendida y compatible.

---

## Referencias

- Snapshots (oficial): <https://docs.getdbt.com/docs/build/snapshots>
- Configuración de snapshots: <https://docs.getdbt.com/reference/snapshot-configs>
- Concepto de SCD tipo 2 (Kimball): *The Data Warehouse Toolkit*.

## Siguiente paso

➡️ [Fase 10 – Modelos incrementales](10-incrementales.md)
