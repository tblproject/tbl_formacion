#DBT_CORE 
# Módulo 02 · Conceptos básicos

## 1. ¿Qué es dbt?

**dbt (data build tool)** es una herramienta de **transformación** de datos. No extrae datos de sistemas origen ni los carga en el warehouse (eso lo hacen herramientas de EL/ELT como Fivetran, Airbyte o scripts amedida). dbt entra en juego **después**: coge datos que ya están en tu base de datos analítica y los transforma en tablas y vistas limpias, testadas y documentadas, usando únicamente **SELECT** en SQL.

Filosofía central: **cada modelo dbt es un `SELECT`** guardado en un fichero `.sql`. dbt se encarga de:

1. Envolver ese `SELECT` en un `CREATE TABLE AS` / `CREATE VIEW AS` (u otras estrategias, ver Módulo 06).
2. Resolver las dependencias entre modelos (`ref()`), en el orden  correcto.
3. Ejecutarlo contra la base de datos.
4. Testarlo, documentarlo y versionarlo como si fuera código de aplicación (porque lo es).

## 2. ELT, no ETL

| | ETL clásico | ELT (enfoque de dbt) |
|---|---|---|
| Orden | Extraer → **Transformar** → Cargar | Extraer → Cargar → **Transformar** |
| Dónde se transforma | En un servidor intermedio | Dentro del propio warehouse, con SQL |
| Quién transforma | Herramienta ETL dedicada | dbt (compila y ejecuta SQL) |

dbt asume que los datos crudos **ya están cargados** en el warehouse (o, en nuestro caso, en el fichero DuckDB) antes de que dbt entre en juego.

## 3. Las capas típicas de un proyecto dbt

Convención muy extendida en la comunidad (no es obligatoria, pero se usa en este curso y en el proyecto de ejemplo):

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

En el proyecto de ejemplo (`proyecto-ejemplo/`) verás exactamente esta estructura: `models/staging`, `models/intermediate`, `models/marts/core`.

## 4. Glosario mínimo

| Término             | Significado                                                                                                                        |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Modelo**          | Fichero `.sql` con un `SELECT`; se compila y materializa como tabla/vista.                                                         |
| **`ref()`**         | Función Jinja para referenciar otro modelo dbt. dbt resuelve el DAG a partir de estas llamadas.                                    |
| **`source()`**      | Función Jinja para referenciar una tabla "cruda" (no generada por dbt), declarada en un `.yml`.                                    |
| **Materialización** | Estrategia física de persistencia de un modelo: `view`, `table`, `incremental`, `ephemeral`.                                       |
| **DAG**             | Grafo de dependencias entre modelos, sources, seeds, snapshots, etc., que dbt construye automáticamente.                           |
| **Seed**            | Fichero CSV versionado en el proyecto que dbt carga como tabla (`dbt seed`). Pensado para datos de referencia pequeños y estables. |
| **Snapshot**        | Mecanismo de dbt para capturar el histórico de cambios de una tabla mutable (SCD tipo 2).                                          |
| **Test**            | Aserción SQL sobre los datos; falla si la query devuelve filas (o, en `unit tests`, si la salida no coincide con la esperada).     |
| **Macro**           | Función reutilizable escrita en Jinja + SQL.                                                                                       |
| **Manifest**        | Artefacto (`manifest.json` en v1, JSON/Parquet en v2) que representa el estado completo compilado del proyecto.                    |
| **Selector**        | Sintaxis (`--select`, `--exclude`) para elegir qué subconjunto del DAG ejecutar.                                                   |

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

A partir del Módulo 04 ejecutaremos este ciclo de verdad, sobre datos reales, sin ningún orquestador de por medio: todo desde la terminal.

## 6. Materialización
### `view`

**Qué crea:** `CREATE VIEW nombre_modelo AS <tu SELECT>`

- **No hay persistencia de datos.** DuckDB solo guarda la _definición_ de la consulta.
- Cada vez que alguien hace `SELECT * FROM ese_modelo`, la base de datos **re-ejecuta el SELECT original en ese instante**, sobre los datos que haya en ese momento.
- **Coste de almacenamiento:** prácticamente cero.
- **Coste de lectura:** se paga cada vez que se consulta (recalcula todo el SELECT en cada acceso).
- **Frescura:** siempre 100% actualizada, porque no hay copia — refleja el estado actual de las tablas de las que depende.
- Por eso es la materialización por defecto para **staging**: son consultas ligeras (renombrar columnas, castear tipos) que no compensa duplicar en disco.

### `table`

**Qué crea:** `DROP TABLE IF EXISTS ...` + `CREATE TABLE nombre_modelo AS <tu SELECT>`

- **Persistencia física completa.** El resultado del `SELECT` se materializa y se escribe en disco como una tabla real, con sus propias filas físicas.
- En **cada `dbt run`**, dbt **borra la tabla entera y la vuelve a crear desde cero** — no es un `INSERT`/`UPDATE` incremental, es una reconstrucción total.
- **Coste de almacenamiento:** el más alto de las cuatro (duplica los datos).
- **Coste de lectura:** el más bajo — quien consulta la tabla lee filas ya calculadas, sin recalcular nada.
- **Frescura:** tan actualizada como la última vez que se ejecutó `dbt run`; si no se relanza, queda desfasada respecto al origen.
- Ideal para **marts** que se consultan mucho (dashboards) y donde recalcular todo en cada `run` sigue siendo asumible en tiempo/coste.

### `ephemeral`

**Qué crea:** literalmente **nada** en la base de datos.

- No hay `CREATE VIEW` ni `CREATE TABLE`. El modelo **no existe como objeto físico** en ningún momento.
- Su SQL se **inyecta como CTE (`WITH ... AS (...)`)** dentro del SQL compilado de cada modelo que lo referencia con `ref()`.
- Ejemplo real de tu proyecto: `int_order_items_enriched` no aparece nunca en `SHOW TABLES`; cuando `fct_orders` hace `ref('int_order_items_enriched')`, dbt pega ese SELECT como un `WITH` al principio de la consulta de `fct_orders`.
- **Coste de almacenamiento:** cero, siempre.
- **Coste de lectura:** se recalcula **cada vez que se ejecuta el modelo que lo consume** (como una vista, pero ni siquiera queda registrado como objeto consultable de forma independiente).
- **Limitación importante:** no puedes hacer `SELECT * FROM ese_modelo` directamente desde fuera de dbt — no existe como tabla ni vista en la base de datos. Solo es visible dentro del SQL compilado de sus "padres".
- Útil para lógica de apoyo intermedia que nadie necesita consultar por sí sola.

### `incremental`

**Qué crea:** una **tabla física real** (igual que `table`), pero con una estrategia de actualización distinta.

- La **primera vez** que se ejecuta (la tabla destino no existe todavía): se comporta exactamente como `table` — `CREATE TABLE AS SELECT` con el 100% de las filas.
- En **ejecuciones posteriores**: dbt **no borra la tabla**. En su lugar, ejecuta algo parecido a:

sql

```sql
  DELETE FROM tabla WHERE <filas que van a actualizarse>;
  INSERT INTO tabla SELECT <solo las filas nuevas/cambiadas>;
```

(el `DELETE+INSERT` es la estrategia que usa DuckDB; otros motores como Snowflake usan `MERGE` — el concepto es el mismo, cambia el SQL exacto bajo el capó).

- El filtro de "qué es nuevo" lo escribes tú con `{% if is_incremental() %}` — dbt no lo adivina solo.
- **Coste de almacenamiento:** igual que `table` (es una tabla completa).
- **Coste de cómputo por ejecución:** mucho menor que `table` a partir de la segunda ejecución, porque solo procesa las filas nuevas, no recalcula el histórico completo.
- **Riesgo:** si tu filtro de "qué es nuevo" está mal escrito, puedes acabar con datos duplicados, huecos o desactualizados sin que dbt te avise — por eso existe `--full-refresh`, que fuerza a tratarla como si fuera la primera ejecución (`DROP` + reconstrucción total) y así "resetear" cualquier inconsistencia.

### Resumen visual

|Materialización|¿Objeto físico?|¿Qué pasa en cada `dbt run`|Frescura de los datos|
|---|---|---|---|
|`view`|No|No aplica (se recalcula en cada `SELECT`, no en el `run`)|Siempre al día|
|`table`|Sí, tabla completa|Borra y reconstruye el 100%|Al día tras cada `run`|
|`ephemeral`|No, ni siquiera consultable aparte|No aplica (se pega como CTE en quien lo usa)|Depende de quién lo consuma|
|`incremental`|Sí, tabla completa|Solo procesa/añade las filas nuevas|Al día tras cada `run`, más barato de mantener|
