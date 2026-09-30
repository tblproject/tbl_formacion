#DBT_CORE 
# Módulo 04 · Primer proyecto y ejecución

## 1. Crear un proyecto desde cero (referencia)

Para *este* curso ya tienes el proyecto generado en `tienda_online/`, pero así es como se crea uno nuevo desde cero:

```bash
dbt init --project-name tienda_online
```

Esto lanza un menú iterativo para elegir si usamos un profile ya existente, creamos uno desde cero, o nos saltamos este paso:
```bash
Installing dbt project and profile setup
Info Created .vscode/extensions.json with dbt extension recommendation
Success Project created successfully!
Info Project name: tienda_online
Info Project directory: tienda_online
Which would you like to do?:
> Use an existing profile from profiles.yml
  Set up a new profile from scratch
  Skip profile setup
```

Si elegimos crearlo de cero nos preguntará qué adaptador queremos usar, pero en el momento de realizar este material, este wizard todavía no incluía DuckDB por lo que nos saltaremos este paso y crearemos el profile antes de lanzar el init.:
```bash
Which would you like to do?: Set up a new profile from scratch
Info Setting up your profile...
   Loading ~/.dbt/profiles.yml
Info Creating new profile...
Which adapter would you like to use?:
> snowflake
  databricks
  bigquery
  clickhouse
  exasol
  postgres
  redshift
  fabric
```
El **dbt init** además de crear el directorio para el proyeto junto con las carpetas estándar, también creará el esqueleto  del archivo dbt_project.ml y en caso de crear el profiles desde cero con el wizard que se indica arriba, se crearía una entrada en  **`~/.dbt/profiles.yml`**.

Para este curso crearemos un profile asociado al proyecto dentro de la ruta estándar y lo usaremos como referencia. Para ello creamos el archivo **~/.dbt/profiles.yml** con el siguiente contenido:
```yaml
tienda_online:
  outputs:
    dev:
      type: duckdb
      path: dev.duckdb
      threads: 1

    prod:
      type: duckdb
      path: prod.duckdb
      threads: 4

  target: dev
```
En donde se indica el nombre del proyecto, los outputs esperados que serán dos archivos **.duckdb** (uno por entorno) y se marca que el target por defecto sea dev.

Ahora en el momento de crear el proyecto tenemos:
```bash

--- Ejecución del init del proyecto eligiendo usar un profile existente

$ dbt init --project-name tienda_online
Installing dbt project and profile setup
Info Created .vscode/extensions.json with dbt extension recommendation
Success Project created successfully!
Info Project name: tienda_online
Info Project directory: tienda_online
Which would you like to do?:
> Use an existing profile from profiles.yml
  Set up a new profile from scratch
  Skip profile setup
  
--- Seleccionamos el profile que hemos creado antes 

Which would you like to do?: Use an existing profile from profiles.yml
Select a profile to use:
> tienda_online (duckdb)

--- Vemos que se completa correctamente la creación del proyecto

Info Using existing profile 'tienda_online'
Success Set profile 'tienda_online' in dbt_project.yml
Validating profile inputs, adapters, and connection

       dbt 2.0.6
   Loading ~/.dbt/profiles.yml
 Debugging profile: dev
 Debugging dbt version: 2.0.6
 Debugging platform: linux x86_64 (unix)
 Debugging adapter type: duckdb (remote)
 Debugging dependencies:
  git: OK
 Debugging connection:
  "path": "dev.duckdb"
 Debugging connection test: OK (1.1s)
  Debugged All checks passed!

====================================================================================== Execution Summary =======================================================================================
Finished 'init' successfully for target 'dev' [1m 19s]

```


## 2. Anatomía de `dbt_project.yml`

Abre `proyecto-ejemplo/dbt_project.yml`. Puntos clave:

```yaml
name: tienda_online

profile: tienda_online

seed-paths: ["seeds"]
model-paths: ["models"]
macro-paths: ["macros"]
clean-targets:
  - "target"
  - "dbt_packages"

seeds:
  # Builds seeds into '<your_schema_name>_raw'
  tienda_online:
    +schema: raw

models:
  tienda_online:
    +static_analysis: strict
    # Materialize staging models as views, and marts as tables
    staging:
      +materialized: view
    marts:
      +materialized: table

```

La sección `models:` permite fijar configuración (materialización, esquema, tags...) **por carpeta**, sin tener que repetirla en cada fichero `.sql`. Se puede sobrescribir modelo a modelo con un bloque
`{{ config(...) }}` dentro del propio `.sql` (lo veremos en el Módulo 06).
Se indican los directorios en donde se encontrarán los archivos de modelos, seeds, y macros. Así como la configuración del proceso de limpieza cuando se lance un **dbt clean**, en este caso se borrará el contenido de los directorios target y dbt_packages

## 3. Anatomía de `profiles.yml`

Este fichero vive **fuera** del proyecto, en `~/.dbt/profiles.yml`, precisamente porque normalmente contiene credenciales y no debe versionarse en git. En nuestro caso, al usar DuckDB, no hay ni usuario ni contraseña:

```yaml
tienda_online:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: 'tienda_online.duckdb'
      threads: 4
```

- `target: dev` indica qué `output` se usa si no se especifica otro con `--target`.
- Puedes tener varios `outputs` (dev, prod, ci...) apuntando a ficheros `.duckdb` distintos — es la forma de simular "entornos" sin un warehouse real.

## 4. Comandos esenciales

| Comando | Qué hace |
|---|---|
| `dbt debug` | Verifica conexión y configuración. Primer comando a ejecutar siempre. |
| `dbt deps` | Descarga los paquetes declarados en `packages.yml` (Módulo 10). |
| `dbt seed` | Carga los CSV de `seeds/` como tablas. |
| `dbt run` | Ejecuta los modelos (`models/`), en orden de dependencias. |
| `dbt test` | Ejecuta los tests declarados (Módulo 07). |
| `dbt build` | Hace `seed` + `run` + `test` + `snapshot` en el orden correcto del DAG, parando si algo falla "aguas arriba". |
| `dbt compile` | Solo compila Jinja→SQL, sin ejecutar nada contra la BD (útil para depurar). |
| `dbt docs generate` / `dbt docs serve` | Genera y sirve la documentación (Módulo 10). |
| `dbt clean` | Borra `target/` y `dbt_packages/`. |

> **⚠️ Diferencia v1 vs v2:** en v1 estos comandos van precedidos de `dbt` a secas (`dbt run`). En Fusion existe también `dbt build`, `dbt run`, etc. de forma idéntica — la sintaxis de comandos no cambia; lo que cambia es el motor que hay detrás compilando y validando el SQL.


### Importante: dbt parsea TODO el proyecto antes de ejecutar nada

Este punto es clave y se explica poco: cualquier comando de dbt — incluido uno tan aparentemente aislado como `dbt seed`, que solo debería tocar los CSV de `seeds/, empieza siempre por **parsear el proyecto entero**: todos los `.sql` de `models/`, todos los `.yml`, todos los `snapshots/`, todas las `macros/`. Esto es así porque dbt necesita construir primero el **DAG completo** (todas las dependencias entre `ref()` y `source()`) antes de poder decidir qué hacer con el subconjunto que le has pedido.

**Consecuencia práctica:** si hay un `ref()` o un `source()` roto en *cualquier* fichero `.sql` del proyecto —aunque ese modelo no tenga nada que ver con lo que estás ejecutando—, el parseo falla y **ningún** comando se ejecuta, ni siquiera `dbt seed` o `dbt debug`. El error que
verás (`DependencyNotFound`, por ejemplo) apunta al fichero `.sql` concreto que rompe el parseo, no al comando que lanzaste.

Esto es distinto de cómo se comportan `--select` y `--exclude` (punto 6 de este módulo): esos filtros deciden **qué se ejecuta**, pero se aplican **después** de que el parseo del proyecto completo haya tenido éxito. No sirven para "saltarse" un modelo roto.

Si en algún momento un comando falla con un error que apunta a un fichero que no esperabas tocar, **ese es siempre el primer sitio donde mirar**: algo en ese `.sql`/`.yml` (un `ref()` a un modelo que no existe, un `source()` a una tabla no declarada, un YAML mal indentado)
está rompiendo el parseo de todo el proyecto.

## 5. Primera ejecución real

```bash
cd tienda_online
dbt debug          
```


## 7. Logs y artefactos

Cada ejecución genera:

- `logs/dbt.log`: log detallado en texto plano.
- `target/manifest.json` (o `.parquet` en v2): representación completa del proyecto compilado — el "mapa" que usan `dbt docs`, IDEs y herramientas externas.
- `target/run_results.json`: resultado de la última ejecución (qué pasó, cuánto tardó cada modelo, qué falló).

En el siguiente módulo empezamos a construir modelos de verdad.
