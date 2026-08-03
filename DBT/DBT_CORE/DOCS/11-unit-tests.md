---
tags:
  - DBT_CORE
---

# Fase 11 – Unit tests

## Objetivo

Validar la **lógica de transformación** de un modelo con datos ficticios de entrada, independientemente de los datos reales. Los unit tests se introdujeron en **dbt 1.8**.

---

## 1. Data test vs unit test

Es importante no confundirlos:

| | **Data test** (Fase 06) | **Unit test** |
|--|-------------------------|---------------|
| Qué comprueba | Los **datos reales** cumplen una regla (sin nulos, sin duplicados…) | La **lógica SQL** produce la salida esperada |
| Datos que usa | Los que hay en el almacén | Datos **ficticios** que tú defines |
| Analogía | "¿Están bien los datos?" | "¿Está bien el código?" (como un test unitario de software) |
| Cuándo se ejecuta | Tras construir el modelo | Al compilar, sin depender de datos reales |

Un unit test responde a: *"si le doy estas filas de entrada, ¿el modelo calcula exactamente esta salida?"*. Es perfecto para lógica delicada: cálculos, `CASE`, agregaciones, ventanas…

## 2. Nuestro unit test

Validamos que `int_order_items_priced` calcula bien `line_amount_eur = quantity * price_eur`. Está en [`models/intermediate/_unit_tests.yml`](../proyecto/jaffle_shop/models/intermediate/_unit_tests.yml):

```yaml
version: 2
unit_tests:
  - name: test_calculo_importe_linea
    description: "El importe de línea debe ser precio * cantidad."
    model: int_order_items_priced
    given:
      - input: ref('stg_order_items')
        rows:
          - {order_item_id: 1, order_id: 100, product_id: 1, quantity: 2}
          - {order_item_id: 2, order_id: 100, product_id: 2, quantity: 3}
      - input: ref('stg_products')
        rows:
          - {product_id: 1, product_name: 'Jaffle', category: 'comida', price_cents: 550, price_eur: 5.50}
          - {product_id: 2, product_name: 'Cafe',   category: 'bebida', price_cents: 200, price_eur: 2.00}
    expect:
      rows:
        - {order_item_id: 1, line_amount_eur: 11.00}   # 2 * 5.50
        - {order_item_id: 2, line_amount_eur: 6.00}    # 3 * 2.00
```

Anatomía:

- **`model`**: el modelo bajo prueba.
- **`given`**: qué le "servimos" en lugar de sus dependencias reales. Aquí sustituimos `stg_order_items` y `stg_products` por filas inventadas y controladas.
- **`expect`**: el resultado exacto que esperamos. dbt **solo compara las columnas que menciones** en `expect`, así que no hace falta listar todas.

## 3. Ejecutarlo

Los unit tests se ejecutan con el mismo comando que los data tests:

```bash
cd proyecto/jaffle_shop
dbt test --profiles-dir . -s int_order_items_priced
```

```
int_order_items_priced::test_calculo_importe_linea ... [PASS]
```

Si alguien rompiera la fórmula (por ejemplo, cambiara `quantity * price_eur` por `quantity + price_eur`), este test fallaría **inmediatamente** y te mostraría la diferencia entre lo esperado y lo obtenido, sin necesidad de mirar los datos de producción.

## 4. Formatos de entrada

Además de `rows` en línea (dict), `given` admite otros formatos, muy cómodos para datos grandes:

```yaml
    given:
      - input: ref('stg_products')
        format: csv
        rows: |
          product_id,product_name,price_eur
          1,Jaffle,5.50
      # o cargar desde un fichero fixture reutilizable:
      - input: ref('stg_order_items')
        format: csv
        fixture: order_items_ejemplo    # busca tests/fixtures/order_items_ejemplo.csv
```

## 5. Cuándo merece la pena

- Lógica de negocio no trivial: cálculos financieros, categorización con `CASE`, deduplicaciones, funciones de ventana.
- Casos límite difíciles de reproducir con datos reales: nulos, valores en cero, fechas frontera.
- Modelos críticos donde un error de cálculo sería caro.

No hace falta unit-testear cada modelo: concéntralos donde la lógica es compleja o el impacto de un fallo es alto.

---

## Referencias

- Unit tests (oficial): <https://docs.getdbt.com/docs/build/unit-tests>
- Sintaxis de `unit_tests`: <https://docs.getdbt.com/reference/resource-properties/unit-tests>
- Anuncio y motivación (dbt 1.8): <https://docs.getdbt.com/blog/unit-testing-dbt>

## Siguiente paso

➡️ [Fase 12 – Comandos, entornos y buenas prácticas](12-despliegue-y-buenas-practicas.md)
