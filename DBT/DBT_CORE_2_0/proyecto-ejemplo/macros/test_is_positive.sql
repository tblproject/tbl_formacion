{% test is_positive(model, column_name) %}

-- Un test genérico personalizado (Módulo 07) devuelve las filas que
-- INCUMPLEN la condición: si la query no devuelve filas, el test pasa.

select *
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
