{#
  Por defecto dbt concatena target_schema + '_' + custom_schema
  (p. ej. "main_staging"). Para este curso preferimos que, en local,
  el esquema definido en +schema (staging, marts...) se use tal cual,
  sin prefijo, para que sea más fácil de inspeccionar con el CLI de DuckDB.
  Ver Módulo 06.
#}

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}

        {{ default_schema }}

    {%- else -%}

        {{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
