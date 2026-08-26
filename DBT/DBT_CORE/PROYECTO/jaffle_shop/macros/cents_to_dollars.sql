{#
  Convierte una columna de centimos (entero) a euros con 2 decimales.
  Uso:  {{ cents_to_dollars('amount_cents') }}
  Ejemplo de macro reutilizable para no repetir la misma logica en cada modelo.
#}
{% macro cents_to_dollars(column_name, decimals=2) -%}
    round( ({{ column_name }} / 100.0)::numeric, {{ decimals }} )
{%- endmacro %}
