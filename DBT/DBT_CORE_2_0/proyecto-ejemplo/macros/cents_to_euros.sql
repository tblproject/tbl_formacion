{% macro cents_to_euros(column_name) %}
    round( ({{ column_name }})::decimal / 100, 2)
{% endmacro %}
