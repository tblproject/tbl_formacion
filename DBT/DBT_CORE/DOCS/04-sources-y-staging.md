# Fase 04 – Sources y capa staging

## Objetivo

Declarar los datos crudos como **sources**, crear la primera capa de modelos (**staging**) que los limpia y estandariza, y entender `ref()`, `source()` y las materializaciones.

---

## 1. Sources: declarar los datos crudos

Un **source** es una declaración en YAML de las tablas crudas que ya existen en el almacén (las que cargamos en la Fase 03). Declararlas aporta tres ventajas:

1. Puedes referenciarlas con `{{ source('nombre','tabla') }}` en lugar de escribir el nombre de tabla a mano.
2. dbt las incluye en el **linaje** (verás de dónde vienen tus datos).
3. Puedes controlar la **frescura** (`freshness`): ¿hace cuánto que no se actualizan?

Nuestro fichero [`models/staging/_sources.yml`](../proyecto/jaffle_shop/models/staging/_sources.yml):

```yaml
version: 2
sources:
  - name: jaffle_raw
    description: "Datos crudos del negocio Jaffle Shop."
    schema: raw                     # dónde están las tablas (esquema raw)
    tables:
      - name: raw_customers
      - name: raw_orders
      - name: raw_payments
        loaded_at_field: "created_at::timestamp"
        freshness:
          warn_after: {count: 3650, period: day}
```

> Convención habitual: los ficheros de propiedades (YAML) empiezan por `_` y describen la carpeta donde viven (`_sources.yml`, `_staging.yml`…). Es solo una convención de la comunidad, no una obligación.

> **⚠️ Lección importante (bootstrap)**: en este curso las tablas del source se crean con `dbt seed` (Fase 03). Un `source` **no** genera una dependencia en el DAG hacia el seed: dbt no sabe que la tabla del source la produce un seed. Por eso, en una base de datos **vacía**, debes ejecutar `dbt seed` **antes** del primer `dbt run`/`dbt build`; si no, los modelos de staging fallarán con "Table raw_customers does not exist". A partir de la primera carga, las tablas ya existen y `dbt build` funciona por sí solo. En un proyecto real este problema no aparece porque los sources apuntan a tablas que ya existen (las deja una herramienta de ingesta), no a seeds.

### Comprobar la frescura de los datos

```bash
dbt source freshness --profiles-dir .
```

dbt mira el valor máximo de `loaded_at_field` y lo compara con la hora actual. Si supera `warn_after` avisa; con `error_after` fallaría. Útil para detectar que una carga se ha quedado parada.

## 2. La capa de staging

La **capa de staging** es la primera transformación. Su misión es **limpiar y estandarizar** cada tabla cruda, con una regla de oro: **un modelo de staging por cada tabla de origen**, y sin `JOIN` ni agregaciones (eso viene después). Aquí se hace:

- Renombrar columnas a nombres consistentes (`id` → `customer_id`).
- Convertir tipos (`created_at` → `date`).
- Cálculos simples de fila (concatenar nombre y apellido, pasar céntimos a euros…).

Ejemplo, [`stg_customers.sql`](../proyecto/jaffle_shop/models/staging/stg_customers.sql):

```sql
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
```

Fíjate en `{{ source('jaffle_raw', 'raw_customers') }}`: al compilar, dbt lo sustituye por el nombre real de la tabla (`raw.raw_customers`). Nunca escribas el nombre de la tabla a mano.

Tenemos cinco modelos de staging (`stg_customers`, `stg_products`, `stg_orders`, `stg_order_items`, `stg_payments`), uno por cada seed.

## 3. `ref()` y `source()`: las dos funciones que lo cambian todo

- **`{{ source('origen', 'tabla') }}`**: referencia a una tabla cruda declarada como source.
- **`{{ ref('modelo') }}`**: referencia a **otro modelo dbt**. Es la función más importante de dbt.

Gracias a estas funciones, dbt:

1. Construye el **DAG** automáticamente (sabe que `stg_customers` depende de `raw_customers`).
2. Decide el **orden de ejecución** (primero los orígenes, luego los modelos que dependen de ellos).
3. Ajusta los nombres según el `target` (en `dev` apunta a un esquema, en `prod` a otro) sin que cambies el código.

## 4. Materializaciones

La **materialización** decide *cómo* persiste dbt un modelo en el almacén. Se configura con `+materialized`:

| Materialización | Qué crea | Cuándo usarla |
|-----------------|----------|---------------|
| `view` | Una **vista** (consulta guardada, no ocupa espacio, siempre fresca) | Transformaciones ligeras. **Por defecto** y elección típica para staging. |
| `table` | Una **tabla** física (se reconstruye entera en cada `run`) | Modelos consultados a menudo o pesados de calcular. Típico en marts. |
| `ephemeral` | **Nada** en el almacén: se inyecta como CTE en los modelos que lo referencian | Lógica intermedia que no necesitas consultar directamente. |
| `incremental` | Una tabla que solo procesa filas nuevas | Tablas grandes de hechos. Ver [Fase 10](10-incrementales.md). |

En nuestro proyecto lo definimos por capa en `dbt_project.yml`:

```yaml
models:
  jaffle_shop:
    staging:      { +materialized: view }
    intermediate: { +materialized: view }
    marts:        { +materialized: table }
```

## 5. Ejecutar los modelos: `dbt run`

```bash
dbt run --profiles-dir .
```

Construye todos los modelos en orden. Para ejecutar solo algunos, usa **selección de nodos** (lo ampliamos en la Fase 05):

```bash
dbt run --profiles-dir . -s staging            # solo la carpeta staging
dbt run --profiles-dir . -s stg_customers      # solo un modelo
dbt run --profiles-dir . -s stg_orders+        # stg_orders y todo lo que depende de él
```

---

## Referencias

- Sources: <https://docs.getdbt.com/docs/build/sources>
- Source freshness: <https://docs.getdbt.com/docs/build/sources#snapshotting-source-data-freshness>
- Modelos SQL: <https://docs.getdbt.com/docs/build/sql-models>
- Materializaciones: <https://docs.getdbt.com/docs/build/materializations>
- Cómo estructurar staging: <https://docs.getdbt.com/best-practices/how-we-structure/2-staging>

## Siguiente paso

➡️ [Fase 05 – Modelos: intermediate y marts](05-modelos-y-marts.md)
