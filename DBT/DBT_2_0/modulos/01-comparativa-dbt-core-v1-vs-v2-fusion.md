# Módulo 01 · Comparativa: dbt Core v1 vs dbt Core v2 (Fusion)

> Módulo introductorio. No requiere tener nada instalado todavía.

## 1. Un poco de historia reciente

- **dbt Core v1.x**: la línea "clásica" de dbt, escrita en Python, en
  desarrollo continuo desde el lanzamiento de dbt 1.0 (diciembre de 2021).
- **dbt Fusion engine**: motor de nueva generación anunciado por dbt Labs,
  reescrito desde cero en **Rust**, con comprensión nativa de SQL (no solo
  renderiza Jinja y lo manda al warehouse "a ciegas"). Se distribuyó
  inicialmente bajo licencia **Elastic License v2 (ELv2)**, es decir, de
  código disponible pero no estrictamente open source.
- **dbt Core v2.0**: a partir de 2026, dbt Labs fusiona ambos proyectos.
  El motor en Rust que impulsaba Fusion se libera como código abierto bajo
  **Apache 2.0** dentro del propio repositorio `dbt-core`, y pasa a ser el
  motor de dbt Core a partir de la versión 2.0. El repositorio histórico
  de Fusion queda archivado: todo el desarrollo se centraliza en un único
  motor compartido.

En otras palabras: **"dbt Core v2" y "Fusion" dejan de ser dos productos
distintos con dos motores distintos**. A partir de v2.0 comparten el mismo
núcleo en Rust. La diferencia real está en cómo se distribuye ese núcleo:

- **dbt Core v2 (código abierto puro)**: el binario/paquete construido
  directamente desde el repositorio Apache 2.0.
- **Fusion**: la distribución precompilada y "enriquecida" de dbt Labs
  sobre ese mismo motor, con funciones adicionales (algunas de pago,
  activadas mediante login) como el language server para el IDE,
  análisis estático avanzado o gestión de estado en la nube.

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
| Adaptadores | Ecosistema maduro, décadas de adaptadores de la comunidad | Compatibilidad casi total; algunos adaptadores/funcionalidades aún en beta (ver notas de cada adaptador) |
| Modelos Python (`.py`) | Soporte estable | Soporte en *preview* público en la fecha de esta formación |
| Instalación | `pip install dbt-core dbt-<adaptador>` | Instalador dedicado (`dbt system install` / Homebrew / winget) o vía `pip` para la variante open source pura |
| DuckDB | Adaptador de la comunidad `dbt-duckdb`, maduro y completo | Driver embebido en el propio binario (algunas extensiones de DuckDB requieren el driver externo `dbc`, ver Módulo 03) |
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
(GA) y precios de Fusion cambian con frecuencia. Antes de impartir este
módulo, se recomienda revisar la página oficial de comparación de
versiones de dbt (`docs.getdbt.com`) por si algún dato de esta tabla ha
quedado desactualizado.
