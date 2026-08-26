{#
  Sobreescribe el comportamiento por defecto de dbt para nombrar esquemas.
  Por defecto dbt genera "<esquema_target>_<esquema_custom>" (p.ej. main_staging).
  Aqui usamos el nombre custom tal cual (raw, staging, intermediate, marts),
  lo que hace mas legible la exploracion del fichero DuckDB.
  En produccion multi-entorno conviene revisar esta logica (ver Fase 07).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
