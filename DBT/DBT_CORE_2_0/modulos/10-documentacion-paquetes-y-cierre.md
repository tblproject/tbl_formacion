#DBT_CORE 
# Módulo 10 · Documentación, paquetes y cierre

## 1. Documentar el proyecto

Cada modelo y columna se documenta con la clave `description:` en el `.yml` correspondiente (ya lo hemos ido haciendo en `_staging__models.yml` y `_marts__models.yml`):

```yaml
- name: fct_orders
  description: Una fila por pedido, con importe total y número de artículos.
  columns:
    - name: order_total_eur
      description: Importe total del pedido en euros, IVA no incluido.
```

Para bloques de texto largos y reutilizables (p. ej. una explicación que aplica a varios modelos), se usan **docs blocks** en ficheros `.md` dentro de `models/`:

```markdown
{% docs order_status %}
Estado del pedido en el sistema de gestión de almacén:
- `completed`: entregado sin incidencias
- `shipped`: en tránsito
- `returned`: devuelto por el cliente
- `cancelled`: cancelado antes de enviarse
{% enddocs %}
```

Y se referencia así en el `.yml`:

```yaml
- name: status
  description: '{{ doc("order_status") }}'
```

## 2. Generar y navegar la documentación

```bash
dbt docs generate
dbt docs serve
```

Esto levanta un sitio web local (por defecto en `http://localhost:8080`)
con:

- El **DAG interactivo** completo del proyecto (sources → staging → intermediate → marts), navegable con clic.
- Descripciones de cada modelo/columna.
- El SQL compilado y el SQL "crudo" de cada modelo.
- Los tests aplicados a cada columna.

> **⚠️ Diferencia v1 vs v2:** en Fusion, buena parte de esta información (linaje a nivel de columna incluido) está disponible también en tiempo real dentro del editor gracias al language server — no hace falta esperar a `dbt docs generate` para explorarla mientras escribes SQL.

## 3. Paquetes: `dbt deps`

`packages.yml` declara dependencias externas, igual que un `package.json` o un `requirements.txt`:

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.3.0", "<2.0.0"]
```

```bash
dbt deps
```

Descarga el paquete en `dbt_packages/` (carpeta que **no** se versiona en git — está en `.gitignore`). A partir de ahí puedes usar sus macros y tests con el prefijo del paquete:

```sql
select {{ dbt_utils.generate_surrogate_key(['order_id', 'product_id']) }}
```

```yaml
data_tests:
  - dbt_utils.accepted_range:
      min_value: 0
```

Paquetes de la comunidad especialmente útiles más allá de `dbt_utils`:

| Paquete | Para qué |
|---|---|
| `dbt-labs/codegen` | Genera YAML de sources/modelos automáticamente a partir de tablas existentes. |
| `calogica/dbt_expectations` | Tests de calidad de datos inspirados en Great Expectations. |
| `dbt-labs/dbt_project_evaluator` | Audita el proyecto contra las buenas prácticas de dbt Labs. |

## 4. Freshness de sources (mención)

Sobre el `.yml` de un source se puede declarar:

```yaml
sources:
  - name: tienda_online_raw
    freshness:
      warn_after: {count: 24, period: hour}
      error_after: {count: 48, period: hour}
    loaded_at_field: _loaded_at
```

```bash
dbt source freshness
```

En nuestro proyecto no aplica (los seeds no tienen un timestamp real de carga), pero es imprescindible en un proyecto con ingesta real: avisa si el proceso de EL upstream se ha detenido.

## 4bis. Novedades de dbt v2 específicas de DuckDB (para ir más allá)

Desde la GA de dbt 2.0.0 (septiembre de 2026), además de traer el adaptador de DuckDB integrado (Módulo 03), hay dos capacidades nuevas que no cubrimos en profundidad en este curso pero que merece la pena conocer:

- **Catálogos DuckLake / Iceberg** (`catalogs.yml` + flag `use_catalogs_v2` en `dbt_project.yml`): permite que un modelo materialice contra un catálogo DuckLake o Iceberg en lugar del
  fichero `.duckdb` local, con materializaciones "catalog-aware". Útil cuando el proyecto crece más allá de un único fichero local.
- **Metadatos del proyecto como Parquet** ("Information Schema"):  ejecutando `dbt parse --generate-info-schema` se generan ficheros Parquet en `target/info_schema/` que puedes consultar directamente con SQL (incluido DuckDB) sin parsear `manifest.json` — muy útil para
  scripts de auditoría o comprobaciones de convenciones en CI, en proyectos grandes donde el manifest JSON pesa cientos de MB.

## 5. Recapitulación: comandos que ya dominas

```bash
dbt debug
dbt deps
dbt seed
dbt run       [--select ... | --full-refresh]
dbt test      [--select ...]
dbt build
dbt snapshot
dbt compile   [--select ...]
dbt docs generate && dbt docs serve
dbt list      --select ...
```

## 6. El DAG completo del proyecto de ejemplo

```
raw_customers ──────────┐
raw_orders (+batch2) ────┼──► stg_customers ──► dim_customers
raw_products ────────────┤    stg_orders    ──┬─► fct_orders
raw_order_items ─────────┘    stg_products   ─┤ (table, Módulo 06)
                               stg_order_items ┘  └─► fct_orders_incremental
                                     │                (incremental, Módulo 09)
                                     ▼
                          int_order_items_enriched
                                (ephemeral)

raw_customers ──► customers_snapshot (SCD2, Módulo 09)
```

## 7. Próximos pasos (fuera de esta formación)

Esta formación termina deliberadamente **antes** de la orquestación, para asentar primero el manejo de dbt "a mano". Los siguientes pasos naturales, cuando el equipo domine lo anterior, serían:

- Programar `dbt build` con un orquestador (Airflow, Dagster, dbt Cloud Jobs...) en vez de lanzarlo manualmente.
- Migrar de DuckDB a un warehouse de producción (Snowflake, BigQuery, Databricks, Redshift...) — el 95% del proyecto (modelos, tests, macros, YAML) no cambia; solo cambia `profiles.yml`.
- Integrar dbt en CI/CD (ejecutar `dbt build` en cada pull request sobre un esquema temporal, usando `state:modified` para construir solo lo que ha cambiado).
- Explorar el **dbt Semantic Layer** / MetricFlow para definir métricas reutilizables entre herramientas de BI.
- Si se trabaja con dbt Core v1, planificar la migración a v2/Fusion siguiendo la comparativa del Módulo 01 y la guía oficial de migración de dbt Labs (revisar en el momento de la migración, ya que el proceso recomendado evoluciona con cada release).
