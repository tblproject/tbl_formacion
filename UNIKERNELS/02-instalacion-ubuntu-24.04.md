# Módulo 2 — Instalación del stack de unikernels sobre Ubuntu Server 24.04 LTS

> **Objetivos del módulo**
> - Preparar Ubuntu Server 24.04 LTS como *host* de unikernels.
> - Verificar y habilitar la **virtualización KVM** (requisito común).
> - Instalar y comprobar **Unikraft (`kraft`)** y **NanoVMs (`ops`)**, las dos herramientas principales del curso.
> - Instalar (opcional) **MirageOS**, **Firecracker** y **OSv** para los módulos avanzados.
>
> **Nota metodológica:** los comandos se han contrastado con la documentación oficial (sept. 2026). El *tooling* cambia rápido: si algún flujo difiere, la fuente de verdad es la doc oficial enlazada al final. Los scripts `curl ... | sh` se ofrecen porque son los recomendados oficialmente, pero **revísalos antes de ejecutarlos** en entornos sensibles.

---

## 2.0. Convenciones

- Todos los comandos asumen un usuario **con privilegios `sudo`** sobre **Ubuntu Server 24.04 LTS** (nombre en clave *Noble Numbat*).
- Se asume arquitectura **x86_64 (amd64)**. La mayoría del tooling soporta también **ARM64**; se indican salvedades donde aplica.
- `$` = comando de usuario normal; se usa `sudo` explícitamente cuando hace falta.

Comprueba tu versión:

```bash
lsb_release -a
# Description:  Ubuntu 24.04.x LTS
uname -r        # kernel del host
```

---

## 2.1. Requisito imprescindible: virtualización KVM

Los unikernels **arrancan como máquinas virtuales**. Necesitas **KVM** habilitado (virtualización por hardware: Intel VT-x o AMD-V). Esto implica CPU con soporte + BIOS/UEFI con virtualización activada. En una VM anidada (nested), hay que habilitar *nested virtualization* en el hipervisor externo.

### Paso 1 — ¿Soporta la CPU virtualización?

```bash
# Debe devolver un número > 0
egrep -c '(vmx|svm)' /proc/cpuinfo
```

- `vmx` → Intel VT-x
- `svm` → AMD-V
- Si devuelve `0`: o la CPU no lo soporta, o está **desactivado en la BIOS/UEFI**, o estás en una VM sin *nested virtualization*.

### Paso 2 — Instalar la utilidad de comprobación

```bash
sudo apt-get update
sudo apt-get install -y cpu-checker
sudo kvm-ok
```

Salida esperada:

```
INFO: /dev/kvm exists
KVM acceleration can be used
```

Si dice *"KVM acceleration can NOT be used"*, revisa BIOS/UEFI o la configuración de virtualización anidada.

### Paso 3 — Instalar QEMU/KVM y utilidades

```bash
sudo apt-get install -y qemu-kvm qemu-utils bridge-utils
```

> En Ubuntu 24.04 el binario puede llamarse `qemu-system-x86_64`. Verifica:
> ```bash
> qemu-system-x86_64 --version    # requerido >= 2.5; ideal una versión reciente (8.x/9.x)
> ```

### Paso 4 — Permisos sobre `/dev/kvm`

Para no necesitar `root` al lanzar VMs, añade tu usuario a los grupos `kvm` y (si usarás libvirt) `libvirt`:

```bash
sudo usermod -aG kvm "$USER"
# Cierra sesión y vuelve a entrar (o usa 'newgrp kvm') para aplicar el grupo
ls -l /dev/kvm      # debería pertenecer al grupo kvm
```

### (Opcional) libvirt para gestión de VMs

Útil si quieres gestionar las VMs de forma clásica (redes, *pools* de almacenamiento):

```bash
sudo apt-get install -y libvirt-daemon-system libvirt-clients virtinst
sudo usermod -aG libvirt "$USER"
sudo systemctl enable --now libvirtd
virsh list --all
```

---

## 2.2. Docker/BuildKit (dependencia práctica de `kraft`)

`kraft` puede construir el **sistema de ficheros raíz (rootfs)** de tu unikernel a partir de un **`Dockerfile`**, y para ello se apoya en **BuildKit** (habitualmente provisto por Docker). Instalar Docker Engine facilita mucho el flujo del módulo 4.

```bash
# Docker Engine (repositorio oficial) en Ubuntu 24.04
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

sudo usermod -aG docker "$USER"   # re-loguéate para aplicar
docker run --rm hello-world       # verificación
```

> **Alternativa sin Docker:** si no quieres Docker, puedes ejecutar un `buildkitd` independiente y apuntar `kraft` a él con la variable `KRAFTKIT_BUILDKIT_HOST`. Para los primeros laboratorios, sin embargo, Docker es el camino más sencillo. También puedes construir rootfs por otros medios y referenciarlos, pero queda fuera del alcance de este módulo.

---

## 2.3. Instalar Unikraft (`kraft` / KraftKit) — herramienta principal

Hay dos vías oficiales.

### Vía A — Script de instalación (rápida)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get.kraftkit.sh | sh
```

El script detecta el sistema y guía la instalación (incluida la actualización automática).

### Vía B — Repositorio APT (recomendada para servidores)

```bash
# Prerrequisitos
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Clave GPG del repositorio
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.pkg.kraftkit.sh/gpg.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/unikraft.gpg

# Definición del repositorio
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/unikraft.gpg] https://deb.pkg.kraftkit.sh /" | \
  sudo tee /etc/apt/sources.list.d/unikraft.list > /dev/null

# Instalación
sudo apt-get update
sudo apt-get install -y kraftkit
```

### Verificación

```bash
kraft version
```

### Prueba de humo (imagen precompilada del catálogo)

```bash
# Ejecuta un "hello world" desde el catálogo oficial de Unikraft
kraft run unikraft.org/helloworld:latest
```

Si KVM está bien configurado, verás el arranque del unikernel en la consola en cuestión de milisegundos. Para salir de la consola de QEMU: `Ctrl+A` y luego `x` (o `Ctrl+A`, `c` para el monitor de QEMU).

> **Plataformas soportadas por KraftKit** (según su documentación): **QEMU** (probado en 4.2.0–9.2.1), **Firecracker** (>= 1.4.1) y **Xen** (<= 4.19), sobre Linux/macOS/Windows en x86_64 y ARM64.

---

## 2.4. Instalar NanoVMs (`ops`) — segunda herramienta principal

`ops` es el CLI de NanoVMs para construir y ejecutar unikernels **Nanos** (ejecutan binarios Linux de un solo proceso).

### Prerrequisitos (si no lo hiciste en 2.1)

```bash
sudo apt-get install -y qemu-kvm qemu-utils
qemu-system-x86_64 --version   # requerido >= 2.5
```

### Instalación

```bash
curl https://ops.city/get.sh -sSfL | sh
```

Tras instalar, recarga el `PATH` (o abre una nueva sesión):

```bash
source ~/.bash_profile 2>/dev/null || source ~/.bashrc
ops version
```

### Prueba de humo (Node.js sin instalarlo en el host)

```bash
# Descarga un paquete Node preconstruido y lo ejecuta como unikernel,
# publicando el puerto 8083 con reenvío de puertos
ops pkg load eyberg/node:20.5.0 -p 8083 -f -n -a hi.js -m 256
```

Necesitarás un `hi.js` mínimo en el directorio actual, por ejemplo:

```javascript
// hi.js
var http = require('http');
http.createServer(function (req, res) {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hola desde un unikernel Nanos!\n');
}).listen(8083, "0.0.0.0");
console.log('Servidor escuchando en :8083');
```

En otra terminal:

```bash
curl http://localhost:8083
```

> Significado de los flags: `-p 8083` publica el puerto; `-f` (force download) fuerza descarga del paquete; `-n` (nightly) usa el kernel más reciente; `-a hi.js` pasa el argumento (el script); `-m 256` asigna 256 MB de RAM. Consulta `ops run --help` y `ops pkg --help` para el conjunto completo.

---

## 2.5. (Opcional) MirageOS — ejemplo *clean-slate* en OCaml

Solo necesario para el laboratorio de unikernel *clean-slate* del módulo 4. Requiere el gestor de paquetes de OCaml, **opam**.

```bash
sudo apt-get update
sudo apt-get install -y opam
opam init            # responde 'y' para configurar el entorno del shell
eval "$(opam env)"

# (Opcional) fijar/verificar una versión de compilador OCaml compatible
opam switch list
# opam switch create 5.1.1   # si necesitas una versión concreta
# eval "$(opam env)"

opam install -y mirage
mirage --version
```

**Backends de despliegue** (elegibles al configurar el proyecto con `mirage configure -t <target>`):

- `unix` / `macosx` → binario UNIX normal (ideal para desarrollo).
- `hvt` (Solo5) → aislamiento por hardware sobre KVM (**el objetivo "unikernel sobre hipervisor"**).
- `spt` (Solo5) → aislamiento por `seccomp` en Linux (x86_64/aarch64).
- `virtio` (Solo5) → compatible con hipervisores que exponen virtio.
- `xen` / `qubes` → Xen / Qubes OS.

Para el *target* `hvt` necesitarás el *tender* de **Solo5**, que `opam` gestiona como dependencia (`solo5`). Detalles en el módulo 4.

---

## 2.6. (Opcional) Firecracker — microVM para labs avanzados

Firecracker es el VMM minimalista de AWS; lo usaremos para ejecutar unikernels como microVMs y medir densidad/arranque.

```bash
# Descarga el release oficial (ajusta la versión a la última estable)
ARCH="$(uname -m)"
VERSION="v1.7.0"   # comprueba la última en el repositorio oficial
curl -Lo firecracker.tgz \
  "https://github.com/firecracker-microvm/firecracker/releases/download/${VERSION}/firecracker-${VERSION}-${ARCH}.tgz"
tar -xzf firecracker.tgz
sudo install "release-${VERSION}-${ARCH}/firecracker-${VERSION}-${ARCH}" /usr/local/bin/firecracker
firecracker --version
```

Requisito: acceso a `/dev/kvm` (grupo `kvm`, ver 2.1). Firecracker no usa QEMU; habla directamente con KVM.

> **Alternativa:** **Cloud Hypervisor** (proyecto de la Linux Foundation) ofrece objetivos similares con más funcionalidades de dispositivo. `kraft` y `OSv` soportan varios de estos VMMs; elige según necesites densidad extrema (Firecracker) o más funciones (Cloud Hypervisor/QEMU).

---

## 2.7. (Opcional) OSv con Capstan — referencia POSIX

OSv permite empaquetar aplicaciones sobre un kernel precompilado con **Capstan**. Requiere Docker o las dependencias de compilación. Vía Capstan (usa kernels precompilados):

```bash
# Capstan (comprueba la URL/última versión en el repositorio de OSv)
curl https://raw.githubusercontent.com/cloudius-systems/capstan/master/scripts/download | bash
export PATH="$HOME/bin:$PATH"
capstan --version
```

> **Estado del proyecto:** OSv es mantenido por la comunidad; su último *release* etiquetado es **v0.57.0 (dic. 2022)**, con desarrollo continuo en `master` y *builds* nocturnos. Soporta QEMU/KVM, Firecracker, Cloud Hypervisor, Xen, VMware, VirtualBox y varias nubes. Lo usaremos como **referencia**, no como herramienta principal.

---

## 2.8. Comprobación final del entorno

Ejecuta esta lista de verificación antes de pasar a los laboratorios:

```bash
# 1. Virtualización
sudo kvm-ok                       # "KVM acceleration can be used"
ls -l /dev/kvm                    # existe y perteneces al grupo kvm

# 2. QEMU
qemu-system-x86_64 --version

# 3. Docker/BuildKit (para rootfs de kraft)
docker run --rm hello-world

# 4. Unikraft
kraft version
kraft run unikraft.org/helloworld:latest   # arranca y muestra "hello world"

# 5. NanoVMs
ops version

# 6. (Opcional) MirageOS / Firecracker / Capstan
mirage --version     2>/dev/null || echo "MirageOS no instalado (opcional)"
firecracker --version 2>/dev/null || echo "Firecracker no instalado (opcional)"
capstan --version     2>/dev/null || echo "Capstan no instalado (opcional)"
```

### Tabla de "sanity check"

| Componente | Comando | Resultado esperado |
|------------|---------|--------------------|
| KVM | `sudo kvm-ok` | *KVM acceleration can be used* |
| `/dev/kvm` | `ls -l /dev/kvm` | Existe; grupo `kvm` |
| QEMU | `qemu-system-x86_64 --version` | Versión >= 2.5 (ideal 8.x/9.x) |
| Docker | `docker run --rm hello-world` | Mensaje de bienvenida |
| Unikraft | `kraft run unikraft.org/helloworld:latest` | Arranque y "hello world" |
| NanoVMs | `ops version` | Muestra versión |

---

## 2.9. Problemas frecuentes (troubleshooting)

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `KVM acceleration can NOT be used` | Virtualización desactivada en BIOS/UEFI o VM sin *nested* | Activar VT-x/AMD-V en firmware; habilitar *nested virtualization* |
| `Permission denied` sobre `/dev/kvm` | Usuario fuera del grupo `kvm` | `sudo usermod -aG kvm $USER` y re-login |
| `kraft` falla al construir rootfs | BuildKit/Docker no disponible | Instalar Docker (2.2) o configurar `KRAFTKIT_BUILDKIT_HOST` |
| `ops`: comando no encontrado tras instalar | `PATH` no recargado | `source ~/.bash_profile` o nueva sesión |
| La VM arranca pero no hay red | Reenvío de puertos/red mal configurado | Revisar flags de red (`-p`) o configurar bridge/tap (módulo 3) |
| Arranque muy lento | KVM no activo, usando emulación pura | Confirmar `-enable-kvm` / que QEMU usa KVM |
| `qemu-system-x86_64: not found` | Paquete no instalado o binario con otro nombre | `sudo apt-get install qemu-kvm qemu-system-x86` |

---

## 2.10. Resumen del módulo

- Todo unikernel necesita **KVM**: verifícalo (`kvm-ok`), instala **qemu-kvm** y da permisos sobre `/dev/kvm`.
- Instala **`kraft`** (Unikraft) por **APT** en servidores, y **`ops`** (NanoVMs) con su script. Son las **dos herramientas principales** del curso.
- **Docker/BuildKit** facilita construir el rootfs con `kraft`.
- Opcionalmente, prepara **MirageOS** (clean-slate), **Firecracker** (microVM) y **OSv/Capstan** (referencia) para los módulos avanzados.
- Cierra el módulo con la **checklist de verificación**: si `kraft run ...helloworld` arranca, tu laboratorio está listo.

**Siguiente paso:** entender qué hay dentro → [`03-componentes-y-funcionalidades.md`](03-componentes-y-funcionalidades.md)

---

### Referencias del módulo

- Instalación de KraftKit — https://unikraft.org/docs/cli/install
- KraftKit (repositorio y quickstart) — https://github.com/unikraft/kraftkit
- Catálogo de aplicaciones Unikraft — https://github.com/unikraft/catalog
- Getting started de Ops (NanoVMs) — https://docs.ops.city/ops/getting_started
- Instalación de MirageOS — https://mirage.io/docs/install
- Firecracker (releases y getting started) — https://github.com/firecracker-microvm/firecracker
- OSv (build/run y Capstan) — https://github.com/cloudius-systems/osv
- KVM en Ubuntu — https://ubuntu.com/blog/kvm-hypervisor
