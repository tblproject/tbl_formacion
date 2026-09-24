#DBT_CORE 
# Módulo 04 · Primer proyecto y ejecución

## 1. Crear un proyecto desde cero (referencia)

Para *este* curso ya tienes el proyecto generado en `proyecto-ejemplo/`, pero así es como se crea uno nuevo desde cero:

```bash
dbt init tienda_online
```

Esto pregunta interactivamente el nombre del proyecto y el adaptador, y genera el esqueleto: `dbt_project.yml`, carpeta `models/` con un ejemplo, y una entrada en `~/.dbt/profiles.yml`.

## 2. Anatomía de `dbt_project.yml`

Abre `proyecto-ejemplo/dbt_project.yml`. Puntos clave:

```yaml
name: 'tienda_online'
profile: 'tienda_online'       # debe existir una entrada con este nombre en profiles.yml

model-paths: ["models"]
seed-paths: ["seeds"]

models:
  tienda_online:
    staging:
      +materialized: view       # config por defecto para TODO lo que esté en models/staging
```

La sección `models:` permite fijar configuración (materialización, esquema, tags...) **por carpeta**, sin tener que repetirla en cada fichero `.sql`. Se puede sobrescribir modelo a modelo con un bloque
`{{ config(...) }}` dentro del propio `.sql` (lo veremos en el Módulo 06).

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

## 5. Primera ejecución real

```bash
cd proyecto-ejemplo
dbt debug          # ya lo hicimos en el Módulo 03, pero repítelo si acabas de instalar
dbt seed           # carga raw_customers, raw_orders, raw_products, raw_order_items
```

Salida esperada (resumida):

```
1 of 4 OK loaded seed file seeds.raw_customers .......... [INSERT 15 in 0.05s]
2 of 4 OK loaded seed file seeds.raw_orders ............. [INSERT 25 in 0.03s]
3 of 4 OK loaded seed file seeds.raw_products ........... [INSERT 15 in 0.03s]
4 of 4 OK loaded seed file seeds.raw_order_items ........ [INSERT 32 in 0.03s]
```

En el Módulo 05 declaramos estos seeds como `source()` y creamos los primeros modelos de staging. Por ahora, inspecciona el resultado directamente con el CLI de DuckDB:

```bash
python3 -c "
import duckdb
con = duckdb.connect('tienda_online.duckdb')
print(con.sql('select * from seeds.raw_customers limit 5'))
"
```

(o instala el CLI nativo de DuckDB — `duckdb tienda_online.duckdb` — si lo prefieres).

## 6. Selectors: ejecutar solo una parte del DAG

No hace falta ejecutar siempre todo el proyecto:

```bash
dbt run --select stg_customers          # un único modelo
dbt run --select staging                # toda una carpeta/tag
dbt run --select stg_orders+            # stg_orders y todo lo que depende de él
dbt run --select +fct_orders            # fct_orders y todo lo que necesita para construirse
dbt run --select tag:core               # por tag
dbt run --exclude stg_products          # todo menos ese modelo
```

Este mismo lenguaje de selección funciona igual en `dbt test`, `dbt build` y `dbt docs generate`. Es la base para ejecuciones incrementales y para integrarlo, en el futuro, con un orquestador (fuera del alcance de este curso).

## 7. Logs y artefactos

Cada ejecución genera:

- `logs/dbt.log`: log detallado en texto plano.
- `target/manifest.json` (o `.parquet` en v2): representación completa del proyecto compilado — el "mapa" que usan `dbt docs`, IDEs y herramientas externas.
- `target/run_results.json`: resultado de la última ejecución (qué pasó, cuánto tardó cada modelo, qué falló).

En el siguiente módulo empezamos a construir modelos de verdad.
