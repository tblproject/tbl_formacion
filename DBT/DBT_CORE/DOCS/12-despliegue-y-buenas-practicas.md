# Fase 12 – Comandos, entornos y buenas prácticas

## Objetivo

Cerrar el curso con la visión de conjunto: el comando `dbt build`, cómo separar `dev` y `prod`, cómo **programar** ejecuciones sin orquestador, la guía de estilo y los siguientes pasos.

---

## 1. `dbt build`: el comando que lo une todo

Hasta ahora hemos ejecutado `seed`, `run`, `test` y `snapshot` por separado. En la práctica se usa **`dbt build`**, que los ejecuta **respetando el DAG**: por cada nodo, primero lo construye y luego pasa sus tests, en orden de dependencias.

```bash
cd proyecto/jaffle_shop
dbt seed --profiles-dir .     # solo la primera vez sobre una BD vacía (ver Fase 04)
dbt build --profiles-dir .
```

```
Found 11 models, 1 snapshot, 1 analysis, 36 data tests, 6 seeds, 5 sources, 1 exposure, 1 unit test
...
Done. PASS=55 WARN=0 ERROR=0 SKIP=0 TOTAL=55
```

La gran ventaja frente a `run` + `test` por separado: si un modelo **falla un test**, dbt **no construye** los modelos que dependen de él (los marca `SKIP`). Así los datos malos no se propagan aguas abajo.

### Resumen de comandos del curso

| Comando | Para qué |
|---------|----------|
| `dbt debug` | Comprobar configuración y conexión |
| `dbt deps` | Instalar paquetes de `packages.yml` |
| `dbt seed` | Cargar los CSV como tablas |
| `dbt run` | Construir los modelos |
| `dbt test` | Ejecutar data tests y unit tests |
| `dbt snapshot` | Actualizar los snapshots |
| `dbt build` | seed + run + test + snapshot, en orden de DAG |
| `dbt source freshness` | Comprobar la frescura de los sources |
| `dbt docs generate` / `serve` | Generar y servir la documentación |
| `dbt compile` | Compilar el SQL sin ejecutarlo |
| `dbt ls` | Listar qué nodos seleccionaría un selector |
| `dbt clean` | Borrar `target/` y `dbt_packages/` |

## 2. Entornos: `dev` vs `prod` con targets

En `profiles.yml` definimos dos `outputs`: `dev` (por defecto) y `prod`. Se cambia con `--target`:

```bash
dbt build --profiles-dir . --target dev     # escribe en jaffle_shop.duckdb
dbt build --profiles-dir . --target prod    # escribe en jaffle_shop_prod.duckdb
```

En un almacén real, `dev` y `prod` apuntarían a esquemas o bases de datos distintas, con credenciales distintas (leídas con `{{ env_var('DBT_PASSWORD') }}`). El **mismo código** produce resultados en el entorno que elijas: esa es la potencia de separar proyecto y profile.

## 3. Programar dbt sin orquestador (con cron)

El enunciado del curso pide trabajar **sin orquestador**. La forma más sencilla de automatizar dbt en un servidor es un **cron** (Linux/macOS) o el **Programador de tareas** (Windows). Ejemplo de script:

```bash
#!/usr/bin/env bash
# run_dbt.sh — construir el proyecto cada noche
set -euo pipefail
cd /ruta/al/proyecto/jaffle_shop
source /ruta/al/.venv/bin/activate
export DBT_PROFILES_DIR=.

dbt source freshness || true      # avisa si los datos están viejos, pero no aborta
dbt build --target prod           # construir + testear todo
dbt snapshot --target prod        # capturar histórico
```

Entrada de crontab para ejecutarlo cada día a las 6:00:

```cron
0 6 * * *  /ruta/run_dbt.sh >> /var/log/dbt/run.log 2>&1
```

Con esto tienes un pipeline funcional sin instalar nada más. **Cuándo dar el salto a un orquestador**: cuando necesites dependencias entre trabajos (primero la ingesta, luego dbt), reintentos inteligentes, alertas, backfills o un panel de ejecuciones.

## 4. Integración continua (CI) básica

Antes de fusionar cambios, conviene ejecutar dbt automáticamente. La idea clave es construir **solo lo que cambió** con selección por estado:

```bash
dbt build --select state:modified+ --defer --state ./prod-manifest
```

`state:modified+` selecciona los modelos modificados y sus descendientes; `--defer` reutiliza las tablas de producción para lo que no cambió. Esto acelera muchísimo la CI en proyectos grandes. Se integra con GitHub Actions, GitLab CI, etc.

## 5. Guía de estilo y buenas prácticas

- **Nomenclatura por capas**: `stg_` (staging), `int_` (intermediate), `dim_`/`fct_` (marts). Consistencia ante todo.
- **Un modelo de staging por fuente**, sin joins. Los joins empiezan en intermediate.
- **Usa siempre `ref()` y `source()`**; nunca escribas nombres de tabla a mano.
- **CTEs con nombres claros** al principio del modelo; un `select` final legible.
- **Documenta y testea** al menos las claves (unique + not_null) de cada modelo.
- **No repitas lógica**: si aparece dos veces, hazla macro.
- **`profiles.yml` fuera de Git** con credenciales por variables de entorno.
- Considera un *linter* como **sqlfluff** (<https://sqlfluff.com>) para formato consistente.

Guía oficial de estilo: <https://docs.getdbt.com/best-practices/how-we-style/0-how-we-style-our-dbt-projects>

## 6. Siguientes pasos

Ya dominas dbt Core en local. Cuando quieras llevarlo más lejos:

- **Almacén real**: cambia el adaptador y el `profiles.yml` (Postgres, Snowflake, BigQuery…). El código de modelos apenas cambia.
- **Orquestación**: **Dagster** (integración nativa con dbt, muy recomendada), **Apache Airflow** (con el paquete `astronomer-cosmos`), **Prefect**, o el scheduler de **dbt Cloud**.
- **dbt Mesh / proyectos múltiples**: para organizaciones grandes que dividen dbt en varios proyectos con contratos entre ellos.
- **Semantic Layer**: definir métricas de negocio una sola vez y consumirlas desde varias herramientas de BI.
- **Observabilidad de datos**: paquetes como `elementary` (<https://www.elementary-data.com>) para monitorizar tests y anomalías.

## 7. Recorrido completo del proyecto (todo de una vez)

```bash
python -m venv .venv && source .venv/bin/activate
pip install dbt-core dbt-duckdb
cd proyecto/jaffle_shop
export DBT_PROFILES_DIR=.

dbt debug              # 1. verificar conexión
dbt seed               # 2. bootstrap: cargar datos crudos (solo la 1ª vez)
dbt build              # 3. modelos + tests + snapshot (todo)
dbt source freshness   # 4. frescura de los orígenes
dbt docs generate      # 5. documentación
dbt docs serve         # 6. abrir el linaje en el navegador
```

---

## Referencias

- `dbt build`: <https://docs.getdbt.com/reference/commands/build>
- Ejecutar dbt en producción: <https://docs.getdbt.com/docs/deploy/deployments>
- CI con dbt: <https://docs.getdbt.com/docs/deploy/continuous-integration>
- Dagster + dbt: <https://docs.dagster.io/integrations/dbt>
- Airflow + dbt (Cosmos): <https://www.astronomer.io/cosmos/>

## Fin de la formación

¡Enhorabuena! Has recorrido dbt Core de principio a fin: conceptos, instalación, proyecto, seeds, sources, modelos por capas, tests de datos, Jinja/macros, documentación, snapshots, incrementales, unit tests y despliegue. Todo sobre un ejemplo real y ejecutable con DuckDB. Vuelve al [índice](../README.md) cuando quieras repasar cualquier fase.
