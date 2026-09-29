# Apéndice — Glosario y referencias

Material de apoyo transversal a todo el curso.

---

## A. Glosario de términos

**Aislamiento por hardware (VT-x / AMD-V)**
Mecanismo de virtualización asistida por CPU que permite a un hipervisor ejecutar VMs con separación fuerte. Es la frontera de seguridad de un unikernel.

**app-elfloader**
Componente de Unikraft que carga y ejecuta binarios ELF de Linux sin recompilarlos, traduciendo sus llamadas al sistema a implementaciones internas. Clave para migrar apps existentes.

**Bare metal**
Ejecución directamente sobre hardware físico, sin hipervisor. Algunos unikernels pueden arrancar así.

**Capstan**
Herramienta de empaquetado/ejecución de OSv que combina kernels precompilados con la aplicación.

**Clean-slate (unikernel)**
Enfoque que reescribe el SO desde cero en un lenguaje concreto (OCaml, C++, Haskell...) y solo ejecuta apps de ese lenguaje. Máxima especialización/seguridad; sin compatibilidad con binarios existentes. Ej.: MirageOS, IncludeOS.

**Cloud Hypervisor**
VMM moderno (Rust, Linux Foundation) para cargas cloud; alternativa a Firecracker con más funciones de dispositivo.

**cgroups / namespaces**
Mecanismos del kernel Linux que aíslan y limitan recursos de los contenedores. **No** intervienen en unikernels (que se aíslan por hipervisor).

**Espacio de direcciones único (single address space)**
Modelo en el que app y "SO" comparten memoria y nivel de privilegio; elimina la separación usuario/kernel y convierte las syscalls en llamadas a función.

**Exokernel**
Arquitectura de SO (MIT, 1995) que expone el hardware de forma segura y deja la política a *library OS* de la aplicación. Antecedente conceptual del unikernel.

**Firecracker**
VMM minimalista de AWS (Rust) para microVMs; arranque en ~ms y superficie de ataque mínima. Base de AWS Lambda/Fargate.

**gVisor**
Sandbox de contenedores que implementa un "kernel" en espacio de usuario (Go) interceptando syscalls; aislamiento sin VM.

**Hipervisor / VMM (Virtual Machine Monitor)**
Software que crea y ejecuta VMs. Tipo 1 (bare metal, p. ej. Xen) o tipo 2 (sobre un SO). KVM convierte Linux en hipervisor tipo 1-ish; QEMU/Firecracker son los VMM que lo usan.

**Kata Containers**
Runtime que ejecuta contenedores OCI dentro de microVMs, integrable en Kubernetes vía RuntimeClass.

**Kraftfile**
Fichero declarativo de Unikraft/KraftKit (spec v0.6) que describe cómo construir y ejecutar un unikernel.

**KVM (Kernel-based Virtual Machine)**
Módulo del kernel Linux que expone la virtualización por hardware. Requisito común para ejecutar unikernels en Linux.

**Library OS (libOS)**
Sistema operativo ofrecido como bibliotecas que se enlazan con la aplicación, en lugar de como un kernel separado. Núcleo de la idea de unikernel.

**lwIP**
Pila TCP/IP ligera y ampliamente usada, integrada por varios unikernels (incl. Unikraft).

**Microkernel**
Arquitectura de SO con un kernel mínimo (IPC, scheduling, memoria básica) y el resto de servicios en espacio de usuario (seL4, MINIX, QNX, L4). **No** es un unikernel ni un sustituto de contenedores.

**microVM**
Máquina virtual ultraligera y de arranque rápido (Firecracker, Cloud Hypervisor). Hábitat natural de los unikernels; también ejecuta contenedores (Kata).

**Nanos**
Kernel unikernel de NanoVMs que ejecuta binarios Linux de un solo proceso. Se opera con la CLI `ops`.

**Ops (`ops`)**
CLI de NanoVMs para construir, ejecutar y desplegar unikernels Nanos.

**POSIX-compatible (unikernel)**
Enfoque que ofrece interfaz tipo POSIX o compatibilidad binaria con Linux para migrar apps existentes. Ej.: Unikraft, Nanos, OSv.

**QEMU**
Emulador/virtualizador de máquinas; con KVM proporciona virtualización acelerada. VMM más flexible y compatible.

**RuntimeClass**
Recurso de Kubernetes que selecciona el runtime de contenedor por pod (p. ej., Kata en microVM).

**rootfs**
Sistema de ficheros raíz de la imagen. En Unikraft puede construirse desde un `Dockerfile`.

**Solo5**
Capa de portabilidad/*tender* que permite a MirageOS (y otros) ejecutarse sobre KVM (hvt), seccomp (spt), virtio y Xen.

**Syscall shim**
Capa que traduce llamadas al sistema (de una app POSIX/Linux) a las implementaciones internas del unikernel.

**virtio**
Estándar de dispositivos paravirtualizados (red, bloque, consola, entropía...) que usan los unikernels para comunicarse con el hipervisor de forma eficiente.

**WASM / WASI**
WebAssembly y su interfaz de sistema (WASI); modelo de ejecución en *sandbox* alternativo al contenedor/unikernel, basado en bytecode + runtime.

**W^X (Write XOR Execute)**
Protección de memoria: una página es escribible o ejecutable, nunca ambas. Mitigación relevante dada la ausencia de separación usuario/kernel en unikernels.

---

## B. Bibliografía y *papers* fundacionales

- Madhavapeddy, A. et al. **"Unikernels: Library Operating Systems for the Cloud"**. ASPLOS 2013. — https://anil.recoil.org/papers/2013-asplos-mirage.pdf
- Manco, F. et al. **"My VM is Lighter (and Safer) than your Container"**. SOSP 2017 (LightVM). — https://dl.acm.org/doi/10.1145/3132747.3132763
- Kuenzer, S. et al. **"Unikraft: Fast, Specialized Unikernels the Easy Way"**. EuroSys 2021. — https://dl.acm.org/doi/10.1145/3447786.3456248
- Martins, J. et al. **"ClickOS and the Art of Network Function Virtualization"**. NSDI 2014. — https://www.usenix.org/conference/nsdi14/technical-sessions/presentation/martins
- Agache, A. et al. **"Firecracker: Lightweight Virtualization for Serverless Applications"**. NSDI 2020. — https://www.usenix.org/conference/nsdi20/presentation/agache
- Engler, D., Kaashoek, M.F., O'Toole, J. **"Exokernel: An OS Architecture for Application-Level Resource Management"**. SOSP 1995. — https://pdos.csail.mit.edu/6.828/2008/readings/engler95exokernel.pdf

### Libros

- Pavlicek, R. **"Unikernels: Beyond Containers to the Next Generation of Cloud"** (O'Reilly, gratuito). — https://nanovms.com/pdf/unikernels-beyond-containers.pdf
- Madhavapeddy, A. et al. **"Real World OCaml"** (contexto para MirageOS). — https://dev.realworldocaml.org/

---

## C. Documentación oficial de los proyectos

| Proyecto | Documentación | Repositorio |
|----------|---------------|-------------|
| Unikraft / KraftKit | https://unikraft.org/docs | https://github.com/unikraft/kraftkit |
| Catálogo Unikraft | — | https://github.com/unikraft/catalog |
| NanoVMs / Ops (Nanos) | https://docs.ops.city | https://github.com/nanovms/ops |
| MirageOS | https://mirage.io/docs | https://github.com/mirage/mirage |
| Solo5 | — | https://github.com/Solo5/solo5 |
| OSv | https://github.com/cloudius-systems/osv/wiki | https://github.com/cloudius-systems/osv |
| Firecracker | https://firecracker-microvm.github.io/ | https://github.com/firecracker-microvm/firecracker |
| Cloud Hypervisor | https://www.cloudhypervisor.org/ | https://github.com/cloud-hypervisor/cloud-hypervisor |
| Kata Containers | https://katacontainers.io/ | https://github.com/kata-containers/kata-containers |
| gVisor | https://gvisor.dev/ | https://github.com/google/gvisor |

---

## D. Recursos para seguir aprendiendo

- **Xen Project — Unikernels:** material introductorio y charlas históricas del ecosistema.
- **Charlas SOSP/NSDI/EuroSys:** las presentaciones de los papers anteriores suelen tener vídeo; excelentes para interiorizar los conceptos.
- **Comunidad Unikraft (Discord/GitHub Discussions):** el proyecto más activo; buen sitio para dudas de migración.
- **Blog de NanoVMs:** tutoriales prácticos de empaquetado de lenguajes y frameworks concretos (Node, Python, Go, Java...).

---

## E. Nota de vigencia

El *tooling* de unikernels evoluciona con rapidez y algunos proyectos cambian de ritmo (p. ej., OSv se mantiene por comunidad con su último *release* etiquetado en 2022; IncludeOS ha reducido su actividad). **Verifica siempre versiones, comandos y estado de cada proyecto contra su documentación oficial** antes de tomar decisiones de arquitectura o de aplicar comandos en entornos reales. Este material se revisó en **septiembre de 2026**.
