# Fase 03 – Seeds: datos iniciales

## Objetivo

Cargar los datos crudos del ejemplo en DuckDB usando **seeds**, y entender cuándo conviene usarlos.

---

## 1. ¿Qué es un seed?

Un **seed** es un fichero CSV situado en la carpeta `seeds/` que dbt carga en el almacén como una tabla con el comando `dbt seed`. Es la forma de meter datos en el almacén **directamente desde dbt**, sin herramientas externas de ingesta.

**¿Para qué se usan normalmente?** Para datos pequeños, estáticos y que cambian poco: mapeos de códigos de país, categorías, tipos de cambio, listas de correos internos, etc. **No** son para cargar tablas de millones de filas (eso es trabajo de una herramienta de ingesta como Airbyte, Fivetran o un `COPY`).

> **En este curso** usamos seeds con un segundo propósito muy práctico: **simular los datos crudos** del negocio sin tener que instalar otra base de datos ni un proceso de ingesta. Así el ejemplo es 100% autocontenido, tal y como pedía el enunciado.

## 2. Los datos del ejemplo

En [`proyecto/jaffle_shop/seeds/`](../proyecto/jaffle_shop/seeds/) hay 5 ficheros CSV que representan los datos crudos ("raw") de nuestra cafetería online:

| Fichero | Filas | Descripción |
|---------|-------|-------------|
| `raw_customers.csv` | 100 | Clientes: `id, first_name, last_name, email, created_at` |
| `raw_products.csv` | 12 | Catálogo: `id, name, category, price_cents` |
| `raw_orders.csv` | 300 | Pedidos: `id, user_id, order_date, status` |
| `raw_order_items.csv` | 798 | Líneas de pedido: `id, order_id, product_id, quantity` |
| `raw_payments.csv` | 243 | Pagos: `id, order_id, payment_method, amount_cents, created_at` |

Y un sexto seed que es un **auténtico dato de referencia** (el uso "canónico" de los seeds):

| Fichero | Filas | Descripción |
|---------|-------|-------------|
| `seed_status_map.csv` | 4 | Traduce el código de estado a texto: `order_status, status_description, is_final` |

`seed_status_map` es pequeño, estático y se mantiene junto al código. Lo usaremos en la [Fase 05](05-modelos-y-marts.md) dentro de `fct_orders`, referenciándolo con `{{ ref('seed_status_map') }}` para enriquecer cada pedido con la descripción de su estado. Ese es el patrón real de un seed; usar seeds para los `raw_*` es una comodidad de este curso para no montar otra base de datos.

Los datos son ficticios y tienen **integridad referencial** (cada pedido apunta a un cliente que existe, cada línea a un producto que existe, etc.), para que los `JOIN` y los tests de la [Fase 06](06-dbt-tests.md) tengan sentido.

Ejemplo de `raw_orders.csv`:

```csv
id,user_id,order_date,status
1,70,2023-06-08,placed
2,41,2023-05-23,completed
3,75,2023-10-07,returned
```

## 3. Configurar los seeds

En el `dbt_project.yml` decimos a qué esquema van y forzamos algunos tipos de columna para que dbt no los deduzca mal:

```yaml
seeds:
  jaffle_shop:
    +schema: raw                # los seeds van al esquema "raw"
    raw_products:
      +column_types:
        id: integer
        price_cents: integer    # nos aseguramos de que sea entero, no texto
    raw_payments:
      +column_types:
        id: integer
        amount_cents: integer
```

`+column_types` es opcional pero recomendable: evita que un CSV con ceros a la izquierda o formatos raros se cargue como texto.

## 4. Ejecutar la carga

```bash
cd proyecto/jaffle_shop
dbt seed --profiles-dir .
```

Salida esperada:

```
1 of 6 OK loaded seed file raw.raw_customers ...   [INSERT 100]
2 of 6 OK loaded seed file raw.raw_order_items ...  [INSERT 798]
3 of 6 OK loaded seed file raw.raw_orders ...       [INSERT 300]
4 of 6 OK loaded seed file raw.raw_payments ...     [INSERT 243]
5 of 6 OK loaded seed file raw.raw_products ...     [INSERT 12]
6 of 6 OK loaded seed file raw.seed_status_map ...  [INSERT 4]
Completed successfully
Done. PASS=6 WARN=0 ERROR=0 SKIP=0 TOTAL=6
```

¡Ya tienes tus tablas crudas y la de referencia en el fichero `jaffle_shop.duckdb`, en el esquema `raw`!

## 5. Comprobarlo (opcional)

Si quieres mirar los datos directamente en DuckDB:

```bash
python -c "import duckdb; con=duckdb.connect('jaffle_shop.duckdb'); print(con.sql('select count(*) from raw.raw_orders').df())"
```

O instala la CLI de DuckDB (<https://duckdb.org/docs/api/cli>) y ejecuta `duckdb jaffle_shop.duckdb` para consultarlo interactivamente.

## 6. Opciones útiles

```bash
dbt seed --profiles-dir . -s raw_customers   # cargar solo un seed
dbt seed --profiles-dir . --full-refresh     # recrear las tablas desde cero
```

---

## Referencias

- Seeds (oficial): <https://docs.getdbt.com/docs/build/seeds>
- Configuración de seeds: <https://docs.getdbt.com/reference/seed-configs>
- Alternativas para ingesta de datos reales: Airbyte (<https://airbyte.com>), Fivetran, `dlt` (<https://dlthub.com>).

## Siguiente paso

➡️ [Fase 04 – Sources y capa staging](04-sources-y-staging.md)
