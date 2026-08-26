# Proyecto de ejemplo: jaffle_shop (dbt Core + DuckDB)

Proyecto dbt completo y ejecutable que acompaña a la [formación](../../README.md). Modela un e-commerce ("Jaffle Shop") partiendo de CSV crudos hasta un modelo en estrella.

## Puesta en marcha

```bash
# desde esta carpeta
pip install dbt-core dbt-duckdb          # si aún no lo tienes
export DBT_PROFILES_DIR=.                # usa el profiles.yml de este proyecto

dbt debug            # verificar conexión a DuckDB
dbt seed             # 1ª vez: cargar datos crudos (crea el esquema raw)
dbt build            # construir modelos + tests + snapshot
dbt docs generate && dbt docs serve      # documentación y linaje
```

> La primera vez es necesario `dbt seed` antes de `dbt build` (los sources apuntan a las tablas que crean los seeds). Ver Fase 04 de la formación.

Resultado esperado: `dbt build` → `PASS=55 WARN=0 ERROR=0` (11 modelos, 6 seeds, 36 data tests, 1 unit test, 1 snapshot).

## Estructura

```
seeds/         Datos crudos (raw_*.csv) + seed de referencia (seed_status_map.csv)
models/
  staging/     Limpieza 1:1 con el origen (stg_*) + sources + tests
  intermediate/ Lógica de negocio (int_*) + unit test
  marts/       Modelo en estrella: dim_customers, dim_products, fct_orders + exposure
snapshots/     orders_snapshot (SCD2 del estado del pedido)
macros/        cents_to_dollars, generate_schema_name
tests/         Test singular + test genérico propio (generic/non_negative.sql)
analyses/      Consulta ad-hoc (no se materializa)
profiles.yml   Conexión DuckDB (incluida para que el ejemplo sea autocontenido)
```

## Nota

Las carpetas/ficheros `raw_data/`, `seeds/_probe.txt`, `target/`, `logs/` y `*.duckdb`
no forman parte del proyecto (son artefactos del entorno o se regeneran). Puedes borrarlos.
