# Fase 02 – Tu primer proyecto

## Objetivo

Conocer la anatomía de un proyecto dbt, entender los dos ficheros de configuración clave (`dbt_project.yml` y `profiles.yml`) y hacer que dbt se conecte correctamente a DuckDB con `dbt debug`.

---

## 1. Crear un proyecto desde cero: `dbt init`

Para crear un proyecto nuevo se usa:

```bash
dbt init mi_proyecto
```

El asistente te pregunta el adaptador (elegirías `duckdb`) y genera la estructura de carpetas. **En este curso no necesitas ejecutarlo**: ya tienes el proyecto montado en [`proyecto/jaffle_shop/`](../proyecto/jaffle_shop/). Aun así conviene saber que existe.

## 2. Anatomía de un proyecto dbt

```
jaffle_shop/
├── dbt_project.yml        # Configuración del proyecto (obligatorio)
├── profiles.yml           # Conexión al almacén (aquí, local al proyecto)
├── packages.yml.example   # Dependencias de paquetes (Fase 07)
├── models/                # Tus modelos SQL, organizados por capas
│   ├── staging/
│   ├── intermediate/
│   └── marts/
├── seeds/                 # CSV que se cargan como tablas (Fase 03)
├── snapshots/             # Snapshots SCD2 (Fase 09)
├── macros/                # Macros Jinja reutilizables (Fase 07)
├── tests/                 # Tests singulares y genéricos propios (Fase 06)
└── analyses/              # Consultas ad-hoc que se compilan pero no se ejecutan
```

## 3. `dbt_project.yml`: el corazón del proyecto

Es el único fichero **obligatorio**. Define el nombre del proyecto, qué *profile* usar y la configuración por defecto de cada recurso. Estos son los fragmentos más importantes del nuestro:

```yaml
name: 'jaffle_shop'
profile: 'jaffle_shop'          # ← enlaza con el bloque de profiles.yml

model-paths: ["models"]         # dónde busca dbt cada tipo de recurso
seed-paths: ["seeds"]
# ...

vars:
  fecha_corte_incremental: '2024-01-01'   # variables del proyecto (Fase 10)

models:
  jaffle_shop:
    staging:
      +materialized: view       # los modelos de staging serán VISTAS
      +schema: staging
    marts:
      +materialized: table      # los de marts serán TABLAS
      +schema: marts
```

La sección `models:` aplica configuración **en cascada por carpeta**. Aquí decimos: "todo lo que esté en `models/staging/` se materializa como vista y va al esquema `staging`". Cada modelo puede sobreescribir esto con un bloque `{{ config(...) }}`.

Referencia completa: <https://docs.getdbt.com/reference/dbt_project.yml>

## 4. `profiles.yml`: la conexión al almacén

Mientras `dbt_project.yml` describe *el proyecto*, `profiles.yml` describe *cómo conectarse al almacén*. Se mantienen separados a propósito: el proyecto se comparte en Git; las credenciales (que van en el profile) **no**.

Nuestro `profiles.yml` para DuckDB:

```yaml
jaffle_shop:                    # ← debe coincidir con "profile:" del dbt_project.yml
  target: dev                   # entorno por defecto
  outputs:
    dev:
      type: duckdb
      path: 'jaffle_shop.duckdb' # el fichero de base de datos DuckDB
      threads: 4
    prod:
      type: duckdb
      path: 'jaffle_shop_prod.duckdb'
      threads: 4
```

Puntos clave:

- **`target`**: el entorno activo por defecto (`dev`). Puedes tener varios (`dev`, `prod`, `ci`…) y elegir con `dbt run --target prod`. Lo veremos en la [Fase 12](12-despliegue-y-buenas-practicas.md).
- **`type: duckdb`**: el adaptador. Si usaras Postgres o Snowflake aquí irían `host`, `user`, `password`, etc.
- **`path`**: para DuckDB, el fichero donde vive la base de datos. Se crea solo la primera vez.
- **`threads`**: cuántos modelos ejecuta dbt en paralelo cuando el DAG lo permite.

### ¿Dónde debe estar `profiles.yml`?

Por defecto dbt lo busca en `~/.dbt/profiles.yml` (tu carpeta de usuario). Para que este curso sea **autocontenido**, lo hemos puesto **dentro del proyecto** y lo indicamos con la opción `--profiles-dir .`:

```bash
dbt debug --profiles-dir .
```

Para no repetir la opción en cada comando, exporta la variable de entorno una sola vez por sesión de terminal:

```bash
export DBT_PROFILES_DIR=.        # Windows PowerShell: $env:DBT_PROFILES_DIR="."
```

> **Buena práctica en proyectos reales**: deja `profiles.yml` en `~/.dbt/` (fuera del repositorio) y usa variables de entorno para las credenciales con `{{ env_var('DBT_PASSWORD') }}`.

## 5. Comprobar la conexión: `dbt debug`

Desde dentro de `proyecto/jaffle_shop/`:

```bash
cd proyecto/jaffle_shop
dbt debug --profiles-dir .
```

Salida esperada al final:

```
Registered adapter: duckdb=1.9.6
Connection test: [OK connection ok]
All checks passed!
```

`dbt debug` valida que el `dbt_project.yml` es correcto, que encuentra el profile y que puede conectarse al almacén. Es siempre lo primero que debes ejecutar ante cualquier problema.

## 6. El comando más útil para inspeccionar: `dbt --help`

```bash
dbt --help              # lista todos los comandos
dbt run --help          # opciones de un comando concreto
```

Los comandos que iremos usando: `seed`, `run`, `test`, `snapshot`, `build`, `docs`, `compile`, `source freshness`, `deps`, `clean`, `ls`.

---

## Referencias

- `dbt_project.yml`: <https://docs.getdbt.com/reference/dbt_project.yml>
- Conexión a DuckDB (`profiles.yml`): <https://docs.getdbt.com/docs/core/connect-data-platform/duckdb-setup>
- `dbt debug`: <https://docs.getdbt.com/reference/commands/debug>
- Estructura de proyecto recomendada: <https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview>

## Siguiente paso

➡️ [Fase 03 – Seeds: datos iniciales](03-seeds.md)
