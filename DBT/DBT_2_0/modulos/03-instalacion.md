# Módulo 03 · Instalación

Vamos a instalar dbt sin depender de ningún warehouse externo: usaremos
**DuckDB**, un motor analítico embebido que vive en un único fichero
local. No hace falta Docker, ni un servidor de base de datos, ni
credenciales de ningún tipo.

Hay dos rutas de instalación. Elige una (o instala las dos, no son
excluyentes — ver Módulo 01, sección 4).

## Opción A — dbt Core v2 / Fusion (recomendada para esta formación)

### macOS / Linux

```bash
# Instalador oficial (descarga el binario de Fusion)
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
  - installed: 2.0.x
  ...
```

### Adaptador DuckDB en v2

El driver de DuckDB **viene integrado en el binario de Fusion**: no hace
falta instalar nada adicional para el caso de uso de este curso. (Si más
adelante necesitas extensiones de DuckDB como `httpfs` o `parquet`, el
driver embebido no las soporta y hay que instalar el driver externo
`dbc`; queda fuera del alcance de esta formación, se menciona solo como
referencia.)

### Editor recomendado

Instala la **extensión oficial de dbt para VS Code**: añade autocompletado,
"ir a definición" para `ref()`/`source()`, previsualización de linaje y
resaltado de errores de SQL en tiempo real gracias al language server de
Fusion.

## Opción B — dbt Core v1.x "clásico" (motor Python)

Útil si tu organización todavía trabaja sobre la línea v1, o si quieres
comparar el comportamiento de ambos motores.

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
