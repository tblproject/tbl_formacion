#DBT_CORE 
# Formación: dbt Core v2 desde cero (con DuckDB)

Formación práctica y progresiva de **dbt Core**, centrada en trabajar directamente con la herramienta **sin ningún orquestador** (ni Airflow, ni Dagster, ni scheduler alguno). Todos los comandos se ejecutan a mano desde la terminal para entender exactamente qué hace dbt en cada paso, antes de delegar esa ejecución a un orquestador en una fase posterior (fuera del
alcance de esta formación).

Motor de base de datos: **DuckDB**, embebido en un fichero local. No hace falta levantar Postgres, Snowflake ni ningún servicio adicional: con Python (o el binario de dbt) y un fichero `.duckdb` es suficiente.

## Caso de uso guía

A lo largo de todos los módulos se construye el mismo proyecto: analítica de una **tienda online** con clientes, productos, pedidos y líneas de pedido. Cada módulo añade una capacidad nueva de dbt sobre el mismo proyecto, de modo que al terminar la formación tienes un mini-DWH
funcional de extremo a extremo.

Todos los ficheros del proyecto de ejemplo están en `../proyecto-ejemplo`, listos para ejecutarse — no hace falta escribirlos desde cero, aunque se recomienda teclearlos a mano la primera vez para interiorizar la sintaxis.

## Índice de módulos

| # | Módulo | Qué se aprende |
|---|--------|-----------------|
| 01 | [Comparativa dbt Core v1 vs dbt Core v2 (Fusion)](01-comparativa-dbt-core-v1-vs-v2-fusion.md) | Qué cambia, por qué existe Fusion, qué versión usar |
| 02 | [Conceptos básicos](02-conceptos-basicos.md) | Qué es dbt, ELT, capas del proyecto, glosario |
| 03 | [Instalación](03-instalacion.md) | Instalar dbt Core v2 / Fusion + adaptador DuckDB |
| 04 | [Primer proyecto y ejecución](04-primer-proyecto-y-ejecucion.md) | `dbt init`, `profiles.yml`, `dbt debug/run/build`, selectors |
| 05 | [Seeds, sources y staging](05-seeds-sources-staging.md) | Cargar datos, declarar fuentes, primera capa de modelos |
| 06 | [Materializaciones y marts](06-materializaciones-y-marts.md) | view / table / ephemeral, capas intermedia y de negocio |
| 07 | [dbt Tests](07-tests.md) | Tests genéricos, singulares, personalizados y unit tests |
| 08 | [Macros y Jinja](08-macros-y-jinja.md) | Jinja, macros propias, `generate_schema_name` |
| 09 | [Incremental y snapshots](09-incremental-y-snapshots.md) | Modelos incrementales, SCD tipo 2 |
| 10 | [Documentación, paquetes y cierre](10-documentacion-paquetes-y-cierre.md) | `dbt docs`, `dbt deps`, dbt_utils, próximos pasos |

## Requisitos previos

- Nociones de SQL (SELECT, JOIN, GROUP BY).
- Terminal / línea de comandos básica (`cd`, `ls`).
- Python 3.9+ instalado (solo si se opta por la instalación vía `pip`; ver
  Módulo 03 para la alternativa sin Python).
- Un editor de código (se recomienda VS Code + extensión oficial de dbt).

## Fuera de alcance (deliberadamente)

- Orquestación (Airflow, Dagster, dbt Cloud Jobs, cron...).
- Motores de producción (Snowflake, BigQuery, Databricks...): se mencionan solo como contexto, pero el curso es 100% reproducible en  local con DuckDB.
- dbt Semantic Layer / MetricFlow.
