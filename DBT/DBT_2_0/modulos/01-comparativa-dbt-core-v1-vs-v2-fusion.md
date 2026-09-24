# Módulo 01 · Comparativa: dbt Core v1 vs dbt Core v2 (Fusion)

> Módulo introductorio. No requiere tener nada instalado todavía.

## 1. Un poco de historia reciente

- **dbt Core v1.x**: la línea "clásica" de dbt, escrita en Python, en
  desarrollo continuo desde el lanzamiento de dbt 1.0 (diciembre de 2021).
  Cada adaptador (Snowflake, BigQuery, DuckDB...) es un paquete Python
  independiente que se instala por separado con `pip`.
- **dbt Fusion engine**: motor de nueva generación anunciado por dbt Labs
  el 28 de mayo de 2025, reescrito desde cero en **Rust**, con
  comprensión nativa de SQL (no solo renderiza Jinja y lo manda al
  warehouse "a ciegas"). Se distribuyó inicialmente bajo licencia
  **Elastic License v2 (ELv2)**, es decir, de código disponible pero no
  estrictamente open source. En su beta inicial **no incluía DuckDB**
  como adaptador soportado de fábrica.
- **dbt Core v2.0 (alpha)**: el 1 de junio de 2026 dbt Labs libera la
  primera alpha, fusionando ambos proyectos. El motor en Rust que
  impulsaba Fusion se libera como código abierto bajo **Apache 2.0**
  dentro del propio repositorio `dbt-core` (el repositorio histórico de
  `dbt-fusion` queda archivado).
- **dbt 2.0.0 (GA)**: el **14 de septiembre de 2026** se publica la
  versión estable. En esa misma release dbt Labs **renombra la marca**:
  ya no se habla de "Fusion" como nombre de producto, sino que "Fusion"
  pasa a ser únicamente el nombre del **motor**. Lo que se instala se
  llama simplemente:
  - **`dbt`** → distribución propietaria (con funciones adicionales de
    pago/login).
  - **`dbt-oss`** → distribución 100% open source (Apache 2.0).

  Ambas corren sobre el mismo motor Fusion/Rust y son gratuitas de
  instalar en local; la diferencia está en qué capacidades extra trae
  cada una, no en el motor de ejecución.

> **Nota:** en el resto de esta formación seguimos usando "v2" o
> "Fusion" de forma coloquial para referirnos al motor Rust en general,
> pero a partir de la GA del 14/09/2026 el nombre correcto del producto
> que se instala es **`dbt`** (o `dbt-oss`), no "Fusion". Ajusta el
> vocabulario si impartes el curso más adelante y la nomenclatura ha
> vuelto a cambiar.

En otras palabras: **v1 y v2 dejan de ser dos productos con dos motores
distintos**. A partir de v2.0 comparten el mismo núcleo en Rust. La
diferencia real está en cómo se distribuye ese núcleo y en la
arquitectura de los adaptadores (ver punto 6).

## 2. Tabla comparativa

| Aspecto | dbt Core v1.x (motor Python) | dbt Core v2 / Fusion (motor Rust) |
|---|---|---|
| Lenguaje del motor | Python | Rust |
| Licencia | Apache 2.0 | Apache 2.0 (núcleo) · Fusion añade capas propietarias/de pago |
| Comprensión de SQL | Ninguna: dbt renderiza Jinja y delega el parseo al warehouse | Análisis estático nativo por dialecto SQL antes de ejecutar nada |
| Detección de errores | En tiempo de ejecución (falla contra el warehouse) | En gran parte en tiempo de compilación (antes de tocar el warehouse) |
| Velocidad de parseo/compilación | Referencia histórica | Sensiblemente más rápida en proyectos grandes |
| Linaje a nivel de columna | Limitado / vía introspección del warehouse | Nativo, gracias al parser SQL propio |
| Editor / LSP | Soporte básico vía extensiones de la comunidad | Language Server oficial (autocompletado, "ir a definición", etc.) |
| Artefactos de estado | JSON (`manifest.json`, `run_results.json`) | Parquet + JSON, pensados para escalar y para uso por agentes/IA |
| Adaptadores | Cada adaptador es un **paquete Python independiente** (`dbt-duckdb`, `dbt-snowflake`...) instalado vía `pip` | Los adaptadores viven **dentro del propio monorepo Rust** y se conectan mediante drivers **ADBC**; no se instalan como paquetes Python sueltos |
| Modelos Python (`.py`) | Soporte estable | Soporte en *preview* público en la fecha de esta formación |
| Instalación | `pip install dbt-core dbt-<adaptador>` | Instalador dedicado (`dbt`/`dbt-oss` vía script oficial, Homebrew o winget); un único binario para todos los adaptadores |
| DuckDB | Paquete `dbt-duckdb` de la comunidad (desde 2021), se instala aparte con `pip` | **Integrado de fábrica** desde dbt v2: no hay paquete que instalar — dbt descarga y cachea el driver de DuckDB automáticamente en la primera ejecución (ver Módulo 03) |
| Catálogos DuckLake / Iceberg | No soportado de forma nativa (se hacía vía `ATTACH` manual en el perfil) | Soporte nativo vía `catalogs.yml` + flag `use_catalogs_v2` (ver Módulo 10) |
| Metadatos del proyecto | `manifest.json` / `run_results.json` (puede pesar cientos de MB en proyectos grandes) | Además de JSON, se escriben como **Parquet** ("Information Schema"), consultables directamente con SQL sin parsear el JSON completo |
| Coste | Gratuito, sin condiciones | Núcleo gratuito; algunas funciones de Fusion (p. ej. reutilización de estado en la nube) tienen precio por uso |

## 3. ¿Qué versión usar en esta formación?

Usaremos **dbt Core v2 / Fusion** como referencia principal, porque:

- Es la línea activa de desarrollo de dbt Labs de cara al futuro.
- El flujo de trabajo, los ficheros (`dbt_project.yml`, `profiles.yml`) y
  el lenguaje (Jinja + SQL) son **prácticamente idénticos** a v1.x: lo
  aprendido aquí sirve igual si en tu empresa todavía usáis v1.
- DuckDB es justo el escenario donde Fusion brilla para aprender: cero
  fricción, sin credenciales.

Cuando algo se comporte de forma distinta entre v1 y v2 se indicará
explícitamente con una nota como esta:

> **⚠️ Diferencia v1 vs v2:** explicación del cambio.

## 4. Instalar ambas no es excluyente

Es habitual tener conviviendo `dbt-core` (v1, vía pip, para proyectos
existentes) y el CLI de Fusion (v2) en la misma máquina; cada proyecto
apunta a un binario distinto. El Módulo 03 muestra ambas rutas de
instalación.

## 5. Para verificar en el momento de dar la formación

Los detalles de versiones concretas, fechas de disponibilidad general
(GA) y precios cambian con frecuencia — de hecho, esta tabla ya se
actualizó una vez tras la GA de dbt 2.0.0 (14/09/2026) y el
renombrado de marca ("Fusion" → `dbt` / `dbt-oss`). Antes de impartir
este módulo, revisa la página oficial de versiones de dbt
(`docs.getdbt.com`) por si algún dato ha vuelto a cambiar.

## 6. Migrar un proyecto v1 existente a v2

Ruta recomendada por dbt Labs si ya tienes un proyecto en v1.12:

```bash
# 1. Con dbt Core v1.12 instalado, prueba el nuevo parser sin migrar nada todavía
dbt parse --use-v2-parser

# 2. Si parsea sin errores, instala dbt v2 (ver Módulo 03) y usa dbt-autofix
#    para aplicar automáticamente los cambios de sintaxis requeridos
pip install dbt-autofix   # o la vía de instalación que corresponda
dbt-autofix .
```

Es un buen primer paso antes de migrar en serio: detecta incompatibilidades
sin tocar el proyecto real hasta que decides dar el salto.
