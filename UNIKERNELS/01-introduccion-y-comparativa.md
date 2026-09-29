# Módulo 1 — Introducción a los unikernels y comparativa con contenedores

> **Objetivos del módulo**
> - Definir con precisión qué es un unikernel y cómo se ejecuta.
> - Situar los unikernels en la historia de los sistemas operativos (library OS, exokernels).
> - Distinguir los dos grandes enfoques: *clean-slate* vs *compatibilidad POSIX/binaria*.
> - Comparar **rigurosamente** unikernels con Docker y con Kubernetes.
> - Saber **cuándo sustituir contenedores por unikernels tiene sentido y cuándo no**.

---

## 1.1. ¿Qué es un unikernel?

Un **unikernel** es una imagen de máquina **especializada, de propósito único y autocontenida**, que se obtiene compilando *una aplicación* junto con *únicamente las partes del sistema operativo que esa aplicación necesita* (drivers, pila de red, planificador, gestor de memoria...), enlazadas en un **único binario que arranca por sí mismo** sobre un hipervisor o sobre hardware.

Dicho de otro modo: en lugar de instalar una aplicación *encima* de un sistema operativo de propósito general, **fusionas la aplicación y el "trozo de SO" que le hace falta en una sola cosa**.

Las tres ideas que lo definen:

1. **Library OS (sistema operativo como biblioteca).** Las funciones que normalmente ofrece el kernel (abrir un socket, reservar memoria, planificar hilos) se ofrecen como **bibliotecas** que se enlazan con la aplicación. No hay un kernel separado ejecutándose "debajo": el SO *es* parte de tu binario.
2. **Espacio de direcciones único (single address space).** No existe la separación clásica entre *espacio de kernel* y *espacio de usuario*. Aplicación y "SO" viven en el mismo espacio de memoria y en el mismo nivel de privilegio. Consecuencia directa: **una llamada al sistema (`syscall`) se convierte en una simple llamada a función**, sin el cambio de contexto/anillo de privilegio que impone un SO tradicional.
3. **Propósito único (single purpose).** Un unikernel ejecuta **una** aplicación. No hay usuarios, ni shell, ni gestor de paquetes, ni `systemd`, ni decenas de procesos de fondo. Todo lo que no necesita tu aplicación, **no está en la imagen**.

### Analogía para fijar el concepto

- Un **contenedor** es como llevarte a un piso amueblado compartido: el edificio (el kernel Linux del host) es de todos; tú tienes tu habitación aislada (namespaces + cgroups), pero compartes cimientos, cañerías e instalación eléctrica con el resto de inquilinos.
- Un **unikernel** es como una **caravana** hecha a medida: solo tiene lo que tú usas, arranca en segundos, cabe en muy poco espacio, y va sobre su propio chasis (el hipervisor). Nadie más vive dentro. Si algo falla, no afecta a otras caravanas.

---

## 1.2. Un poco de historia (por qué esto no es nuevo)

Los unikernels beben de décadas de investigación en sistemas operativos. Conocer la genealogía ayuda a entender las decisiones de diseño:

- **1995 — Exokernels (MIT).** Engler y Kaashoek proponen un kernel que expone el hardware de forma segura y deja que cada aplicación traiga su propia *library OS*. Es la semilla intelectual del unikernel. *("Exokernel: An Operating System Architecture for Application-Level Resource Management", SOSP 1995).*
- **Años 90–2000 — Nemesis, Rump kernels.** Experimentos de SO como biblioteca y de reutilización de drivers de NetBSD como componentes (*rump kernels* → `rumprun`).
- **2013 — MirageOS y el término "unikernel".** El paper fundacional *"Unikernels: Library Operating Systems for the Cloud"* (Madhavapeddy et al., **ASPLOS 2013**) populariza el concepto y presenta MirageOS, escrito en OCaml. Es el pistoletazo de salida del movimiento moderno.
- **2013–2016 — Florecen las implementaciones.** ClickOS (NFV), OSv (compatibilidad POSIX), IncludeOS (C++), HaLVM (Haskell), runtime.js (JavaScript), Drawbridge (Microsoft Research).
- **2016 — Docker adquiere Unikernel Systems.** Señal de que la industria toma en serio el enfoque; parte de esa tecnología influye en LinuxKit.
- **2017 — "My VM is Lighter (and Safer) than your Container"** (Manco et al., **SOSP 2017**). Demuestra con LightVM/Unikraft arranques de VMs en milisegundos y densidades de miles por host, atacando el argumento de que "las VMs son pesadas".
- **2021 — "Unikraft: Fast, Specialized Unikernels the Easy Way"** (**EuroSys 2021**). Unikraft se posiciona como framework modular que hace los unikernels *usables* y compatibles con software existente.
- **2018–2026 — Consolidación y encaje con microVMs.** La aparición de **Firecracker** (AWS, 2018) y de proyectos como **Cloud Hypervisor** y **Kata Containers** normaliza la idea de "VM ligerísima como unidad de despliegue", el hábitat natural del unikernel. Surgen ofertas comerciales (NanoVMs, Unikraft Cloud) que buscan cerrar la brecha de *tooling*.

> **Lectura recomendada (gratuita):** *"Unikernels: Beyond Containers to the Next Generation of Cloud"*, Russell Pavlicek (O'Reilly). Introducción divulgativa excelente para fijar conceptos. Enlace en el apéndice.

---

## 1.3. ¿Cómo se ejecuta un unikernel? (modelo mental)

Compara los tres modelos de aislamiento y ejecución:

```
   BARE METAL / VM tradicional          CONTENEDOR (Docker)                 UNIKERNEL
 ┌──────────────────────────┐    ┌──────────────────────────┐    ┌──────────────────────────┐
 │        Aplicación        │    │  App A  │  App B  │ App C  │    │        Aplicación        │
 │  ─────────────────────   │    │ ─────── │ ─────── │ ────── │    │  ══════════════════════  │  ← un solo
 │  SO de propósito general │    │ bins/libs por contenedor │    │  Library OS (solo lo      │    binario,
 │  (systemd, shell, users, │    │ ───────────────────────  │    │   necesario: red, mem,    │    un solo
 │   miles de paquetes...)  │    │   Kernel Linux del HOST  │    │   sched, drivers virtio)  │    espacio de
 │  ─────────────────────   │    │   (COMPARTIDO por todos) │    │  ══════════════════════  │    direcciones
 │        Hardware/VM       │    │ ───────────────────────  │    ├──────────────────────────┤
 └──────────────────────────┘    │        Hardware/VM       │    │      Hipervisor (KVM)     │
                                  └──────────────────────────┘    ├──────────────────────────┤
   Aislamiento: total,            Aislamiento: a nivel SO         │        Hardware           │
   pero pesado                    (namespaces/cgroups),           └──────────────────────────┘
                                  kernel compartido = mayor         Aislamiento: por hardware
                                  superficie de ataque             (VT-x/AMD-V), imagen mínima
```

**Flujo de arranque de un unikernel** (simplificado):

1. El **hipervisor** (KVM+QEMU, Firecracker, Xen...) crea una VM y carga la imagen del unikernel.
2. El **código de arranque** del unikernel inicializa la CPU, la memoria y los **dispositivos virtio** (red, bloque, consola).
3. Se inicializan las **bibliotecas del library OS** que la aplicación requiere (por ejemplo, la pila TCP/IP).
4. Se transfiere el control a la función principal de la **aplicación**.
5. La aplicación corre en **ring 0** de la VM, en un único espacio de direcciones, sin `fork()` de procesos separados (sí suele haber **hilos**).

Como no hay que arrancar un SO completo ni decenas de servicios, **los tiempos de arranque bajan a decenas de milisegundos** (a veces menos), habilitando patrones como "arrancar una VM por petición".

---

## 1.4. Los dos grandes enfoques (esto decide tu estrategia de migración)

Cuando planteas "sustituir contenedores por unikernels", el primer cruce de caminos es **qué tipo de unikernel** usar:

### A) *Clean-slate* / específicos de lenguaje

Reescriben el SO desde cero en un lenguaje (a menudo con seguridad de memoria) y **solo ejecutan aplicaciones escritas en ese lenguaje**.

- **Ejemplos:** MirageOS (OCaml), IncludeOS (C++), HaLVM (Haskell), runtime.js (JavaScript).
- **Ventajas:** máxima especialización, imágenes diminutas, **seguridad de tipos/memoria** de extremo a extremo, superficie de ataque mínima.
- **Inconvenientes:** solo sirve si tu aplicación está (o la reescribes) en ese lenguaje. Curva de adopción alta. No es un "sustituto directo" de tus contenedores actuales.

### B) *POSIX-like* / compatibilidad binaria

Ofrecen una interfaz tipo POSIX (o directamente **ejecutan binarios Linux sin recompilar**) para que puedas llevar aplicaciones existentes con poco esfuerzo.

- **Ejemplos:** **Unikraft** (con `app-elfloader` ejecuta ELF de Linux), **Nanos/NanoVMs** (ejecuta binarios Linux, un proceso), **OSv** ("Linux binary compatible"), `rumprun`.
- **Ventajas:** **camino real de migración** desde contenedores; reutilizas tu binario/lenguaje/framework (Go, Node, Python, Java, etc.).
- **Inconvenientes:** compatibilidad no siempre del 100 % (llamadas al sistema no implementadas, `fork()` limitado o inexistente, señales, etc.); imágenes mayores que las *clean-slate*.

> **Regla práctica para migrar:** si el objetivo es *sustituir contenedores existentes*, empezarás casi siempre por el **enfoque B** (Unikraft o Nanos). El enfoque A se reserva para componentes nuevos y críticos donde la seguridad y el tamaño extremos justifican reescribir.

---

## 1.5. Comparativa detallada: Unikernel vs Contenedor (Docker)

La diferencia esencial: **un contenedor comparte el kernel del host y se aísla con `namespaces` + `cgroups`; un unikernel trae su propio "kernel mínimo" y se aísla con el hipervisor (hardware).**

| Dimensión | Contenedor Docker | Unikernel |
|-----------|-------------------|-----------|
| **Unidad de aislamiento** | Proceso(s) con `namespaces`/`cgroups` | Máquina virtual (VT-x/AMD-V) |
| **Kernel** | **Compartido** con el host | **Dedicado y mínimo**, embebido en la imagen |
| **Frontera de seguridad** | Interfaz de *syscalls* del kernel Linux (grande: cientos de syscalls) | Interfaz del hipervisor (pequeña) + virtio |
| **Superficie de ataque** | Amplia (kernel completo + herramientas de la imagen) | Muy reducida (sin shell, sin usuarios, sin paquetes extra) |
| **Tamaño de imagen** | Decenas–cientos de MB (imagen base + app) | Desde **cientos de KB a pocos MB** (*clean-slate*) o algunos MB (POSIX) |
| **Tiempo de arranque** | Milisegundos–segundos (arranca un proceso) | **Milisegundos–decenas de ms** (arranca una VM mínima) |
| **Consumo de memoria** | Bajo | Muy bajo (a menudo pocos MB) |
| **Densidad por host** | Alta | Muy alta (miles de microVMs/unikernels por host) |
| **Multiproceso** | Sí (varios procesos por contenedor) | Normalmente **un solo proceso** (sí múltiples hilos) |
| **Compatibilidad** | Total con el ecosistema Linux | Variable; excelente en Unikraft/Nanos/OSv, nula fuera del lenguaje en *clean-slate* |
| **Depuración/operación** | Madura (`docker exec`, `sh`, `strace`, `ps`...) | **Inmadura**: no hay shell; se depura por consola serie, `gdb` stub, tracing propio |
| **Madurez del ecosistema** | Enorme (registries, CI/CD, orquestadores) | Emergente; *tooling* en rápida evolución |
| **Actualización/parcheo** | Reconstruir imagen o parchear kernel del host (afecta a todos) | Reconstruir la imagen (el "kernel" se versiona **con** la app) |

### Matices que un perfil avanzado debe tener claros

- **"Menor superficie de ataque" no significa "invulnerable".** El espacio de direcciones único elimina la separación usuario/kernel: si hay un fallo de memoria explotable en la aplicación, el atacante ya está en "ring 0" de esa VM. La defensa es doble: (1) reducir drásticamente *qué* código hay dentro, y (2) apoyarse en el aislamiento del hipervisor para contener el radio de impacto. Por eso los enfoques *clean-slate* con seguridad de memoria (OCaml, Rust) son tan atractivos: reducen la probabilidad del fallo de raíz.
- **Comparar tamaños "manzanas con manzanas".** Una imagen Docker `scratch`/`distroless` con un binario Go estático también es pequeña. La ventaja del unikernel no es solo el tamaño del artefacto, sino **lo poco que hay ejecutándose** y el **modelo de aislamiento**.
- **El kernel compartido es una ventaja operativa y un riesgo de seguridad a la vez.** Compartir kernel simplifica (un solo kernel que parchear) pero concentra el riesgo: una vulnerabilidad de *escape de contenedor* (p. ej., fallos históricos en runc) compromete el host y a todos sus vecinos. El unikernel sobre hipervisor eleva el listón del escape a "romper el hipervisor".

---

## 1.6. Comparativa: Unikernels vs Kubernetes

Aquí hay que evitar un error de categoría frecuente: **Kubernetes es un orquestador**, no un formato de ejecución. La comparación honesta es *"el ecosistema de orquestación de contenedores"* frente a *"cómo se orquestan (hoy) los unikernels"*.

| Aspecto | Kubernetes (contenedores) | Unikernels |
|---------|---------------------------|------------|
| **Modelo** | Orquesta *pods*/contenedores sobre un pool de nodos | No hay un orquestador estándar equivalente |
| **Scheduling, self-healing, scaling** | Maduro y estándar de facto | Inmaduro; se apoya en soluciones ad-hoc o en integrarse **dentro** de K8s |
| **Networking** | CNI, Services, Ingress, NetworkPolicies | Redes de VM (bridge/tap, port-forward); sin CNI nativo |
| **Almacenamiento** | CSI, PV/PVC | Volúmenes de VM (raw, 9pfs); menos estandarizado |
| **Observabilidad** | Enorme ecosistema (Prometheus, sidecars...) | Limitada; sin *sidecars* clásicos (un unikernel = un proceso) |
| **Ecosistema/comunidad** | Gigantesco | Pequeño pero especializado |

### ¿Entonces los unikernels sustituyen a Kubernetes?

**No directamente.** Hay tres estrategias reales para "producción con unikernels", que verás en el módulo 5:

1. **Unikernels *dentro* de Kubernetes vía microVMs.** Usando **Kata Containers** con Firecracker/Cloud Hypervisor como *runtime* (a través de `RuntimeClass`), puedes ejecutar cargas fuertemente aisladas manteniendo `kubectl`, Deployments, Services, etc. Es la vía más pragmática para conservar tu plataforma actual.
2. **Plataformas específicas de unikernel.** Ofertas como **NanoVMs (ops + cloud providers)** o **Unikraft Cloud** gestionan el ciclo de vida de unikernels sin K8s.
3. **Orquestación clásica de VMs.** `libvirt`, plantillas de VM, *systemd units* que lanzan procesos QEMU/Firecracker, o herramientas de IaC (Terraform) sobre un hipervisor. Adecuado para *appliances* y edge.

> **Idea clave:** en 2026, "sustituir contenedores por unikernels" rara vez significa "tirar Kubernetes". Suele significar **cambiar la unidad de ejecución** (de contenedor a unikernel/microVM) **manteniendo** buena parte del plano de control, o **especializar** cargas concretas (edge, funciones, componentes de seguridad) fuera del clúster.

---

## 1.7. ¿Cuándo sustituir contenedores por unikernels? (guía de decisión)

### Buenos candidatos ✅

- **Edge / IoT / appliances:** poco espacio, arranque rápido, superficie mínima, actualizaciones atómicas de imagen.
- **NFV / funciones de red:** el caso histórico de ClickOS; latencia y densidad extremas.
- **Serverless / FaaS:** arrancar una instancia por invocación en milisegundos (el mismo problema que resuelve Firecracker para Lambda).
- **Microservicios de un solo propósito** con requisitos de seguridad/aislamiento altos.
- **Cargas sensibles multi-tenant** donde el aislamiento por hardware compensa la complejidad.

### Malos candidatos ❌

- Aplicaciones que dependen de **múltiples procesos**, `fork()`/`exec()` intensivo, o de un shell y utilidades del sistema.
- Software con **dependencias complejas de SO** difíciles de portar.
- Equipos que necesitan **el ecosistema completo de K8s** (operadores, service mesh, sidecars) sin margen para *tooling* inmaduro.
- Casos donde la **facilidad de depuración y el time-to-market** pesan más que la densidad o la seguridad extrema.
- Cargas con **almacenamiento con estado complejo** o que requieren orquestación sofisticada de datos.

### Tabla resumen de *trade-offs*

| Priorizas... | Elige |
|--------------|-------|
| Ecosistema, madurez, velocidad de desarrollo | **Contenedores + Kubernetes** |
| Aislamiento fuerte manteniendo K8s | **microVMs (Kata/Firecracker) en K8s** |
| Tamaño, arranque y superficie de ataque mínimos | **Unikernels** (POSIX si migras; clean-slate si reescribes) |
| Aislamiento de VM con arranque rápido para funciones | **microVMs / unikernels sobre Firecracker** |

---

## 1.8. Alternativas y tecnologías vecinas (visión de conjunto)

Para tomar decisiones con criterio, hay que conocer el "espacio post-contenedor" completo. Se detallan en el módulo 5; aquí una vista rápida:

- **microVMs (Firecracker, Cloud Hypervisor):** VMs mínimas con arranque en ~ms. No son unikernels (ejecutan un kernel Linux recortado + tu app/contenedor), pero comparten objetivos de densidad y aislamiento. **Muy maduras** y en producción a gran escala (AWS Lambda/Fargate usan Firecracker).
- **Kata Containers:** contenedores "de aspecto normal" que por debajo corren en una microVM. Integración directa con Kubernetes vía `RuntimeClass`. **La vía más fácil para ganar aislamiento sin cambiar tu flujo.**
- **gVisor:** un "kernel" en espacio de usuario (en Go) que intercepta las syscalls del contenedor para reducir la superficie de ataque **sin** VM. Alternativa de aislamiento con otro *trade-off* (compatibilidad/rendimiento vs seguridad).
- **WebAssembly + WASI:** módulos Wasm ejecutados en runtimes como **Wasmtime, WasmEdge, Wasmer**, orquestables con proyectos como **SpinKube/runwasi** en Kubernetes. Es la otra gran corriente "post-contenedor": arranque casi instantáneo, portabilidad y *sandbox* por diseño, a costa de un modelo de ejecución distinto y un ecosistema aún en maduración.

| Tecnología | Aislamiento | Arranque | Compatibilidad Linux | Madurez |
|------------|-------------|----------|----------------------|---------|
| Contenedor | Namespaces (SO) | ms–s | Total | Muy alta |
| gVisor | Sandbox user-space | ms | Alta (con límites) | Alta |
| Kata / microVM | VM (hardware) | ~ms–100 ms | Total | Alta |
| **Unikernel** | VM (hardware) | ~ms | Variable | Emergente |
| WASM/WASI | Sandbox de runtime | ~µs–ms | Baja (recompilar a Wasm) | Emergente |

---

## 1.9. Resumen del módulo

- Un **unikernel** = aplicación + *library OS* mínimo, en un **único espacio de direcciones**, que arranca sobre un **hipervisor**. No confundir con **microkernel** (arquitectura de SO).
- Su valor: **tamaño, arranque y superficie de ataque mínimos**, con **aislamiento por hardware**.
- Hay dos enfoques: **clean-slate** (reescribir, máxima seguridad/especialización) y **POSIX/compat** (migrar lo que ya tienes → **Unikraft, Nanos, OSv**).
- Frente a **Docker**, cambian el modelo de aislamiento (VM en vez de kernel compartido). Frente a **Kubernetes**, hoy **no** hay orquestador estándar equivalente: se integran vía **microVMs en K8s**, plataformas propias o gestión clásica de VMs.
- Sustituir contenedores por unikernels es acertado en **edge, NFV, serverless y cargas de alta seguridad**, y desaconsejable cuando priman ecosistema, multiproceso o velocidad de desarrollo.

**Siguiente paso:** montar el laboratorio → [`02-instalacion-ubuntu-24.04.md`](02-instalacion-ubuntu-24.04.md)

---

### Referencias del módulo

- Madhavapeddy et al., *"Unikernels: Library Operating Systems for the Cloud"*, ASPLOS 2013 — https://anil.recoil.org/papers/2013-asplos-mirage.pdf
- Manco et al., *"My VM is Lighter (and Safer) than your Container"*, SOSP 2017 — https://dl.acm.org/doi/10.1145/3132747.3132763
- Kuenzer et al., *"Unikraft: Fast, Specialized Unikernels the Easy Way"*, EuroSys 2021 — https://dl.acm.org/doi/10.1145/3447786.3456248
- Engler, Kaashoek, O'Toole, *"Exokernel"*, SOSP 1995 — https://pdos.csail.mit.edu/6.828/2008/readings/engler95exokernel.pdf
- R. Pavlicek, *"Unikernels: Beyond Containers to the Next Generation of Cloud"* (O'Reilly) — https://nanovms.com/pdf/unikernels-beyond-containers.pdf
- Documentación Unikraft — https://unikraft.org/docs
- Documentación NanoVMs/Ops — https://docs.ops.city
- MirageOS — https://mirage.io
