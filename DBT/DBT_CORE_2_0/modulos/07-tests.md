#DBT_CORE 
# Módulo 07 · dbt Tests

Los tests son aserciones sobre tus datos. Un test **pasa** si su query asociada devuelve **cero filas**, y **falla** si devuelve una o más (esas filas son precisamente las que incumplen la regla).

> **⚠️ Diferencia v1 vs v2:** desde dbt 1.8 el bloque en el `.yml` se llama `data_tests:` (antes `tests:`, que queda como alias en desuso). Usamos `data_tests:` en todo el curso porque es la forma soportada de cara al futuro en ambos motores.

## 1. Tests genéricos (los 4 "de fábrica")

dbt trae 4 tests genéricos incorporados, que se declaran en YAML sobre una columna:

| Test | Qué comprueba |
|---|---|
| `not_null` | La columna nunca es `NULL`. |
| `unique` | No hay valores repetidos en la columna. |
| `accepted_values` | El valor está dentro de una lista cerrada. |
| `relationships` | Cada valor existe como clave en otra tabla (integridad referencial). |

Ejemplo real de `models/staging/_staging__models.yml`:

```yaml
models:
  - name: stg_orders
    columns:
      - name: order_id
        data_tests:
          - unique
          - not_null
      - name: customer_id
        data_tests:
          - not_null
          - relationships:
              to: ref('stg_customers')
              field: customer_id
      - name: status
        data_tests:
          - accepted_values:
              values: ['completed', 'shipped', 'returned', 'cancelled']
```

Ejecuta:

```bash
dbt test --select staging
```

Salida esperada (resumida, todo en verde):

```
PASS unique_stg_orders_order_id ................................ [PASS in 0.02s]
PASS not_null_stg_orders_order_id .............................. [PASS in 0.02s]
PASS relationships_stg_orders_customer_id__customer_id__ref_stg_customers_
                                                                    [PASS in 0.02s]
PASS accepted_values_stg_orders_status__completed__shipped__returned__cancelled
                                                                    [PASS in 0.02s]
```

### Provocar un fallo a propósito (ejercicio)

Edita `seeds/raw_orders.csv`, cambia el `status` de un pedido a `"pendiente"` (valor no aceptado), y relanza:

```bash
dbt seed --select raw_orders
dbt test --select stg_orders
```

Verás el test `accepted_values_...` en `FAIL`, con el número exacto de filas que incumplen la regla. Deshaz el cambio antes de continuar.

## 2. Tests singulares

Un test singular es, simplemente, **un fichero `.sql` en `tests/`** con una query que debe devolver 0 filas. Perfecto para reglas de negocio específicas que no encajan en los 4 tests genéricos.

`tests/assert_order_total_matches_items.sql`:

```sql
select
    order_id,
    total_items,
    order_total_eur
from {{ ref('fct_orders') }}
where total_items > 0
  and order_total_eur <= 0
```

Regla: *si un pedido tiene artículos, su importe debe ser mayor que cero*. Ejecuta:

```bash
dbt test --select assert_order_total_matches_items
```

## 3. Tests genéricos personalizados

Se puede crear un test genérico propio con un macro `{% test %}`. 
`macros/test_is_positive.sql`:

```sql
{% test is_positive(model, column_name) %}

select *
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
```

Una vez creado, se usa exactamente igual que `not_null` o `unique` en cualquier `.yml`:

```yaml
- name: order_total_eur
  data_tests:
    - is_positive
```

(Este patrón, `nombre_columna < 0`, es intencionalmente simple para practicar la sintaxis; para reglas de rango completas se usa `dbt_utils.accepted_range`, ver punto 5).

## 4. Ejecutar todos los tests del proyecto

```bash
dbt test
```

O, dentro del flujo completo (recomendado para el día a día):

```bash
dbt build
```

`dbt build` construye cada modelo **y** ejecuta sus tests antes de pasar al siguiente nodo del DAG que dependa de él. Si un test de `stg_orders` falla, dbt no construirá `fct_orders` encima de datos que ya sabe que están mal — así se evita propagar errores capa arriba.

## 5. Tests de paquetes externos: `dbt_utils`

En `models/marts/core/_marts__models.yml` verás:

```yaml
- name: order_total_eur
  data_tests:
    - not_null
    - dbt_utils.accepted_range:
        min_value: 0
        inclusive: true
```

`dbt_utils.accepted_range` no viene de fábrica: la trae el paquete `dbt_utils` (`packages.yml`). Para que funcione hace falta:

```bash
dbt deps
```

Lo retomamos en detalle en el Módulo 10.

## 6. Unit tests (novedad reciente, disponible en v1.8+ y en v2)

A diferencia de los `data_tests` (que validan los datos reales de tu base de datos), los **unit tests** validan la **lógica SQL de un modelo** contra datos de entrada ficticios que tú defines — más parecido a un test unitario de software tradicional. Se declaran también en YAML, con `unit_tests:`. Ejemplo (no incluido en el proyecto de ejemplo para no sobrecargarlo, pero puedes añadirlo como ejercicio):

```yaml
unit_tests:
  - name: test_fct_orders_total_cero_sin_lineas
    model: fct_orders
    given:
      - input: ref('stg_orders')
        rows:
          - {order_id: 1, customer_id: 1, order_date: '2024-01-01', status: 'completed'}
      - input: ref('int_order_items_enriched')
        rows: []
    expect:
      rows:
        - {order_id: 1, total_items: 0, order_total_eur: 0}
```

Ventaja: se ejecutan **sin tocar la base de datos real**, muy rápidos, y son ideales para lógica compleja de negocio (cálculos, `CASE WHEN` anidados...) que quieres blindar frente a regresiones.

## 7. Buenas prácticas de testing

- Como mínimo: `unique` + `not_null` en la clave primaria de **todo**   modelo expuesto (staging y marts).
- `relationships` en cada clave foránea relevante — es la forma más barata de detectar problemas de integridad entre capas.
- Reserva los tests singulares para reglas de negocio que de verdad importan; no abuses de ellos como sustituto de los genéricos.
- Ejecuta `dbt build` (no solo `dbt run`) en cualquier flujo que vaya a alimentar un dashboard o a otra herramienta aguas abajo.
