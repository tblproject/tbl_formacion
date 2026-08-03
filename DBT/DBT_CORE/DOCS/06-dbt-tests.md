---
tags:
  - DBT_CORE
---

# Fase 06 – dbt Tests (calidad de datos)

## Objetivo

Dominar el sistema de pruebas de dbt: tests **genéricos**, **singulares** y **personalizados**, cómo ejecutarlos, cómo controlar su severidad y cómo depurarlos. Los tests son una de las razones principales por las que se adopta dbt: convierten la calidad de datos en algo automático y versionado.

---

## 1. ¿Qué es un test en dbt?

Un test es una **afirmación sobre tus datos**. Bajo el capó, cada test es simplemente una consulta SQL que dbt ejecuta con esta lógica:

> El test **pasa** si la consulta devuelve **0 filas**. Si devuelve una o más filas, esas filas son las que **incumplen** la afirmación y el test **falla**.

Ejemplo: el test `not_null` de una columna compila, en esencia, a `select * from modelo where columna is null`. Si no hay nulos, no hay filas, y el test pasa.

Hay dos tipos: **data tests** (comprueban los datos reales) y **unit tests** (comprueban la lógica de transformación con datos ficticios; ver [Fase 11](11-unit-tests.md)). Los data tests, a su vez, son **genéricos** o **singulares**.

## 2. Tests genéricos integrados

dbt trae cuatro tests genéricos de fábrica. Se declaran en un fichero de propiedades YAML, bajo cada columna, en el bloque `data_tests`:

- **`unique`**: la columna no tiene valores repetidos.
- **`not_null`**: la columna no tiene nulos.
- **`accepted_values`**: la columna solo contiene valores de una lista.
- **`relationships`**: cada valor existe en otra tabla (integridad referencial, tipo *foreign key*).

Extracto real de [`models/staging/_staging.yml`](../proyecto/jaffle_shop/models/staging/_staging.yml):

```yaml
version: 2
models:
  - name: stg_orders
    description: "Pedidos normalizados."
    columns:
      - name: order_id
        data_tests: [unique, not_null]
      - name: customer_id
        description: "FK al cliente."
        data_tests:
          - not_null
          - relationships:
              to: ref('stg_customers')     # customer_id debe existir en stg_customers
              field: customer_id
      - name: order_status
        data_tests:
          - accepted_values:
              values: ['placed', 'shipped', 'completed', 'returned']
```

> **Nota de versión**: en dbt ≥ 1.8 la palabra clave es `data_tests`. En proyectos antiguos verás `tests:` (aún funciona pero está en desuso).

## 3. Tests singulares (singular tests)

Cuando una comprobación es específica y no encaja en un test genérico, escribes un **test singular**: un fichero `.sql` en la carpeta `tests/` con una consulta que **selecciona las filas problemáticas**.

[`tests/assert_pagado_no_supera_pedido.sql`](../proyecto/jaffle_shop/tests/assert_pagado_no_supera_pedido.sql):

```sql
-- Si devuelve filas, FALLA: ningún pedido debería tener pagado más que su importe.
select
    order_id,
    order_amount_eur,
    amount_paid_eur
from {{ ref('fct_orders') }}
where amount_paid_eur > order_amount_eur + 0.01
```

Regla mental: *"escribe el SQL que encuentra lo que NO debería pasar"*. Si encuentra algo, el test falla y te muestra exactamente qué filas.

## 4. Tests genéricos personalizados

Si repites la misma comprobación en varias columnas, conviértela en un **test genérico propio**: una macro `{% test %}` que recibe `model` y `column_name`. Es exactamente lo que hicimos para no depender de paquetes externos.

[`tests/generic/non_negative.sql`](../proyecto/jaffle_shop/tests/generic/non_negative.sql):

```sql
{% test non_negative(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
```

Y se usa por su nombre, igual que `unique`:

```yaml
# models/marts/_marts.yml
      - name: order_amount_eur
        data_tests:
          - non_negative
```

También hay tests genéricos muy útiles en el paquete **dbt_utils** (`accepted_range`, `expression_is_true`, `unique_combination_of_columns`…). Lo vemos en la [Fase 07](07-jinja-macros-packages.md).

## 5. Ejecutar los tests: `dbt test`

```bash
cd proyecto/jaffle_shop
dbt test --profiles-dir .
```

Salida (nuestro proyecto tiene 36 data tests + 1 unit test):

```
36 of 37 PASS unique_stg_products_product_id ...................... [PASS]
37 of 37 PASS int_order_items_priced::test_calculo_importe_linea ... [PASS]
Completed successfully
Done. PASS=37 WARN=0 ERROR=0 SKIP=0 TOTAL=37
```

Selección de nodos (igual que en `run`):

```bash
dbt test --profiles-dir . -s stg_orders          # solo los tests de stg_orders
dbt test --profiles-dir . -s +fct_orders          # tests de fct_orders y sus dependencias
```

## 6. Severidad: `error` vs `warn`

Por defecto un test que falla es un **error** (corta la ejecución). A veces prefieres un **aviso** que no bloquee. Se controla con `config`:

```yaml
      - name: email
        data_tests:
          - not_null:
              config:
                severity: warn            # avisa pero no falla
      - name: order_id
        data_tests:
          - unique:
              config:
                severity: error           # falla (comportamiento por defecto)
                error_if: ">10"           # fallar solo si hay más de 10 filas malas
                warn_if: ">0"             # avisar a partir de 1
```

`error_if` / `warn_if` permiten umbrales: útil cuando toleras un pequeño número de anomalías.

## 7. Depurar un test que falla: `store_failures`

Cuando un test falla, quieres ver *qué* filas lo provocaron. Con `--store-failures` dbt guarda esas filas en una tabla del esquema, para que las consultes:

```bash
dbt test --profiles-dir . --store-failures
```

También puedes fijarlo por test con `config: {store_failures: true}`. dbt siempre te da el SQL compilado del test en `target/compiled/...`, que puedes copiar y ejecutar a mano para investigar.

## 8. Dónde declarar los tests

- Tests genéricos → en ficheros `.yml` de propiedades, junto a los modelos (`_staging.yml`, `_marts.yml`…).
- Tests singulares → ficheros `.sql` en `tests/`.
- Tests genéricos propios → macros `{% test %}` en `tests/generic/` o en `macros/`.

## 9. `dbt build`: run + test en un solo comando

En la práctica se usa `dbt build`, que ejecuta **en orden por el DAG**: seeds → modelos → tests → snapshots. Así, si un modelo falla un test, dbt **no** construye lo que depende de él. Lo veremos a fondo en la [Fase 12](12-despliegue-y-buenas-practicas.md).

```bash
dbt build --profiles-dir .
```

---

## Referencias

- Tests de datos: <https://docs.getdbt.com/docs/build/data-tests>
- Tests genéricos y personalizados: <https://docs.getdbt.com/best-practices/writing-custom-generic-tests>
- Configuración de tests (severidad, umbrales): <https://docs.getdbt.com/reference/resource-configs/severity>
- `store_failures`: <https://docs.getdbt.com/reference/resource-configs/store_failures>
- Paquete de aserciones avanzadas: dbt_expectations (<https://github.com/calogica/dbt-expectations>).

## Siguiente paso

➡️ [Fase 07 – Jinja, macros y packages](07-jinja-macros-packages.md)
