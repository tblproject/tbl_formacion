# Proyecto de ejemplo — Tienda Online (dbt Core v2 + DuckDB)

Proyecto de acompañamiento de la formación **"dbt Core v2 desde cero"**
(ver carpeta `../modulos`). No requiere ningún motor de base de datos
externo: todo corre sobre un fichero DuckDB local.

## Puesta en marcha rápida

```bash
# 1. Copia profiles.yml a tu carpeta de perfiles de dbt
mkdir -p ~/.dbt
cp profiles.yml ~/.dbt/profiles.yml

# 2. Comprueba la conexión
dbt debug

# 3. Instala paquetes externos (dbt_utils)
dbt deps

# 4. Carga los datos de ejemplo (seeds) como si fueran datos "crudos"
dbt seed

# 5. Construye todo el proyecto: modelos + tests + snapshots
dbt build
```

Consulta cada módulo en `../modulos` para ir incorporando comandos y
capacidades progresivamente en lugar de ejecutar `dbt build` desde el
principio.

## Estructura

```
proyecto-ejemplo/
├── dbt_project.yml
├── profiles.yml            # referencia; en un proyecto real va en ~/.dbt/
├── packages.yml
├── requirements.txt         # instalación vía pip (ruta clásica)
├── seeds/                   # datos de partida (simulan la capa "raw")
├── models/
│   ├── staging/              # 1 modelo staging por fuente + sources.yml
│   ├── intermediate/         # modelos ephemeral de apoyo
│   └── marts/core/           # dim_ / fct_ listos para analítica
├── macros/                   # macros propias + test genérico personalizado
├── tests/                    # tests singulares
└── snapshots/                # SCD tipo 2 sobre raw_customers
```
