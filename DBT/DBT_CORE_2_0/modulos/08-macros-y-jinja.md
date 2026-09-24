# Módulo 08 · Macros y Jinja

dbt compila cada `.sql` con el motor de plantillas **Jinja** antes de
mandarlo a la base de datos. Eso es lo que permite usar `{{ ref(...) }}`,
`{% if %}`, bucles, variables, etc. dentro de SQL "normal".

## 1. Sintaxis Jinja básica

| Sintaxis | Uso |
|---|---|
| `{{ ... }}` | Expresión: su resultado se inserta en el SQL compilado. |
| `{% ... %}` | Sentencia de control (`if`, `for`, `set`, `macro`...): no imprime nada por sí misma. |
| `{# ... #}` | Comentario Jinja (no aparece ni en el SQL compilado). |

## 2. Ver el SQL compilado

Es el mejor hábito para aprender Jinja: compila y mira el resultado.

```bash
dbt compile --select stg_products
cat target/compiled/tienda_online/models/staging/stg_products.sql
```

## 3. Macro propia: `cents_to_euros`

`macros/cents_to_euros.sql`:

```sql
{% macro cents_to_euros(column_name) %}
    round( ({{ column_name }})::decimal / 100, 2)
{% endmacro %}
```

Uso en `models/staging/stg_products.sql`:

```sql
select
    product_id,
    product_name,
    category,
    {{ cents_to_euros('unit_price_cents') }} as unit_price_eur,
    is_active
from source
```

Compílalo y comprueba que Jinja ha sustituido la llamada por SQL real:

```bash
dbt compile --select stg_products
```

Deberías ver algo como:

```sql
select
    product_id,
    product_name,
    category,
    round( (unit_price_cents)::decimal / 100, 2) as unit_price_eur,
    is_active
from source
```

## 4. Macros que dbt invoca automáticamente: `generate_schema_name`

Algunos macros no se llaman explícitamente desde un modelo, sino que
**dbt los invoca por convención** en cada ejecución. `generate_schema_name`
es el más habitual de sobrescribir: controla en qué esquema cae cada
modelo cuando se usa `+schema:` en la configuración.

`macros/generate_schema_name.sql`:

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}

        {{ default_schema }}

    {%- else -%}

        {{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
```

Por defecto, dbt concatena `<schema_del_target>_<custom_schema>` (p. ej.
`main_marts`). Aquí lo sobrescribimos para que, en local, el esquema
declarado (`staging`, `marts`...) se use **tal cual**, sin prefijo — más
cómodo para inspeccionar con el CLI de DuckDB. Es el motivo por el que,
tras `dbt run`, ves esquemas llamados `staging` y `marts` en vez de
`main_staging` y `main_marts`.

## 5. Variables de proyecto (`vars`)

En `dbt_project.yml`:

```yaml
vars:
  primer_dia_fiscal: '2024-01-01'
```

Se leen desde cualquier modelo o macro con `{{ var('primer_dia_fiscal') }}`,
y se pueden sobrescribir en tiempo de ejecución sin tocar el YAML:

```bash
dbt run --select fct_orders --vars '{primer_dia_fiscal: 2024-06-01}'
```

Útil para parametrizar backfills o ejecuciones puntuales.

## 6. Control de flujo: `{% if %}` y `{% for %}`

Patrón muy común — generar una columna por cada valor de una lista, sin
repetir SQL a mano:

```sql
{% set categorias = ['electronica', 'papeleria', 'accesorios'] %}

select
    order_id,
    {% for categoria in categorias %}
    sum(case when category = '{{ categoria }}' then line_amount_eur else 0 end)
        as total_{{ categoria }}{{ "," if not loop.last }}
    {% endfor %}
from {{ ref('int_order_items_enriched') }}
group by 1
```

Como ejercicio, prueba a pegar esto en un modelo nuevo
(`models/marts/core/rpt_ventas_por_categoria.sql`) y compílalo con `dbt
compile` para ver el SQL expandido antes de ejecutarlo con `dbt run`.

## 7. `is_incremental()`: adelanto del Módulo 09

Una función Jinja especial de dbt, disponible solo dentro de modelos con
`materialized='incremental'`, que devuelve `true` únicamente cuando la
tabla destino ya existe (es decir, en todas las ejecuciones excepto la
primera o un `--full-refresh`). La vemos con detalle en el próximo
módulo, donde es la pieza central.

## 8. Resumen: ¿macro o modelo?

- Si la lógica es **una transformación de datos completa** → modelo
  (`.sql` en `models/`).
- Si la lógica es **una pieza de SQL reutilizable en varios modelos**
  (una fórmula, una condición, un fragmento de `CASE WHEN`) → macro.
- Si la lógica es **una regla de validación reutilizable** → macro de
  tipo `{% test %}` (Módulo 07).
