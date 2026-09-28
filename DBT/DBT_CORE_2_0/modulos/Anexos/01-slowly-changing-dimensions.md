#ANEXO #SCD
## Slowly Changing Dimensions (SCD)


## ¿Qué es una Slowly Changing Dimension?

Una **dimensión** (en el sentido de modelado dimensional / Kimball) es una tabla que describe el "quién, qué, dónde" de tu negocio: clientes, productos, tiendas, empleados... Se llama **"de cambio lento"** (*slowly changing*) porque sus atributos **sí cambian con el tiempo**, pero no
constantemente — un cliente cambia de país de vez en cuando, un producto cambia de categoría alguna vez, un empleado cambia de departamento cada cierto tiempo.

El problema que resuelven las estrategias SCD es sencillo de enunciar pero incómodo de ignorar:

> Cuando un atributo de una fila cambia, **¿qué hago con el valor anterior? ¿Lo pierdo, lo guardo, o lo guardo de otra forma?**

Ejemplo base que usaremos en todo este documento (el mismo cliente del proyecto de ejemplo de la formación):

| customer_id | full_name   | country (antes) | country (después, 1 marzo) |
| ----------- | ----------- | --------------- | -------------------------- |
| 3           | Sofía López | PT              | ES                         |

La cliente Sofía se muda de Portugal a España el 1 de marzo. La pregunta de negocio típica es: *"¿en qué país estaba Sofía cuando hizo su pedido de febrero?"* — la respuesta correcta es **PT**, aunque hoy su ficha diga **ES**. Cómo se responde a esa pregunta depende del tipo de SCD que
elijas.

## Tipo 0 — No hacer nada (Retain Original)

**Regla:** el valor original se queda fijo para siempre; los cambios posteriores **se ignoran** para ese campo.

| customer_id | full_name   | country |
| ----------- | ----------- | ------- |
| 3           | Sofía López | **PT**  |

Aunque Sofía se mude, este campo nunca se actualiza. Se usa para atributos que, por definición de negocio, deben quedar congelados: la **fecha de alta original**, el **país de registro inicial**, el **precio de lista con el que se firmó un contrato**. No es que "se te olvide" actualizarlo — es una decisión deliberada de que ese dato histórico no debe tocarse jamás.

## Tipo 1 — Sobrescribir (Overwrite)

**Regla:** se actualiza el valor en el sitio. **No queda ningún rastro** del valor anterior.

Antes del cambio:

| customer_id | full_name   | country |
| ----------- | ----------- | ------- |
| 3           | Sofía López | PT      |

Después del cambio (mismo registro, actualizado):

| customer_id | full_name   | country |
| ----------- | ----------- | ------- |
| 3           | Sofía López | **ES**  |

- Es lo que hace, por defecto, cualquier tabla operacional normal (un `UPDATE` de toda la vida) — y también lo que hace un modelo dbt  `materialized='table'` en cada `dbt run`: siempre refleja el estado  **actual**, sin histórico.
- **Ventaja:** simple, barato, la tabla no crece.
- **Inconveniente:** pierdes la capacidad de responder "¿cómo era este  dato en el pasado?". Si un informe de febrero se vuelve a ejecutar hoy,  Sofía aparecerá como española también en los datos de febrero —  aunque en febrero viviera en Portugal.
- Se usa cuando el valor histórico **no importa para el análisis**:  errores tipográficos corregidos, un teléfono de contacto actualizado,   etc.

## Tipo 2 — Nueva fila por cada cambio (Full History)

**Regla:** cuando cambia un valor, **no se toca la fila antigua**: se "cierra" y se **inserta una fila nueva** con el valor actualizado. Cada fila representa una **versión** del registro, válida durante un rango de
fechas.

Se añaden columnas técnicas de control, normalmente:

- `valid_from` (o `dbt_valid_from`): desde cuándo es válida esta versión.
- `valid_to` (o `dbt_valid_to`): hasta cuándo fue válida (`NULL` o una  fecha muy lejana = versión vigente).
- A veces también `is_current` (booleano) como atajo.

| customer_id | full_name   | country | valid_from | valid_to   |
| ----------- | ----------- | ------- | ---------- | ---------- |
| 3           | Sofía López | PT      | 2024-02-03 | 2026-03-01 |
| 3           | Sofía López | **ES**  | 2026-03-01 | `NULL`     |

- Ahora **sí** puedes responder correctamente: "el pedido de febrero se  une con la fila donde `order_date` cae dentro de `[valid_from, valid_to)`" → devuelve `PT`. Y una consulta de "estado actual" filtra  por `valid_to IS NULL` → devuelve `ES`.
- **Ventaja:** histórico completo y consultable con SQL normal (un JOIN  con rango de fechas).
- **Inconveniente:** la tabla crece con cada cambio (una fila por  versión, no por entidad); las consultas que solo quieren "el estado  actual" necesitan filtrar explícitamente por la versión vigente.
- **Es el tipo que implementa `dbt snapshot`**, como viste en el  Módulo 09:

  ```sql
  {% snapshot customers_snapshot %}
  {{ config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='check',
      check_cols=['country', 'email'],
  ) }}
  select * from {{ source('tienda_online_raw', 'raw_customers') }}
  {% endsnapshot %}
  ```

  dbt genera automáticamente `dbt_valid_from` / `dbt_valid_to` cada vez   que detecta un cambio en `check_cols` (estrategia `check`) o en la   columna de timestamp (estrategia `timestamp`).

## Tipo 3 — Columna adicional para el valor anterior

**Regla:** en vez de nuevas filas, se añade una **columna extra** para guardar el valor previo (normalmente solo el *inmediatamente* anterior, no todo el histórico).

| customer_id | full_name   | country_actual | country_anterior |
| ----------- | ----------- | -------------- | ---------------- |
| 3           | Sofía López | **ES**         | PT               |

- **Ventaja:** no hace crecer el número de filas; muy fácil de consultar  ("comparar antes/después") sin JOINs.
- **Inconveniente grande:** solo guarda **una** transición. Si Sofía se  muda una segunda vez (de España a México), el valor `PT` se pierde  para siempre — no hay sitio donde guardarlo sin añadir otra columna  más.
- Se usa en casos muy concretos donde de verdad solo interesa "valor  actual vs. valor anterior inmediato" y nunca vas a necesitar más  profundidad histórica (p. ej., "territorio de ventas anterior" para  una transición organizativa puntual).

## Tipo 4 — Tabla de histórico separada

**Regla:** se mantiene una tabla "actual" tipo 1 (siempre sobrescrita, rápida de consultar) **y**, en paralelo, una tabla de histórico independiente tipo 2 con todas las versiones.

**Tabla actual** (`dim_customers`):

| customer_id | full_name | country |
|---|---|---|
| 3 | Sofía López | ES |

**Tabla de histórico** (`dim_customers_history`):

| customer_id | full_name | country | valid_from | valid_to |
|---|---|---|---|---|
| 3 | Sofía López | PT | 2024-02-03 | 2026-03-01 |
| 3 | Sofía López | ES | 2026-03-01 | `NULL` |

- **Ventaja:** la tabla "actual" se queda pequeña y rápida (ideal para  BI que solo necesita el presente), mientras el histórico completo vive  aparte, sin penalizar las consultas del día a día.
- **Inconveniente:** hay que mantener y sincronizar **dos** tablas en  vez de una.
- Es, de hecho, el patrón natural cuando combinas en dbt una **mart**  normal (`dim_customers`, tabla) con su **snapshot** correspondiente  (`customers_snapshot`, tipo 2) — cada uno cumple un rol distinto,  como en el proyecto de ejemplo de esta formación.

## Tipo 5 — Mini-dimensión + clave actual (referencia, no se usa en la práctica)

> **⚠️ Este tipo se incluye únicamente como referencia teórica.** Es poco frecuente en proyectos reales, especialmente en tooling moderno  como dbt, donde el tipo 2 (snapshot) resuelve casi todos los casos con mucho menos esfuerzo de modelado. Prácticamente no encontrarás
> implementaciones de tipo 5 fuera de datawarehouses Kimball "clásicos"  ya antiguos.

**Regla:** combina el **tipo 1** y el **tipo 4**. Los atributos que cambian con mucha frecuencia (y que además tienen pocos valores posibles, como un rango de edad o un segmento de cliente) se separan a una tabla aparte llamada **mini-dimensión**, que guarda cada **combinación** de esos atributos como si fuera un catálogo. La dimensión principal se actualiza tipo 1 (sobrescribe) y además guarda una **clave** que apunta a la fila vigente de la mini-dimensión.

**Dimensión principal** (`dim_customers`, tipo 1 — siempre el valor actual):

| customer_id | full_name | country | current_segment_key |
|---|---|---|---|
| 3 | Sofía López | ES | **7** |

**Mini-dimensión** (`dim_customer_segment_history`, catálogo de combinaciones + rango de validez, al estilo tipo 4):

| segment_key | segmento | valid_from | valid_to |
|---|---|---|---|
| 4 | Nuevo cliente | 2024-02-03 | 2024-08-01 |
| 7 | Cliente recurrente | 2024-08-01 | `NULL` |

- `country` se comporta como tipo 1: sin histórico, se sobrescribe. 
- `current_segment_key` sí permite reconstruir el histórico de  **segmento**, porque apunta a una fila concreta de la mini-dimensión  vigente en cada momento.
- **Ventaja teórica:** evita que la dimensión principal crezca sin  control (tipo 2) cuando el atributo cambiante tiene pocos valores  posibles y cambia con mucha frecuencia (ideal para "mini-dimensiones"  de scoring o segmentación que se recalculan a diario).
- **Inconveniente (por eso apenas se usa hoy):** modelo mucho más  complejo de diseñar y mantener que un simple `dbt snapshot`; obliga a  gestionar claves subrogadas y una tabla de catálogo adicional a mano;  con motores columnares modernos y baratos en almacenamiento, el  "problema" que resolvía (tablas tipo 2 demasiado grandes) ya no
  justifica la complejidad añadida en la inmensa mayoría de los casos.

## Tipo 6 — Híbrido (1 + 2 + 3)

**Regla:** combina las tres ideas anteriores en una sola tabla: nueva fila por cambio (tipo 2) + columna de "valor actual" repetida en todas las versiones (tipo 1) + columna de "valor anterior" (tipo 3).

| customer_id | full_name | country_en_esa_version | country_actual | country_anterior | valid_from | valid_to |
|---|---|---|---|---|---|---|
| 3 | Sofía López | PT | **ES** | PT | 2024-02-03 | 2026-03-01 |
| 3 | Sofía López | ES | **ES** | PT | 2026-03-01 | `NULL` |

- `country_en_esa_version` → como en tipo 2, refleja el valor válido en  esa fila concreta (para análisis histórico exacto). 
- `country_actual` → como en tipo 1, siempre muestra el valor de **hoy**  en **todas** las filas (para poder filtrar "todo el histórico de  clientes que hoy están en España", sin importar dónde estaban antes).
- `country_anterior` → como en tipo 3, valor previo inmediato.
- **Ventaja:** máxima flexibilidad analítica en una sola tabla.
- **Inconveniente:** el más complejo de mantener y el que más columnas  técnicas añade; solo se justifica en dimensiones muy consultadas donde  de verdad se necesitan los tres ángulos a la vez.

## Tabla resumen

| Tipo | ¿Guarda histórico? | ¿Crece la tabla? | ¿Columnas extra? | Caso de uso típico |
|---|---|---|---|---|
| **0** — Retener original | Sí, pero congelado (nunca se actualiza) | No | No | Fecha de alta, condiciones originales de contrato |
| **1** — Sobrescribir | No | No | No | Correcciones de datos, campos sin relevancia histórica |
| **2** — Nueva fila | Sí, completo | Sí (una fila por versión) | `valid_from` / `valid_to` | Auditoría, análisis histórico exacto — **lo que hace `dbt snapshot`** |
| **3** — Columna anterior | Solo la última transición | No | 1 columna extra por atributo | Comparar "antes vs. ahora" sin necesitar todo el histórico |
| **4** — Tabla separada | Sí, en tabla aparte | La tabla actual no; la de histórico sí | Tabla nueva completa | BI rápido sobre el presente + auditoría en otro sitio |
| **5** — Mini-dimensión ⚠️ *(no se usa en la práctica, solo referencia)* | Sí, para el atributo en la mini-dimensión; no para el resto | Mini-dimensión sí, principal no | Clave + tabla de catálogo | Datawarehouses Kimball clásicos con atributos de baja cardinalidad y cambio muy frecuente |
| **6** — Híbrido | Sí, completo + resumen | Sí | Varias | Dimensiones críticas que se consultan desde muchos ángulos a la vez |

## ¿Cuál usar en la práctica con dbt?

- Para el **99% de los casos** donde necesitas histórico real: **tipo  2**, vía `dbt snapshot`. Es la opción con soporte nativo en dbt, sin  tener que programar nada a mano.
- Si no necesitas histórico y solo quieres el estado actual: no hace  falta ningún mecanismo especial — un modelo `table` normal ya es,  efectivamente, **tipo 1**.
- Los tipos 0, 3, 4 y 6 no tienen soporte "de fábrica" en dbt: si los  necesitas, se construyen a mano combinando modelos normales con (o  sin) un snapshot tipo 2 por debajo, como se explica en el tipo 4.
- El **tipo 5** se incluye en este documento solo por completitud de  referencia: no lo vas a necesitar en un proyecto dbt moderno, y no hay  ningún ejemplo de él en el proyecto de la formación.
