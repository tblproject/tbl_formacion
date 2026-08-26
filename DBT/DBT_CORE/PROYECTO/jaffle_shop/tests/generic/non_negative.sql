{#
  Test generico propio: comprueba que una columna no tenga valores negativos.
  Un test generico se define como macro {% test ... %} y se usa por nombre en
  el bloque data_tests de un .yml, igual que unique o not_null.
  Uso:
    data_tests:
      - non_negative
#}
{% test non_negative(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
