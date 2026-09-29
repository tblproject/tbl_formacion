# Módulo 4 — Ejemplos prácticos (laboratorios)

> **Objetivos del módulo**
> - Arrancar tus primeros unikernels con `kraft` y `ops`.
> - Empaquetar aplicaciones reales (Go, Python, Node) como unikernels.
> - **Migrar un contenedor a unikernel** con una metodología reproducible.
> - Ejecutar unikernels sobre **Firecracker** y medir densidad/arranque.
> - **Comparar (benchmark)** contenedor vs unikernel: tamaño, arranque, memoria.
>
> **Prerrequisito:** haber completado el módulo 2 (checklist verde). Todos los labs asumen **Ubuntu Server 24.04 LTS** con KVM activo.
>
> ⚠️ Los comandos concretos pueden variar ligeramente entre versiones del tooling. Ante cualquier discrepancia, `--help` de cada comando y la documentación oficial son la fuente de verdad.

---

## Índice de laboratorios

| Lab | Título | Herramienta | Dificultad |
|-----|--------|-------------|------------|
| 0 | Verificación del entorno | — | ★ |
| 1 | Hello World desde el catálogo | `kraft` | ★ |
| 2 | Servidor HTTP en Go como unikernel | `kraft` + Kraftfile | ★★ |
| 3 | App Python/Flask como unikernel | `kraft` | ★★ |
| 4 | **Migrar un contenedor Docker a unikernel** | `ops` / `kraft` | ★★★ |
| 5 | Volúmenes persistentes con Nanos | `ops` | ★★ |
| 6 | Unikernel sobre **Firecracker** + densidad | `kraft`/Firecracker | ★★★ |
| 7 | **Benchmark** contenedor vs unikernel | Docker + `kraft` | ★★★ |
| 8 | (Bonus) Unikernel *clean-slate* con MirageOS | `mirage` | ★★★★ |

---

## Lab 0 — Verificación del entorno

**Objetivo:** confirmar que el laboratorio está operativo.

```bash
sudo kvm-ok                                   # KVM acceleration can be used
kraft version && ops version                  # ambas herramientas responden
kraft run unikraft.org/helloworld:latest      # arranque de prueba
```

**Resultado esperado:** el helloworld arranca en la consola en milisegundos y termina. Si algo falla, vuelve al módulo 2 (§2.9 Troubleshooting).

> Salir de la consola QEMU: `Ctrl+A` y luego `x`.

---

## Lab 1 — Hello World desde el catálogo (Unikraft)

**Objetivo:** entender el flujo `run` con imágenes precompiladas del catálogo oficial.

```bash
# 1. Ejecutar el ejemplo C precompilado
kraft run unikraft.org/helloworld:latest

# 2. Explorar el catálogo (aplicaciones y runtimes disponibles)
#    https://github.com/unikraft/catalog
```

**Qué observar:**
- La velocidad de arranque (compárala mentalmente con `docker run`).
- Que no hay "sistema": arranca, ejecuta, termina. No hay shell ni servicios de fondo.

**Para profundizar:** clona el catálogo y explora `Kraftfile` de distintos ejemplos:

```bash
git clone https://github.com/unikraft/catalog.git
ls catalog/examples
cat catalog/examples/http-go1.21/Kraftfile   # (la ruta exacta puede variar)
```

---

## Lab 2 — Servidor HTTP en Go como unikernel (Unikraft + Kraftfile)

**Objetivo:** construir un unikernel a partir de tu propio código usando un `Dockerfile` como rootfs.

### 2.1. Código de la aplicación

```bash
mkdir -p ~/labs/go-http && cd ~/labs/go-http
```

`main.go`:

```go
package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hola desde un unikernel Unikraft (Go)!")
	})
	fmt.Println("Escuchando en :8080")
	http.ListenAndServe(":8080", nil)
}
```

### 2.2. `Dockerfile` (solo para construir el rootfs con el binario)

```dockerfile
# Compila el binario estático de Go
FROM golang:1.22 AS build
WORKDIR /src
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o /server main.go

# Imagen final mínima: solo el binario (será el rootfs del unikernel)
FROM scratch
COPY --from=build /server /server
```

### 2.3. `Kraftfile`

```yaml
spec: v0.6

runtime: base:latest
rootfs: ./Dockerfile
cmd: ["/server"]
```

### 2.4. Construir y ejecutar

```bash
# Construir y ejecutar, publicando el puerto 8080 del unikernel al host
kraft run --rm -p 8080:8080 .
```

En otra terminal:

```bash
curl http://localhost:8080/
# Hola desde un unikernel Unikraft (Go)!
```

**Qué observar:**
- El rootfs se construyó desde tu `Dockerfile` (aquí interviene BuildKit/Docker del módulo 2).
- La app corre **sin un SO Linux completo debajo**: solo el library OS de Unikraft + tu binario.

**Para profundizar:** prueba a fijar el *target* de plataforma/arquitectura (`--target qemu/x86_64`) y a ajustar memoria (`-M 64M`) para ver cuán poca RAM necesita.

---

## Lab 3 — App Python/Flask como unikernel (Unikraft)

**Objetivo:** empaquetar una app con *runtime* interpretado (más dependencias que un binario Go estático).

```bash
mkdir -p ~/labs/py-flask && cd ~/labs/py-flask
```

`app.py`:

```python
from flask import Flask
app = Flask(__name__)

@app.route("/")
def home():
    return "Hola desde un unikernel (Python/Flask)!\n"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

`requirements.txt`:

```
flask==3.0.3
```

`Dockerfile` (rootfs con Python + dependencias):

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
```

`Kraftfile`:

```yaml
spec: v0.6

runtime: python3:latest      # runtime Python del catálogo Unikraft
rootfs: ./Dockerfile
cmd: ["/app/app.py"]
```

Ejecutar:

```bash
kraft run --rm -p 8080:8080 .
curl http://localhost:8080/
```

> **Nota de compatibilidad:** las apps interpretadas arrastran más superficie POSIX. Si algo no funciona, es un excelente ejercicio de diagnóstico: observa qué *syscall* o fichero reclama la app. Es exactamente el tipo de fricción del que habla el módulo 3 (§3.7).

**Alternativa con Nanos/Ops** (mismo objetivo, otra herramienta):

```bash
# Ops trae paquetes de runtimes; por ejemplo Python
ops pkg list | grep -i python
# ops run/load con un config.json que incluya app.py y dependencias
```

---

## Lab 4 — Migrar un contenedor Docker a unikernel ⭐ (el caso central del curso)

**Objetivo:** tomar una aplicación que hoy corre en un contenedor y **ejecutarla como unikernel**, con una metodología repetible y verificación.

### Metodología de migración (7 pasos)

```
1. INVENTARIO      → ¿Un solo proceso? ¿fork/exec? ¿shell? ¿multiproceso?
2. ARTEFACTO       → Obtener el binario/app y sus dependencias (idealmente estático)
3. CONFIG          → Puertos, variables de entorno, ficheros, volúmenes
4. EMPAQUETADO     → Construir la imagen unikernel (ops o kraft)
5. EJECUCIÓN       → Arrancar y comprobar red/logs
6. VERIFICACIÓN    → Pruebas funcionales + comparar con el contenedor
7. DECISIÓN        → ¿Compatible y con ventaja? Si no, documentar el bloqueo
```

### Ejemplo A — Migrar un binario Go (contenedor `scratch` → unikernel Nanos)

Punto de partida: un contenedor que ejecuta un binario Go estático (`server`).

```bash
mkdir -p ~/labs/migracion-go && cd ~/labs/migracion-go
# Reutiliza el binario del Lab 2 o compílalo:
cat > main.go <<'EOF'
package main
import ("fmt"; "net/http")
func main() {
  http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request){
    fmt.Fprintln(w, "Migrado a unikernel Nanos!")
  })
  http.ListenAndServe(":8080", nil)
}
EOF
CGO_ENABLED=0 GOOS=linux go build -o server main.go
```

Manifiesto `config.json` para Ops:

```json
{
  "RunConfig": { "Ports": ["8080"], "Memory": "128m" }
}
```

Ejecutar como unikernel:

```bash
ops run server -c config.json
# En otra terminal:
curl http://localhost:8080/
# Migrado a unikernel Nanos!
```

Empaquetar una imagen reutilizable (para desplegarla en una nube soportada):

```bash
ops image create server -c config.json -i mi-servicio
ops image list
```

### Ejemplo B — Migrar una app interpretada (Node.js)

```bash
mkdir -p ~/labs/migracion-node && cd ~/labs/migracion-node
cat > server.js <<'EOF'
const http = require('http');
http.createServer((req,res)=>{ res.end("Node en unikernel!\n"); })
    .listen(8080, "0.0.0.0");
EOF
```

`config.json`:

```json
{
  "Args": ["server.js"],
  "Files": ["server.js"],
  "RunConfig": { "Ports": ["8080"], "Memory": "256m" }
}
```

```bash
# Cargar un paquete de Node y ejecutar tu script
ops pkg load eyberg/node:20.5.0 -c config.json
curl http://localhost:8080/
```

### Checklist de compatibilidad (rellénalo al migrar)

| Comprobación | ¿OK? | Notas |
|--------------|------|-------|
| ¿La app es de **un solo proceso**? | ☐ | Si hace `fork`/workers → replantear |
| ¿Evita `exec` de binarios externos (shell, subprocesos)? | ☐ | |
| ¿Estado en volúmenes/servicios externos (no en la imagen)? | ☐ | |
| ¿Config por **variables de entorno**? | ☐ | |
| ¿Arranca y responde en el puerto esperado? | ☐ | |
| ¿Pasan las pruebas funcionales? | ☐ | |
| ¿Ventaja medible (tamaño/arranque/memoria)? | ☐ | Ver Lab 7 |

> **Cuándo abortar la migración:** si la app necesita múltiples procesos, un shell, o syscalls no soportadas que no puedes rodear, **documenta el bloqueo** y considera una **microVM (Kata/Firecracker)** como alternativa de aislamiento (módulo 5), que no exige rediseñar la app.

---

## Lab 5 — Volúmenes persistentes con Nanos (estado que sobrevive al reinicio)

**Objetivo:** ver cómo se maneja el **estado persistente** (la imagen es inmutable; el estado va aparte).

```bash
# 1. Crear un volumen persistente de 1 GB
ops volume create datos -s 1g
ops volume list

# 2. Montar el volumen en /data al ejecutar la app
#    (config.json)
cat > config.json <<'EOF'
{
  "RunConfig": { "Ports": ["8080"], "Memory": "256m" },
  "Mounts": { "datos": "/data" }
}
EOF

# 3. Ejecutar la app con el volumen montado
ops run server -c config.json --mounts datos:/data
```

**Qué observar:** lo que la app escriba en `/data` persiste entre reinicios del unikernel, mientras que el resto de la imagen es inmutable. Es el patrón correcto para cargas con estado.

**Para profundizar:** compara este modelo con los `PersistentVolume`/`PVC` de Kubernetes. La idea es la misma (separar cómputo inmutable de datos persistentes), la implementación es de VM.

---

## Lab 6 — Unikernel sobre Firecracker y prueba de densidad (avanzado)

**Objetivo:** ejecutar un unikernel sobre el VMM minimalista **Firecracker** y apreciar por qué habilita densidad y arranque extremos.

### 6.1. Con `kraft` apuntando a Firecracker

KraftKit soporta Firecracker como plataforma (`fc`). El flujo general:

```bash
cd ~/labs/go-http     # reutiliza el Lab 2
# Construir para el target Firecracker
kraft build --target fc/x86_64 .
# Ejecutar sobre Firecracker (requiere firecracker en PATH y /dev/kvm)
kraft run --plat fc --arch x86_64 -p 8080:8080 .
```

> Los nombres exactos de *target*/flags pueden variar entre versiones de KraftKit. Comprueba `kraft build --help` y `kraft run --help`. La doc de KraftKit indica soporte de **Firecracker >= 1.4.1**.

### 6.2. Prueba de densidad (concepto)

El argumento de "miles de VMs por host" (LightVM/Unikraft, SOSP 2017) se aprecia lanzando muchas instancias mínimas y midiendo memoria agregada y tiempo de arranque. Script ilustrativo (ajústalo a tu tooling):

```bash
# Lanza N unikernels en segundo plano y mide tiempos de arranque
N=20
for i in $(seq 1 $N); do
  ( time kraft run --rm -M 32M unikraft.org/helloworld:latest ) 2>> tiempos.txt &
done
wait
grep real tiempos.txt | sort | tail
```

**Qué observar:** el arranque por instancia en el rango de milisegundos y el consumo de RAM por VM en pocos MB. Extrapola: en un host con cientos de GB de RAM, la densidad teórica es de **miles** de unikernels. Es el fundamento de FaaS/serverless de arranque rápido.

---

## Lab 7 — Benchmark: contenedor vs unikernel ⭐

**Objetivo:** medir con datos (no impresiones) las tres métricas donde el unikernel presume de ventaja: **tamaño de imagen, tiempo de arranque y memoria**.

### 7.1. Preparar las dos versiones del mismo servicio Go

**Versión contenedor:**

```bash
cd ~/labs/go-http
cat > Dockerfile.container <<'EOF'
FROM golang:1.22 AS build
WORKDIR /src
COPY main.go .
RUN CGO_ENABLED=0 go build -o /server main.go
FROM scratch
COPY --from=build /server /server
ENTRYPOINT ["/server"]
EOF
docker build -f Dockerfile.container -t bench-container .
```

**Versión unikernel:** la del Lab 2 (`kraft`).

### 7.2. Medir TAMAÑO

```bash
# Contenedor
docker images bench-container --format '{{.Size}}'

# Unikernel: localiza el artefacto construido por kraft y mide su tamaño
#   (kraft deja la imagen en el directorio de build del proyecto)
find . -name '*.kernel' -o -name 'kernel' 2>/dev/null | xargs ls -lh 2>/dev/null
```

### 7.3. Medir ARRANQUE (cold start)

```bash
# Contenedor: tiempo hasta que responde el puerto
time (docker run -d --name b1 -p 8081:8080 bench-container >/dev/null; \
      until curl -s localhost:8081 >/dev/null; do :; done)
docker rm -f b1

# Unikernel: tiempo hasta que responde
time (kraft run --rm -p 8082:8080 . & \
      until curl -s localhost:8082 >/dev/null; do :; done)
```

### 7.4. Medir MEMORIA

```bash
# Contenedor
docker stats --no-stream bench-container

# Unikernel: observa el consumo real de la VM (proceso QEMU/firecracker asociado)
ps -o rss= -C qemu-system-x86_64 | awk '{s+=$1} END{print s/1024 " MB"}'
```

### 7.5. Tabla de resultados (plantilla)

| Métrica | Contenedor | Unikernel | Δ |
|---------|-----------|-----------|---|
| Tamaño de imagen | ___ MB | ___ MB | |
| Cold start (ms) | ___ | ___ | |
| RAM en reposo | ___ MB | ___ MB | |
| RPS (opcional, `wrk`/`ab`) | ___ | ___ | |

> **Interpretación honesta:** con un binario Go sobre `scratch`, el contenedor ya es pequeño; la mayor diferencia la verás en **modelo de aislamiento** y **superficie de ataque**, no siempre en tamaño bruto. Con runtimes interpretados (Python/Node) o comparando contra imágenes base "gordas", las diferencias de tamaño/arranque se amplían. Mide **tu** caso.

**Herramientas de carga recomendadas:** `wrk`, `ab` (apache2-utils), `hey`.

---

## Lab 8 — (Bonus) Unikernel *clean-slate* con MirageOS (avanzado)

**Objetivo:** experimentar el enfoque *clean-slate* (reescribir en un lenguaje seguro) frente al de compatibilidad.

```bash
# Requiere MirageOS instalado (módulo 2, §2.5)
eval "$(opam env)"
mkdir -p ~/labs/mirage-hello && cd ~/labs/mirage-hello

# Esqueleto de un unikernel "hello world" de MirageOS
#   (sigue la guía oficial: define unikernel.ml y config.ml)
```

`config.ml` (ejemplo mínimo, orientativo — sigue la guía oficial para la API vigente):

```ocaml
open Mirage

let main = main "Unikernel.Hello" (job)
let () = register "hello" [ main ]
```

`unikernel.ml`:

```ocaml
open Lwt.Infix

module Hello (T : Mirage_time.S) = struct
  let start _time =
    let rec loop n =
      if n = 0 then Lwt.return_unit
      else (Logs.info (fun f -> f "hola mundo %d" n);
            OS.Time.sleep_ns (Duration.of_sec 1) >>= fun () -> loop (n-1))
    in loop 4
end
```

Configurar, construir y ejecutar para el target `hvt` (Solo5 sobre KVM):

```bash
mirage configure -t hvt
make depend
make
# Ejecuta el unikernel con el tender de Solo5
solo5-hvt ./dist/hello.hvt     # el nombre del artefacto puede variar
```

**Qué observar:**
- Imagen **diminuta** y seguridad de tipos/memoria de OCaml de extremo a extremo.
- El *coste*: solo ejecutas código OCaml. No hay migración de binarios existentes; es reescritura.

> Como la API de MirageOS evoluciona entre versiones mayores, **sigue el tutorial oficial "Hello World"** para el código exacto: https://mirage.io/docs/hello-world

---

## Cierre del módulo: qué te llevas

- Sabes arrancar unikernels precompilados y **construir los tuyos** con `kraft` (Kraftfile + Dockerfile) y `ops` (config.json).
- Tienes una **metodología de migración** contenedor→unikernel con checklist de compatibilidad y criterio para abortar.
- Sabes gestionar **estado persistente** (volúmenes) y ejecutar sobre **Firecracker**.
- Puedes **medir** la ventaja real (tamaño/arranque/memoria) en tu caso, sin fiarte del marketing.
- Has probado el contraste **compat (Unikraft/Nanos) vs clean-slate (MirageOS)**.

**Siguiente paso:** llevarlo a producción y comparar con alternativas → [`05-produccion-orquestacion-y-alternativas.md`](05-produccion-orquestacion-y-alternativas.md)

---

### Referencias del módulo

- Catálogo de ejemplos Unikraft — https://github.com/unikraft/catalog
- Guía "Building an app" con kraft — https://unikraft.org/docs/getting-started
- Configuración de Ops (config.json, volúmenes) — https://docs.ops.city/ops/configuration
- Ops — volúmenes persistentes — https://docs.ops.city/ops/volumes
- KraftKit y Firecracker — https://github.com/unikraft/kraftkit
- MirageOS Hello World — https://mirage.io/docs/hello-world
- Herramienta de carga `wrk` — https://github.com/wg/wrk
