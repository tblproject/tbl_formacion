# Módulo 3 — Componentes y funcionalidades de un unikernel (en detalle)

> **Objetivos del módulo**
> - Diseccionar la **anatomía interna** de un unikernel, capa por capa.
> - Entender el papel del **hipervisor/VMM** y de **virtio**.
> - Detallar **memoria, planificación, red, almacenamiento, arranque, seguridad y observabilidad**.
> - Ver cómo Unikraft y Nanos materializan cada componente (con ejemplos de configuración).
>
> Este módulo es teórico-técnico. Puedes leerlo en paralelo a los laboratorios del módulo 4 para ver cada pieza "en vivo".

---

## 3.1. Anatomía general: las capas de un unikernel

Un unikernel apila (de abajo arriba) estas capas, **todas dentro de una sola imagen y un solo espacio de direcciones**:

```
┌───────────────────────────────────────────────────────────┐
│                     APLICACIÓN (tu código)                  │
│   Go / Python / Node / Java / C / Rust / OCaml ...          │
├───────────────────────────────────────────────────────────┤
│   Capa de compatibilidad (opcional): libc (musl/newlib),    │
│   shim POSIX, cargador de ELF (app-elfloader)               │
├───────────────────────────────────────────────────────────┤
│   Servicios del LIBRARY OS (solo los que la app usa):       │
│   · Pila de red (lwIP / propia)                             │
│   · Sistema de ficheros (ramfs / 9pfs / initrd / bloque)    │
│   · Planificador e hilos                                    │
│   · Gestor de memoria (asignador, heap)                     │
│   · Temporizadores, entropía, consola                       │
├───────────────────────────────────────────────────────────┤
│   Drivers de dispositivo (virtio-net, virtio-blk, consola)  │
├───────────────────────────────────────────────────────────┤
│   Código de arranque + capa de plataforma                   │
│   (KVM/QEMU · Firecracker · Xen · bare metal)               │
└───────────────────────────────────────────────────────────┘
                          ▼  (interfaz mínima)
┌───────────────────────────────────────────────────────────┐
│              HIPERVISOR / VMM  (KVM+QEMU, Firecracker...)    │
├───────────────────────────────────────────────────────────┤
│                          HARDWARE                           │
└───────────────────────────────────────────────────────────┘
```

La diferencia radical con un SO tradicional: **no hay frontera usuario/kernel**. Lo que en Linux sería una `syscall` (con su trampa al kernel y cambio de anillo de privilegio) aquí es una **llamada a función** dentro del mismo binario. Eso elimina un coste importante y explica parte de la ventaja de rendimiento y de arranque.

---

## 3.2. El hipervisor / VMM: dónde vive el unikernel

El unikernel **no corre sobre Linux**: corre sobre un **hipervisor**. Tres opciones típicas:

| VMM | Qué es | Fortalezas | Cuándo usarlo |
|-----|--------|-----------|---------------|
| **QEMU + KVM** | Emulador completo + aceleración por hardware (KVM) | Máxima compatibilidad de dispositivos; el más flexible | Desarrollo, pruebas, casos generales |
| **Firecracker** | VMM minimalista (AWS) escrito en Rust | Arranque en ms, huella diminuta, superficie de ataque VMM mínima | Serverless, densidad extrema, multi-tenant |
| **Cloud Hypervisor** | VMM moderno (Linux Foundation) en Rust | Más dispositivos que Firecracker, hotplug | Cargas que necesitan más funciones que Firecracker |
| **Xen** | Hipervisor tipo 1 | Aislamiento fuerte, historia en cloud | Entornos Xen existentes, ciertos casos de seguridad |

**Concepto clave — el VMM también es superficie de ataque.** Firecracker se diseñó precisamente para *minimizar* el código del VMM (frente a QEMU, que es enorme). Combinar **unikernel mínimo + VMM mínimo** (p. ej., Unikraft sobre Firecracker) es la configuración de menor superficie de ataque de extremo a extremo.

### virtio: el lenguaje común unikernel↔hipervisor

Los unikernels hablan con el mundo exterior mediante **dispositivos paravirtualizados virtio**, un estándar que evita emular hardware real (lento) y ofrece drivers eficientes:

- **virtio-net** → tarjeta de red.
- **virtio-blk** → dispositivo de bloque (disco).
- **virtio-console / serial** → consola (logs, stdout).
- **virtio-rng** → entropía.
- **virtio-fs / 9pfs** → compartición de ficheros con el host.

Que un unikernel solo incluya los **drivers virtio que necesita** es una de las razones de su tamaño mínimo.

---

## 3.3. Gestión de memoria

Características del modelo de memoria de un unikernel:

- **Espacio de direcciones único.** No hay separación por procesos ni, en muchos casos, la complejidad completa de memoria virtual multiproceso. Algunos unikernels usan paginación (para protección de páginas, W^X, guard pages), pero **no hay conmutación entre espacios de usuario/kernel**.
- **Sin ambiente multiusuario.** No hay `setuid`, ni permisos de usuario, ni aislamiento entre procesos *dentro* de la imagen: el aislamiento lo da el hipervisor **hacia afuera**.
- **Asignadores especializados.** Unikraft, por ejemplo, permite elegir el **asignador de memoria** (`ukalloc` con back-ends como *buddy allocator*, *region/bump allocator*, etc.), optimizando según la carga.
- **Huella mínima configurable.** Reservas de RAM de pocos MB son habituales; se ajustan al arrancar la VM (`-m` en QEMU/ops).

**Implicación de seguridad (para nivel avanzado):** al no existir separación usuario/kernel, un desbordamiento explotable en la app **no necesita escalar privilegios**: ya está en el nivel máximo *de esa VM*. Mitigaciones: (1) lenguajes con seguridad de memoria (OCaml, Rust) en enfoques clean-slate; (2) ASLR y W^X donde el unikernel lo soporte; (3) confiar el radio de impacto al **aislamiento del hipervisor**. Es un *trade-off* consciente, no un descuido.

---

## 3.4. Planificación y concurrencia (hilos, no procesos)

- **Un proceso, múltiples hilos.** La mayoría de unikernels ejecutan **un único "proceso"** pero soportan **hilos** dentro de él. **No hay `fork()`** clásico (o es muy limitado): esto rompe aplicaciones que dependen de crear procesos hijos (por ejemplo, servidores que hacen `fork` por conexión, o supervisores tipo `gunicorn --workers`).
- **Planificadores intercambiables.** Unikraft ofrece `uksched` con planificadores cooperativos o preemptivos; MirageOS usa el modelo de concurrencia de OCaml (Lwt/efectos); Nanos gestiona hilos de un proceso Linux.
- **Consecuencia de diseño para migrar:** si tu servicio escala con *procesos worker*, la vía natural en unikernels es **escalar con más instancias/VM** (horizontal), no con más procesos dentro de la imagen. Encaja bien con el modelo "una microVM por unidad de trabajo".

---

## 3.5. Pila de red

- **Pilas TCP/IP embebidas.** Unikraft integra **lwIP** (ligera y probada); MirageOS trae su **pila TCP/IP propia en OCaml** (`mirage-tcpip`); Nanos y OSv incluyen pilas compatibles con sockets POSIX.
- **Sin `iptables`/`netfilter` del host dentro de la imagen.** El "firewall" y la topología de red se gestionan **fuera**, en el hipervisor/host (bridges, tap, reglas), o dentro de la app.
- **Modos de red típicos:**
  - **User-mode networking (SLIRP en QEMU):** cómodo para desarrollo; reenvío de puertos (`hostfwd`). Rendimiento limitado.
  - **TAP + bridge:** interfaz `tap` conectada a un `bridge` del host; rendimiento de red real, IP propia. Lo estándar para producción/laboratorio serio.
  - **macvtap / SR-IOV:** para latencia/throughput máximos (NFV).
- **Reenvío de puertos** (lo verás en el módulo 4): con `ops`, `-p 8080`; con `kraft`, `-p 8080:8080`.

> **Rendimiento:** al eliminar copias y cambios de contexto usuario/kernel, los unikernels alcanzan cifras de red muy altas. ClickOS (NFV) demostró procesar millones de paquetes por segundo con huellas mínimas. Es una de las razones históricas de su adopción en funciones de red.

---

## 3.6. Almacenamiento y sistemas de ficheros

Los unikernels priorizan la **inmutabilidad** y el estado mínimo, pero soportan varios modelos:

- **initrd / ramfs:** sistema de ficheros en memoria, empaquetado en la imagen. Ideal para binarios, assets estáticos y configuración de solo lectura. **Efímero.**
- **9pfs / virtio-fs:** montar un directorio del **host** dentro del unikernel. Muy usado en desarrollo para no reconstruir la imagen a cada cambio.
- **Volúmenes de bloque (virtio-blk):** discos persistentes. Nanos, por ejemplo, permite crear y adjuntar **volúmenes raw persistentes** (`ops volume`). OSv soporta **ZFS/ROFS/RAMFS**.
- **rootfs desde `Dockerfile` (Unikraft):** `kraft` puede construir el rootfs a partir de un `Dockerfile`, reutilizando tu forma de empaquetar dependencias. Puente conceptual muy útil viniendo de contenedores.

**Patrón recomendado (12-factor-friendly):** imagen **inmutable** + estado en **volúmenes** o en servicios externos (bases de datos, colas, almacenamiento de objetos). Igual que con contenedores bien diseñados.

---

## 3.7. Capa de compatibilidad: cómo se ejecuta software "de Linux"

Aquí está la magia que hace viable **migrar contenedores**:

- **Unikraft — `app-elfloader` + `musl`/`newlib`:** Unikraft puede **cargar y ejecutar binarios ELF de Linux sin recompilarlos**, mapeando las syscalls que la app invoca a implementaciones internas (`syscall_shim`). Combinado con `musl`, cubre un amplio subconjunto de POSIX. Lo que no está implementado, falla explícitamente (útil para diagnosticar portabilidad).
- **Nanos:** diseñado desde el principio para **ejecutar binarios Linux de un solo proceso**. `ops` orquesta la construcción de la imagen a partir de tu binario + manifiesto.
- **OSv:** "**Linux binary compatible**"; ejecuta muchas aplicaciones sin cambios, con un enlazador dinámico propio.

**Límites de compatibilidad que debes conocer:**

- `fork()`/`exec()`, múltiples procesos, señales complejas, `/proc` completo, `ptrace`, ciertos `ioctl`: soporte parcial o inexistente.
- Aplicaciones que lanzan subprocesos (shells, servidores multiproceso) suelen requerir cambio de arquitectura (a modelo multihilo o multi-instancia).
- **Verificación empírica obligatoria:** portar = **probar**. No asumas compatibilidad al 100 %; el módulo 4 incluye una metodología de migración con verificación.

---

## 3.8. Sistema de construcción y configuración (build system)

Cada framework tiene su modelo; conocerlos evita frustraciones:

### Unikraft — micro-bibliotecas + KConfig + `Kraftfile`

- **Micro-bibliotecas:** Unikraft descompone el SO en libs pequeñas y opcionales: `ukboot` (arranque), `ukalloc` (memoria), `uksched` (planificador), `uknetdev` (red), `vfscore` (VFS), `posix-*` (compatibilidad), `lwip`, etc. **Solo se enlaza lo que activas.**
- **Configuración estilo Kconfig:** `kraft menuconfig` (o ficheros de config) permite activar/desactivar componentes con granularidad, igual que configurar el kernel Linux.
- **`Kraftfile` (spec v0.6):** describe cómo construir/ejecutar el unikernel de forma declarativa. Ejemplo real:

```yaml
# Kraftfile
spec: v0.6

runtime: base:latest          # runtime base de Unikraft
rootfs: ./Dockerfile          # el rootfs se construye desde un Dockerfile
cmd: ["/usr/bin/my-server"]   # binario a ejecutar dentro del unikernel
```

Y se ejecuta con:

```bash
kraft run .
```

También admite definir `targets` (plataforma + arquitectura, p. ej. `qemu/x86_64`, `fc/x86_64`), fuentes de `unikraft` y `libraries`, y `volumes`.

### Nanos — manifiesto de `ops` (`config.json`)

Nanos se configura con un JSON declarativo que `ops` traduce a la imagen:

```json
{
  "Args": ["arg1", "arg2"],
  "Env": { "NODE_ENV": "production" },
  "Files": ["hi.js"],
  "Dirs": ["static"],
  "RunConfig": { "Ports": ["8080"], "Memory": "256m" },
  "Mounts": { "myvol": "/data" }
}
```

```bash
ops run mibinario -c config.json
```

> **Comparación de filosofías:** Unikraft es **modular y afinable al extremo** (eliges cada lib; ideal para minimizar y para *clean-slate* con compatibilidad). Nanos es **"trae tu binario Linux y ejecútalo"** (menos afinado, más inmediato para migrar). Elige según el objetivo: control fino (Unikraft) vs rapidez de migración (Nanos).

---

## 3.9. Seguridad: el modelo completo

Ventajas y matices, sin marketing:

**A favor**
- **Superficie de ataque mínima:** sin shell, sin intérpretes extra, sin usuarios, sin *daemons*. Menos código = menos vulnerabilidades y menos "herramientas para el atacante" (no hay `bash`, `curl`, `cat`... que reutilizar tras un compromiso).
- **Aislamiento por hardware (hipervisor):** frontera más fuerte que namespaces; el escape exige romper el VMM/hipervisor.
- **Inmutabilidad:** imágenes de solo lectura; el estado va en volúmenes. Difícil de "persistir" un ataque dentro de la imagen.
- **Parcheo acoplado app+SO:** el "kernel" se versiona con la app; no hay deriva entre el kernel del host y la carga.

**Matices/riesgos**
- **Sin separación usuario/kernel:** un fallo de memoria explotable no necesita escalar (ver 3.3). Mitigar con lenguajes seguros y protecciones de página.
- **Madurez de las mitigaciones:** ASLR, stack canaries, W^X, KASLR-equivalentes **varían por proyecto**. Verifica qué ofrece tu unikernel.
- **Cadena de suministro:** sigues dependiendo de las libs que incluyes; auditar dependencias sigue siendo necesario.
- **Superficie del VMM:** minimízala con Firecracker/Cloud Hypervisor frente a QEMU en producción.

> **Comparativa de seguridad rápida:** *contenedor* (frontera = syscalls del kernel Linux, amplia) < *gVisor* (frontera = kernel user-space, media) < *unikernel/microVM* (frontera = hipervisor, estrecha). A cambio, unikernel paga en madurez operativa.

---

## 3.10. Arranque: por qué es tan rápido

Secuencia y razones del arranque en milisegundos:

1. El VMM crea la VM y **carga la imagen** (a menudo un único fichero; con Firecracker, kernel + rootfs mínimos).
2. **No hay BIOS/UEFI pesado ni gestor de arranque** en muchos casos: el VMM salta casi directo al punto de entrada.
3. Se **inicializan solo los dispositivos virtio necesarios** y las libs activas. No hay decenas de servicios `systemd`, ni detección de hardware, ni `udev`, ni montaje de múltiples FS.
4. Control a la app.

Cifras de referencia de la literatura: **LightVM/Unikraft** demostró arranques y paradas de VMs en **milisegundos** y densidades de **miles por host** (SOSP 2017); es el mismo principio que permite a **Firecracker** arrancar microVMs en ~125 ms para AWS Lambda. Esto habilita patrones imposibles con VMs tradicionales: *scale-to-zero* real, una VM por petición, *cold starts* aceptables.

---

## 3.11. Observabilidad, depuración y operación

El punto más **inmaduro** frente a contenedores. Herramientas disponibles:

- **Consola serie / stdout:** los logs salen por la consola virtio (QEMU la muestra en terminal; en producción se redirige a ficheros/collectors).
- **Depuración con GDB:** QEMU expone un *stub* GDB (`-s -S`); puedes conectar `gdb` al unikernel y depurar como a un kernel. Unikraft documenta este flujo (`kraft ... --dbg` / QEMU gdbstub).
- **Tracing:** Unikraft ofrece puntos de traza; OSv incluye *tracepoints*, una **API REST de gestión** y una CLI (`osv`), algo poco común y muy útil para introspección.
- **Métricas:** no hay *sidecars* (un unikernel = un proceso). Se instrumenta **dentro de la app** (exponer `/metrics` Prometheus) o se miden desde el **hipervisor/host** (uso de CPU/RAM de la VM).
- **Sin `exec` interactivo:** no puedes "entrar" a un unikernel con un shell (no hay shell). El cambio de mentalidad operativo es grande: se depura por logs, trazas, GDB y **reconstruyendo la imagen**, no "toqueteando" en caliente.

**Guía de mentalidad operativa (viniendo de contenedores):**

| Con contenedores haces... | Con unikernels haces... |
|---------------------------|--------------------------|
| `docker exec -it ... sh` | Añadir logs/trazas y reconstruir; GDB stub |
| `kubectl logs` | Redirigir consola serie a un colector |
| Sidecar de métricas | Endpoint `/metrics` en la propia app |
| Parche del kernel del host | Reconstruir la imagen (kernel va dentro) |
| Depuración con `strace` | Ver syscalls no implementadas en el shim; GDB |

---

## 3.12. Mapa de componentes por proyecto (referencia rápida)

| Componente | Unikraft | Nanos (NanoVMs) | MirageOS | OSv |
|------------|----------|-----------------|----------|-----|
| Lenguaje del core | C (modular) | C | OCaml | C++ |
| Compatibilidad Linux | Alta (`app-elfloader`) | Alta (1 proceso) | Ninguna (solo OCaml) | Alta (binaria) |
| Pila de red | lwIP | propia | `mirage-tcpip` (OCaml) | propia (POSIX) |
| FS | ramfs/9pfs/initrd/bloque | volúmenes raw, 9pfs | mirage-fs / block | ZFS/ROFS/RAMFS |
| Config | Kconfig + `Kraftfile` | `config.json` (ops) | `mirage configure` | Capstan / build |
| VMMs | QEMU, Firecracker, Xen | QEMU/KVM, Firecracker, nubes | Solo5 (hvt/spt/virtio), Xen | QEMU, Firecracker, Cloud HV, Xen... |
| Modelo de concurrencia | hilos (`uksched`) | hilos (1 proceso) | Lwt/efectos OCaml | hilos |
| Observabilidad | consola, GDB, tracing | consola, logs | consola, GDB | consola, REST API, tracepoints |

---

## 3.13. Resumen del módulo

- Un unikernel apila **app + capa de compatibilidad + servicios del library OS + drivers virtio + arranque**, todo en **un binario y un espacio de direcciones**, sobre un **hipervisor**.
- El **VMM** (QEMU, Firecracker, Cloud Hypervisor, Xen) define aislamiento y superficie de ataque; **virtio** es la interfaz con el exterior.
- Memoria (espacio único), planificación (**hilos, no procesos, sin `fork`**), red (lwIP/propia), almacenamiento (inmutable + volúmenes) y **capa de compatibilidad** (clave para migrar) son los subsistemas que hay que dominar.
- La **seguridad** es su gran fortaleza (superficie mínima + aislamiento HW), con matices (sin separación usuario/kernel).
- La **observabilidad/depuración** es su punto débil: cambia la mentalidad operativa (logs, trazas, GDB, reconstruir; nunca `exec`).

**Siguiente paso:** ponerlo todo en práctica → [`04-ejemplos-practicos.md`](04-ejemplos-practicos.md)

---

### Referencias del módulo

- Arquitectura de Unikraft (micro-libraries, Kconfig, Kraftfile) — https://unikraft.org/docs
- Especificación del `Kraftfile` — https://unikraft.org/docs/cli/reference/kraftfile
- Configuración de aplicaciones en Nanos/Ops (`config.json`) — https://docs.ops.city/ops/configuration
- Solo5 (tenders hvt/spt para MirageOS) — https://github.com/Solo5/solo5
- Firecracker design — https://github.com/firecracker-microvm/firecracker/blob/main/docs/design.md
- Agache et al., *"Firecracker: Lightweight Virtualization for Serverless Applications"*, NSDI 2020 — https://www.usenix.org/conference/nsdi20/presentation/agache
- OSv (tracepoints, REST API) — https://github.com/cloudius-systems/osv/wiki
