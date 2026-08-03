---
tags:
  - DBT_CORE
---

# Fase 07 – Jinja, macros y packages

## Objetivo

Entender que los modelos dbt son en realidad **plantillas Jinja + SQL**, escribir tus propias **macros** reutilizables y aprovechar **paquetes** de la comunidad como `dbt_utils`.

---

## 1. Jinja: el motor de plantillas

Todo lo que has escrito entre `{{ }}` y `{% %}` es **Jinja**, un lenguaje de plantillas de Python. dbt **compila** tus ficheros `.sql` (sustituyendo el Jinja) y **luego** ejecuta el SQL resultante contra el almacén.

- `{{ ... }}` → **expresión**: se sustituye por un valor (p. ej. `{{ ref('stg_orders') }}` → `"jaffle_shop"."staging"."stg_orders"`).
- `{% ... %}` → **sentencia**: lógica de control (`if`, `for`, `set`, definición de macros). No produce salida por sí misma.
- `{# ... #}` → **comentario** que desaparece al compilar.

Puedes ver el SQL final compilado en `target/compiled/...` o con:

```bash
dbt compile --profiles-dir . -s fct_orders
```

### Funciones y variables que ya conoces

- `{{ ref('modelo') }}` y `{{ source('origen','tabla') }}` — dependencias.
- `{{ config(materialized='table') }}` — configuración inline.
- `{{ var('nombre') }}` — lee una variable de `dbt_project.yml` (`vars:`) o de la línea de comandos (`--vars '{clave: valor}'`).
- `{{ env_var('MI_VAR') }}` — lee una variable de entorno (ideal para credenciales).
- `{{ this }}` — la relación (tabla) del modelo actual; muy usada en incrementales.

Ejemplo de nuestro modelo incremental, que combina `var`, `is_incremental()` y `this`:

```sql
where order_date >= '{{ var("fecha_corte_incremental") }}'
{% if is_incremental() %}
  and order_date > (select max(order_date) from {{ this }})
{% endif %}
```

## 2. Macros: funciones reutilizables

Una **macro** es una función escrita en Jinja + SQL que puedes invocar desde cualquier modelo. Sirven para no repetir lógica (principio DRY). Van en la carpeta `macros/`.

Nuestra macro [`macros/cents_to_dollars.sql`](../proyecto/jaffle_shop/macros/cents_to_dollars.sql):

```sql
{% macro cents_to_dollars(column_name, decimals=2) -%}
    round( ({{ column_name }} / 100.0)::numeric, {{ decimals }} )
{%- endmacro %}
```

Se usa dentro de un `select`:

```sql
{{ cents_to_dollars('price_cents') }} as price_eur
```

Al compilar, esa línea se convierte en `round((price_cents / 100.0)::numeric, 2) as price_eur`. Si mañana cambia la lógica de conversión, la tocas en **un solo sitio**.

### Macro que altera el comportamiento de dbt

Algunas macros tienen nombres "especiales" que dbt invoca automáticamente. Nosotros sobreescribimos [`generate_schema_name`](../proyecto/jaffle_shop/macros/generate_schema_name.sql) para que los esquemas se llamen `raw`, `staging`, `marts`… en lugar del prefijo por defecto `main_raw`, `main_staging`:

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

> **Cuidado en producción**: esta versión simplificada haría que `dev` y `prod` escriban en los mismos esquemas. En un entorno real conviene prefijar por entorno/usuario. Es un ejemplo didáctico de lo potente (y delicado) que es poder redefinir el comportamiento de dbt.

## 3. Ejecutar una macro suelta: `dbt run-operation`

Puedes invocar macros que hagan tareas de mantenimiento (por ejemplo, conceder permisos o vaciar tablas) sin construir modelos:

```bash
dbt run-operation nombre_de_macro --args '{clave: valor}' --profiles-dir .
```

## 4. Hooks: SQL antes/después de ejecutar

Los **hooks** ejecutan SQL en momentos concretos del ciclo de vida:

- `pre-hook` / `post-hook`: antes/después de construir un modelo.
- `on-run-start` / `on-run-end`: al principio/final de todo el `run`.

Ejemplo típico (en `dbt_project.yml` o en `config`): conceder permisos tras crear una tabla.

```yaml
models:
  jaffle_shop:
    marts:
      +post-hook: "grant select on {{ this }} to role analista"
```

## 5. Packages: reutilizar código de la comunidad

Los **packages** son proyectos dbt que instalas como dependencia para reutilizar sus macros y tests. El más popular es **`dbt_utils`** (de dbt Labs).

Declaras las dependencias en `packages.yml` (te dejamos uno listo en [`packages.yml.example`](../proyecto/jaffle_shop/packages.yml.example)):

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.1.0", "<2.0.0"]
```

Y las instalas con:

```bash
cp packages.yml.example packages.yml
dbt deps --profiles-dir .
```

> Dejamos el fichero como `.example` a propósito para que el proyecto base se pueda ejecutar **sin conexión a internet**. `dbt deps` sí necesita internet (descarga los paquetes en `dbt_packages/`). Una vez instalado, podrías cambiar el test `non_negative` por el más completo de dbt_utils:
>
> ```yaml
>       - name: order_amount_eur
>         data_tests:
>           - dbt_utils.accepted_range:
>               min_value: 0
>               inclusive: true
> ```

### Paquetes útiles

- **dbt_utils**: macros y tests de propósito general. <https://hub.getdbt.com/dbt-labs/dbt_utils/latest/>
- **dbt_expectations**: aserciones de calidad al estilo Great Expectations. <https://github.com/calogica/dbt-expectations>
- **codegen**: genera automáticamente YAML de sources y modelos base. <https://github.com/dbt-labs/dbt-codegen>
- **dbt_date**: utilidades de fechas y dimensiones de calendario.
- Catálogo completo: **dbt Hub** <https://hub.getdbt.com>

---

## Referencias

- Jinja y macros: <https://docs.getdbt.com/docs/build/jinja-macros>
- Contexto de Jinja (funciones disponibles): <https://docs.getdbt.com/reference/dbt-jinja-functions>
- Packages: <https://docs.getdbt.com/docs/build/packages>
- Hooks: <https://docs.getdbt.com/docs/build/hooks-operations>

## Siguiente paso

➡️ [Fase 08 – Documentación y linaje](08-documentacion.md)
