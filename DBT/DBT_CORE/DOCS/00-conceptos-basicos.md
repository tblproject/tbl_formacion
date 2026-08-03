---
tags:
  - DBT_CORE
---

# Fase 00 – Conceptos básicos

## Objetivo

Entender **qué es dbt**, qué problema resuelve y el vocabulario mínimo antes de instalar nada. Esta fase es teórica; a partir de la Fase 01 empezamos a ejecutar.

---

## 1. ¿Qué es dbt?

**dbt** (*data build tool*) es una herramienta open source que se encarga de la **"T" (Transform)** de un proceso de datos. Su idea central es sencilla y potente: **transformar datos escribiendo únicamente sentencias `SELECT`**.

Tú escribes un `SELECT` que describe *cómo* debe verse una tabla o vista; dbt se encarga del `CREATE TABLE`/`CREATE VIEW`, del orden de ejecución, de las dependencias entre modelos, de los tests y de la documentación. En otras palabras, dbt aplica al análisis de datos las buenas prácticas de la ingeniería de software: control de versiones, modularidad, pruebas automáticas, documentación y entornos (desarrollo/producción).

A dbt no le importa *de dónde* vienen los datos ni *cómo* llegaron a la base de datos: parte de que los datos crudos **ya están** en tu almacén (*data warehouse*) y su trabajo es convertirlos en tablas limpias, fiables y listas para el análisis.

## 2. ETL vs ELT: por qué dbt existe

Históricamente los datos se procesaban con **ETL** (*Extract – Transform – Load*): se extraían del origen, se transformaban en un servidor intermedio y **después** se cargaban ya transformados en el almacén.

Con la llegada de los almacenes en la nube (BigQuery, Snowflake, Redshift…) y de motores rápidos como DuckDB, el patrón cambió a **ELT** (*Extract – Load – Transform*): primero se **cargan** los datos crudos tal cual en el almacén, y la **transformación** se hace *dentro* del propio almacén con SQL. dbt es la herramienta de referencia para esa "T" final del ELT.

```
ETL:  Origen ─▶ [Transformar fuera] ─▶ Cargar en almacén
ELT:  Origen ─▶ Cargar crudo en almacén ─▶ [Transformar dentro con dbt]
```

Ventajas del ELT con dbt: aprovechas la potencia del almacén, mantienes los datos crudos disponibles para reprocesar, y las transformaciones quedan versionadas y testeadas como código.

## 3. Los conceptos clave de dbt

- **Model (modelo)**: un fichero `.sql` que contiene un único `SELECT`. dbt lo materializa en el almacén como una vista o tabla. Es la unidad de trabajo fundamental.
- **Source (origen)**: una declaración de las tablas crudas ya existentes en el almacén. Permite referenciarlas de forma limpia y controlar su "frescura".
- **Seed (semilla)**: un fichero CSV pequeño que dbt carga como tabla. Ideal para datos estáticos de referencia (o, en este curso, para simular los datos crudos sin instalar otra base de datos).
- **Ref y source**: las funciones `{{ ref('otro_modelo') }}` y `{{ source('origen','tabla') }}` sustituyen los nombres de tabla "a pelo". Gracias a ellas dbt **descubre automáticamente las dependencias** entre modelos.
- **DAG (grafo dirigido acíclico)**: el mapa de dependencias que dbt construye a partir de los `ref()`. Determina el **orden de ejecución** y el **linaje** (de qué depende cada tabla).
- **Materialización**: cómo persiste dbt un modelo en el almacén: `view`, `table`, `ephemeral` o `incremental`.
- **Test**: una comprobación de calidad de datos (p. ej. "esta columna no tiene nulos"). Ver [Fase 06](DBT/DBT_CORE/DOCS/06-dbt-tests.md).
- **Macro**: función reutilizable escrita en Jinja + SQL. Ver [Fase 07](07-jinja-macros-packages.md).

### El DAG en una imagen

```
                   ┌─ stg_customers ─┐
raw_customers ─────┤                 ├─▶ dim_customers ─┐
raw_orders ────────┼─ stg_orders ────┤                  ├─▶ fct_orders ─▶ dashboard
raw_order_items ───┼─ stg_order_items┼─▶ int_orders ────┘
raw_products ──────┼─ stg_products ──┘
raw_payments ──────┴─ stg_payments
```

dbt calcula este grafo solo a partir de tus `ref()`. Nunca tienes que indicar manualmente el orden de ejecución.

## 4. dbt Core vs dbt Cloud

- **dbt Core**: la herramienta open source de línea de comandos (CLI). Gratuita, se ejecuta donde tú quieras. **Es la que usamos en todo este curso.**
- **dbt Cloud**: producto SaaS comercial de dbt Labs que añade IDE web, planificador (scheduler) integrado, CI/CD gestionado, catálogo, control de accesos, etc., por encima de dbt Core.

En este curso trabajamos **solo con dbt Core y sin orquestador**: ejecutaremos los comandos manualmente. En la [Fase 12](12-despliegue-y-buenas-practicas.md) veremos cómo programarlos con `cron` y qué orquestadores existen para dar el salto a producción.

## 5. Analytics Engineering

dbt popularizó el rol de **Analytics Engineer**: un perfil a medio camino entre el analista de datos (que conoce el negocio y el SQL) y el ingeniero de datos (que conoce el software y la infraestructura). El *analytics engineer* construye los modelos limpios y documentados que después consumen los analistas de negocio. dbt es su herramienta principal.

## 6. Alternativas a dbt

Para tener una visión completa, estas son las principales alternativas y en qué se diferencian:

- **SQLMesh** (open source): muy similar a dbt, pero con manejo nativo de *columnas/planes* y detección de cambios que evita reconstruir todo el DAG; permite Python y SQL. Buena opción si te preocupa el coste de recomputación. <https://sqlmesh.com>
- **Google Dataform** (gratuito dentro de GCP): equivalente a dbt pero integrado en BigQuery/Google Cloud. Útil si vives 100% en GCP. <https://cloud.google.com/dataform>
- **SDF** (Rust, open source): motor de transformación con análisis estático del SQL y comprobación de tipos en tiempo de compilación. <https://www.sdf.com>
- **Coalesce** (comercial): plataforma visual (low-code) de transformación sobre Snowflake, orientada a equipos que prefieren interfaz gráfica en lugar de escribir SQL a mano.
- **Apache Airflow / Dagster / Prefect**: **no** son alternativas a dbt sino **orquestadores**. Resuelven *cuándo* y *en qué orden* se lanzan tareas (incluida la ejecución de dbt), no *cómo* transformar SQL. Complementan a dbt, no lo sustituyen.

dbt sigue siendo el estándar de facto por su enorme comunidad, su ecosistema de paquetes ([dbt Hub](https://hub.getdbt.com)) y su integración con casi cualquier almacén.

## 7. ¿Por qué DuckDB en este curso?

Para practicar dbt necesitas *algún* almacén de datos. En lugar de instalar y administrar PostgreSQL, Snowflake o BigQuery, usamos **DuckDB**: una base de datos analítica **embebida** (como SQLite pero orientada a analítica) que vive en un único fichero y no necesita servidor. Instalar el adaptador `dbt-duckdb` es todo lo que hace falta. Es rapidísima y perfecta para aprender. En la [Fase 01](01-instalacion-y-entorno.md) verás cómo cambiar de adaptador si mañana quieres apuntar a un almacén real.

---

## Referencias

- ¿Qué es dbt? (docs oficiales): <https://docs.getdbt.com/docs/introduction>
- Analytics Engineering (guía de dbt Labs): <https://www.getdbt.com/what-is-analytics-engineering>
- Libro recomendado: *Analytics Engineering with SQL and dbt* (O'Reilly, 2024).
- Libro recomendado: *Fundamentals of Data Engineering* (Reis & Housley, O'Reilly, 2022) — capítulos sobre ELT.

## Siguiente paso

➡️ [Fase 01 – Instalación y entorno](01-instalacion-y-entorno.md)
