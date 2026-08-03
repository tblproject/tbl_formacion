---
tags:
  - DBT_CORE
---

# Fase 01 – Instalación y entorno

## Objetivo

Dejar tu máquina lista para ejecutar dbt Core con DuckDB. Al terminar tendrás `dbt --version` funcionando.

---

## 1. Requisitos previos

- **Python 3.9 – 3.12** instalado. Compruébalo con:

  ```bash
  python --version
  ```

  Si no lo tienes: <https://www.python.org/downloads/>.
- **pip** (viene con Python).
- Un terminal (Bash, Zsh, PowerShell o CMD).

dbt Core se distribuye como un paquete de Python, por eso necesitamos Python. No hace falta nada más: **DuckDB se instala como parte del adaptador**, sin servidores ni contenedores.

## 2. Crear un entorno virtual (recomendado)

Un entorno virtual aísla las dependencias de dbt del resto de tu Python. Muy recomendable para no mezclar versiones entre proyectos.

```bash
# Colócate en la carpeta de la formación
python -m venv .venv

# Activarlo
source .venv/bin/activate        # macOS / Linux
.venv\Scripts\activate           # Windows (PowerShell/CMD)
```

Cuando el entorno está activo, verás `(.venv)` al principio del prompt. Para salir: `deactivate`.

> **Alternativas al venv**: [`uv`](https://docs.astral.sh/uv/) (gestor moderno y muy rápido, `uv venv` + `uv pip install`), `pipx` (instala dbt como app aislada), `conda`, o directamente Docker con la imagen oficial `ghcr.io/dbt-labs/dbt-duckdb`. El `venv` estándar es suficiente para este curso.

## 3. Instalar dbt Core y el adaptador DuckDB

dbt se instala en **dos piezas**: el núcleo (`dbt-core`) y un **adaptador** por cada tipo de almacén. Instalar el adaptador arrastra automáticamente `dbt-core` y `duckdb`.

```bash
pip install dbt-core dbt-duckdb
```

> **Importante**: instala siempre el adaptador de tu almacén. dbt Core por sí solo no sabe hablar con ninguna base de datos.

### Otros adaptadores (si mañana usas un almacén real)

El código de este curso funciona casi idéntico en otros almacenes; solo cambiarías el adaptador y el `profiles.yml`:

| Almacén | Paquete a instalar |
|---------|--------------------|
| DuckDB (este curso) | `dbt-duckdb` |
| PostgreSQL | `dbt-postgres` |
| Snowflake | `dbt-snowflake` |
| BigQuery | `dbt-bigquery` |
| Databricks | `dbt-databricks` |
| Redshift | `dbt-redshift` |

Lista completa de adaptadores: <https://docs.getdbt.com/docs/supported-data-platforms>

## 4. Verificar la instalación

```bash
dbt --version
```

Salida esperada (las versiones pueden variar):

```
Core:
  - installed: 1.9.10
Plugins:
  - duckdb: 1.9.6
```

Si ves esto, ¡ya tienes dbt Core funcionando! Si el comando `dbt` no se encuentra, asegúrate de tener el entorno virtual activado o de que la carpeta de scripts de pip esté en tu `PATH`.

## 5. ¿Por qué DuckDB y qué hace el adaptador?

`dbt-duckdb` permite a dbt ejecutar tus modelos contra **DuckDB**, un motor analítico OLAP embebido:

- **Sin servidor**: la base de datos es un único fichero (`.duckdb`) en tu disco. No hay procesos que arrancar ni puertos que abrir.
- **Rápida para analítica**: está optimizada para consultas de agregación sobre columnas, justo lo que hace dbt.
- **Compatible con SQL estándar** y capaz de leer CSV/Parquet/JSON directamente.

Esto la hace ideal para aprender: cero fricción de instalación, tal y como pedía el enunciado del curso.

Documentación del adaptador: <https://github.com/duckdb/dbt-duckdb>
Documentación de DuckDB: <https://duckdb.org/docs/>

---

## Referencias

- Instalación de dbt (oficial): <https://docs.getdbt.com/docs/core/installation-overview>
- Instalar con pip: <https://docs.getdbt.com/docs/core/pip-install>
- Adaptadores soportados: <https://docs.getdbt.com/docs/supported-data-platforms>

## Siguiente paso

➡️ [Fase 02 – Tu primer proyecto](02-primer-proyecto.md)
