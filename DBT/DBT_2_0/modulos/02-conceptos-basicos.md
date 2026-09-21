# Módulo 02 · Conceptos básicos

## 1. ¿Qué es dbt?

**dbt (data build tool)** es una herramienta de **transformación** de
datos. No extrae datos de sistemas origen ni los carga en el warehouse
(eso lo hacen herramientas de EL/ELT como Fivetran, Airbyte o scripts a
medida). dbt entra en juego **después**: coge datos que ya están en tu
base de datos analítica y los transforma en tablas y vistas limpias,
testadas y documentadas, usando únicamente **SELECT** en SQL.

Filosofía central: **cada modelo dbt es un `SELECT`** guardado en un
fichero `.sql`. dbt se encarga de:

1. Envolver ese `SELECT` en un `CREATE TABLE AS` / `CREATE VIEW AS` (u
   otras estrategias, ver Módulo 06).
2. Resolver las dependencias entre modelos (`ref()`), en el orden
   correcto.
3. Ejecutarlo contra la base de datos.
4. Testarlo, documentarlo y versionarlo como si fuera código de
   aplicación (porque lo es).

## 2. ELT, no ETL

| | ETL clásico | ELT (enfoque de dbt) |
|---|---|---|
| Orden | Extraer → **Transformar** → Cargar | Extraer → Cargar → **Transformar** |
| Dónde se transforma | En un servidor intermedio | Dentro del propio warehouse, con SQL |
| Quién transforma | Herramienta ETL dedicada | dbt (compila y ejecuta SQL) |

dbt asume que los datos crudos **ya están cargados** en el warehouse (o,
en nuestro caso, en el fichero DuckDB) antes de que dbt entre en juego.

## 3. Las capas típicas de un proyecto dbt

Convención muy extendida en la comunidad (no es obligatoria, pero se usa
en este curso y en el proyecto de ejemplo):

```
raw (fuera de dbt)
   │
   ▼
staging (stg_*)        → 1 modelo por tabla origen. Renombra columnas,
                          castea tipos, limpieza mínima. materialized: view
   │
   ▼
intermediate (int_*)   → combina/enriquece staging. Suele ser "ephemeral"
                          o "view". No se expone a negocio directamente.
   │
   ▼
marts (dim_*, fct_*)    → modelos finales, listos para BI/analítica.
                          materialized: table (o incremental si crecen mucho)
```

En el proyecto de ejemplo (`proyecto-ejemplo/`) verás exactamente esta
estructura: `models/staging`, `models/intermediate`, `models/marts/core`.

## 4. Glosario mínimo

| Término | Significado |
|---|---|
| **Modelo** | Fichero `.sql` con un `SELECT`; se compila y materializa como tabla/vista. |
| **`ref()`** | Función Jinja para referenciar otro modelo dbt. dbt resuelve el DAG a partir de estas llamadas. |
| **`source()`** | Función Jinja para referenciar una tabla "cruda" (no generada por dbt), declarada en un `.yml`. |
| **Materialización** | Estrategia física de persistencia de un modelo: `view`, `table`, `incremental`, `ephemeral`. |
| **DAG** | Grafo de dependencias entre modelos, sources, seeds, snapshots, etc., que dbt construye automáticamente. |
| **Seed** | Fichero CSV versionado en el proyecto que dbt carga como tabla (`dbt seed`). Pensado para datos de referencia pequeños y estables. |
| **Snapshot** | Mecanismo de dbt para capturar el histórico de cambios de una tabla mutable (SCD tipo 2). |
| **Test** | Aserción SQL sobre los datos; falla si la query devuelve filas (o, en `unit tests`, si la salida no coincide con la esperada). |
| **Macro** | Función reutilizable escrita en Jinja + SQL. |
| **Manifest** | Artefacto (`manifest.json` en v1, JSON/Parquet en v2) que representa el estado completo compilado del proyecto. |
| **Selector** | Sintaxis (`--select`, `--exclude`) para elegir qué subconjunto del DAG ejecutar. |

## 5. El ciclo de vida de un modelo dbt

```
escribir SELECT en .sql
        │
        ▼
   dbt run / dbt build   (compila Jinja→SQL, ejecuta contra la BD)
        │
        ▼
   dbt test               (verifica calidad de los datos resultantes)
        │
        ▼
   dbt docs generate       (genera documentación + linaje navegable)
```

A partir del Módulo 04 ejecutaremos este ciclo de verdad, sobre datos
reales, sin ningún orquestador de por medio: todo desde la terminal.
