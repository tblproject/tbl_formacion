# Módulo 05 · Seeds, sources y staging

## 1. Seeds: ¿cuándo usarlos?

Un **seed** es un CSV versionado en el propio proyecto que dbt carga
como tabla con `dbt seed`. Pensado para:

- Datos de referencia pequeños y estables (códigos de país, mapeos
  moneda→símbolo, listas de exclusión...).
- **No** para sustituir a un proceso de ingesta de datos operacionales.

> **Nota pedagógica:** en este curso usamos seeds también para los datos
> "operacionales" (`raw_orders`, `raw_customers`...) porque no tenemos
> herramienta de orquestación ni de ingesta. Es una simplificación
> deliberada para poder practicar sin infraestructura adicional — en un
> proyecto real, esas tablas las cargaría un proceso de EL (Fivetran,
> Airbyte, un script propio) y dbt las consumiría vía `source()`, nunca
> vía `dbt seed`.

Revisa `proyecto-ejemplo/seeds/`:

```
raw_customers.csv      15 clientes
raw_products.csv       15 productos
raw_orders.csv          25 pedidos (abril-mayo 2024)
raw_order_items.csv     32 líneas de pedido
raw_orders_batch2.csv    5 pedidos adicionales (para el Módulo 09, incremental)
```

Carga (si no lo has hecho ya en el Módulo 04):

```bash
dbt seed
```

`dbt_project.yml` fuerza el tipo de columna de las fechas para que
DuckDB no las infiera como texto:

```yaml
seeds:
  tienda_online:
    raw_customers:
      +column_types:
        signup_date: date
```

## 2. Sources: declarar los datos "crudos"

Un `source` es la forma en que dbt referencia una tabla que **no** ha
creado él mismo. Se declara en YAML, nunca en SQL directamente, para
poder:

- Documentarla y testarla igual que a un modelo.
- Trackear su **freshness** (antigüedad de los datos) — no lo cubrimos en
  detalle aquí, pero se menciona en el Módulo 10.
- Que el DAG de dbt sepa que ese nodo es el punto de partida.

Abre `proyecto-ejemplo/models/staging/_staging__sources.yml`:

```yaml
version: 2

sources:
  - name: tienda_online_raw
    schema: seeds
    tables:
      - name: raw_customers
        columns:
          - name: customer_id
            data_tests:
              - unique
              - not_null
      - name: raw_orders
      - name: raw_products
      - name: raw_order_items
```

Desde cualquier modelo, se referencia así:

```sql
select * from {{ source('tienda_online_raw', 'raw_customers') }}
```

dbt compila esto a la tabla física real (`seeds.raw_customers` en
nuestro caso) y, de paso, registra la dependencia en el DAG.

## 3. La capa staging: un modelo por fuente

Regla de oro de staging: **1:1 con la tabla origen**, sin joins. Solo:

- Renombrar columnas a un estándar consistente.
- Castear tipos.
- Limpieza mínima (trim, lower, etc.).

Mira `models/staging/stg_customers.sql`:

```sql
with source as (

    select * from {{ source('tienda_online_raw', 'raw_customers') }}

),

renamed as (

    select
        customer_id,
        first_name,
        last_name,
        trim(lower(email))              as email,
        country,
        signup_date,
        first_name || ' ' || last_name  as full_name

    from source

)

select * from renamed
```

Patrón `with source as (...) , renamed as (...) select * from renamed`:
es una convención (no una obligación) muy extendida en dbt para que
cualquier modelo staging se lea igual, facilitando el mantenimiento.

Hay un modelo equivalente para `stg_orders`, `stg_products` (que además
usa una macro propia, lo veremos en el Módulo 08) y `stg_order_items`.

## 4. Ejecutar la capa staging

```bash
dbt run --select staging
```

Salida esperada:

```
1 of 4 OK created sql view model staging.stg_customers ......... [OK in 0.04s]
2 of 4 OK created sql view model staging.stg_products ........... [OK in 0.03s]
3 of 4 OK created sql view model staging.stg_orders .............. [OK in 0.03s]
4 of 4 OK created sql view model staging.stg_order_items ......... [OK in 0.03s]
```

Fíjate en `created sql VIEW model`: es la materialización por defecto
que fijamos para toda la carpeta `staging` en `dbt_project.yml`
(`+materialized: view`). Las vistas no duplican datos y siempre reflejan
el estado actual del seed — perfectas para una capa que solo renombra
columnas. El Módulo 06 explica las demás materializaciones.

## 5. Comprobación visual del DAG

```bash
dbt list --select staging+
```

Lista, en orden topológico, el nodo `staging` y todo lo que depende de
él (de momento nada más, porque aún no hemos creado la capa
intermedia/marts — llega en el Módulo 06).
