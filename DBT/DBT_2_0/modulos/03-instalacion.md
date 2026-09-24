# Módulo 03 · Instalación

Vamos a instalar dbt sin depender de ningún warehouse externo: usaremos
**DuckDB**, un motor analítico embebido que vive en un único fichero
local. No hace falta Docker, ni un servidor de base de datos, ni
credenciales de ningún tipo.

Hay dos rutas de instalación. Elige una (o instala las dos, no son
excluyentes — ver Módulo 01, sección 4).

## Opción A — dbt v2 (motor Fusion; recomendada para esta formación)

> **Nota de nomenclatura (actualizado tras la GA de dbt 2.0.0, 14 de
> septiembre de 2026):** dbt Labs ya no usa "Fusion" como nombre del
> producto instalable. Lo que se instala se llama **`dbt`**
> (distribución propietaria) o **`dbt-oss`** (100% open source, Apache
> 2.0); "Fusion" es ahora el nombre del motor en Rust que hay detrás de
> ambas. Este módulo usa `dbt` como nombre de comando por ser el más
> habitual, pero si tu organización requiere la variante estrictamente
> open source, sustituye el binario por `dbt-oss` en los mismos pasos.

### macOS / Linux

```bash
# Instalador oficial (descarga el binario de dbt v2 / motor Fusion)
curl -fsSL https://public.cdn.getdbt.com/fs/install/install.sh | sh -s -- --update

# Alternativa vía Homebrew
brew install dbt
```

### Windows

```powershell
winget install dbt-labs.dbt
```

### Verificar la instalación

```bash
dbt --version
```

Deberías ver algo como:

```
Core:
  - installed: 2.0.0
  ...
```

### Adaptador DuckDB en v2: ya no se instala aparte

**Este es el cambio más relevante para este curso.** En v1, el
adaptador de DuckDB (`dbt-duckdb`) es un paquete Python independiente
que instalas con `pip` (ver Opción B). En v2, la arquitectura cambia:
los adaptadores viven **dentro del propio binario/monorepo en Rust** y
se conectan a través de drivers **ADBC**, en lugar de ser paquetes
Python sueltos.

En la práctica, para DuckDB esto significa que **no hay nada que
instalar**: la primera vez que ejecutas un comando dbt contra un
`profiles.yml` con `type: duckdb`, dbt **descarga y cachea el driver de
DuckDB automáticamente**. Basta con tener `dbt` instalado (paso
anterior) y un `profiles.yml` válido — el Módulo 04 lo explica en
detalle.

(Si más adelante necesitas trabajar con catálogos DuckLake o Iceberg,
v2 los soporta de forma nativa vía `catalogs.yml`; queda fuera del
alcance de esta formación, se menciona en el Módulo 10 como contenido
para ir más allá.)

### Editor recomendado

Instala la **extensión oficial de dbt para VS Code**: añade autocompletado,
"ir a definición" para `ref()`/`source()`, previsualización de linaje y
resaltado de errores de SQL en tiempo real gracias al language server de
Fusion.

## Opción B — dbt Core v1.x "clásico" (motor Python)

Útil si tu organización todavía trabaja sobre la línea v1, o si quieres
comparar el comportamiento de ambos motores. A diferencia de v2, aquí sí
hace falta instalar el adaptador de DuckDB como paquete Python aparte
(`dbt-duckdb`).

```bash
python3 -m venv venv
source venv/bin/activate        # en Windows: venv\Scripts\activate

pip install --upgrade pip
pip install -r requirements.txt  # ver proyecto-ejemplo/requirements.txt
```

Contenido de `requirements.txt`:

```
dbt-core>=1.10,<2.0
dbt-duckdb>=1.9
```

Verifica con:

```bash
dbt --version
```

## Comprobación final (cualquiera de las dos opciones)

```bash
cd proyecto-ejemplo
mkdir -p ~/.dbt
cp profiles.yml ~/.dbt/profiles.yml
dbt debug
```

Salida esperada (resumida):

```
Connection:
  path: tienda_online.duckdb
  ...
Connection test: [OK connection ok]
All checks passed!
```

Si ves `All checks passed!`, ya tienes un entorno funcional. En el
Módulo 04 exploramos en detalle qué acabas de configurar.

## Problemas comunes

| Síntoma | Causa habitual | Solución |
|---|---|---|
| `dbt: command not found` | El binario no está en el `PATH` | Reabre la terminal o revisa la salida del instalador (suele indicar la línea a añadir al perfil de shell) |
| `Could not find profile named 'tienda_online'` | `profiles.yml` no está en `~/.dbt/` | Repite el `cp profiles.yml ~/.dbt/profiles.yml` |
| Error de permisos al crear `tienda_online.duckdb` | Ejecutando `dbt` desde una carpeta sin permisos de escritura | Ejecuta desde `proyecto-ejemplo/` con permisos de usuario normales |
