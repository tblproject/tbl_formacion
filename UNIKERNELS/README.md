# Curso avanzado: Unikernels como sustituto de contenedores

> **Nivel:** Avanzado (arquitectos e ingeniería de plataforma)
> **Idioma:** Español
> **Formato:** Curso modular en Markdown, orientado a la práctica
> **Última revisión de contenidos:** septiembre 2026

---

## Aviso terminológico importante (léelo antes de empezar)

En muchas conversaciones se dice "microkernel" cuando en realidad se quiere hablar de **unikernels**. **No son lo mismo** y conviene fijar los términos desde el minuto uno, porque de lo contrario se arrastran errores conceptuales durante todo el aprendizaje:

- **Microkernel** (arquitectura de sistema operativo): un diseño de kernel en el que se deja en modo privilegiado el mínimo imprescindible (planificación, IPC, gestión básica de memoria) y el resto (drivers, sistemas de ficheros, pilas de red) se ejecuta como servicios en espacio de usuario. Ejemplos: **seL4, MINIX 3, QNX, L4, GNU Hurd, Zircon (Fuchsia)**. Es una forma de *construir un SO de propósito general*, **no** una alternativa a los contenedores.
- **Unikernel**: una **imagen de máquina especializada y de propósito único** que compila *tu aplicación* junto con *solo las funciones de sistema operativo que esa aplicación necesita* (un *library OS*), en un **único espacio de direcciones**, y que arranca **directamente sobre un hipervisor** (o bare metal). *Esta* es la tecnología que la industria plantea como **sustituto/alternativa a los contenedores**.
- **MicroVM** (concepto vecino): máquinas virtuales ultraligeras (**Firecracker, Cloud Hypervisor, Kata Containers**) que aíslan cargas *tipo contenedor* con la fortaleza de una VM. Se solapan con los unikernels en el terreno de la ejecución, y de hecho **muchos unikernels se ejecutan encima de microVMs**.

Este curso trata sobre **unikernels**, con especial foco en **cómo y cuándo sustituir contenedores** por ellos. Los microVM y WebAssembly/WASI se tratan como **alternativas** en el módulo 5.

---

## ¿A quién va dirigido?

A perfiles que ya dominan Docker y Kubernetes y quieren:

- Entender en profundidad qué son los unikernels y su modelo de ejecución.
- Valorar con criterio técnico **cuándo tiene sentido** sustituir contenedores por unikernels (y cuándo **no**).
- Montar un entorno de laboratorio sobre **Ubuntu Server 24.04 LTS**.
- Conocer los componentes internos (library OS, hipervisor, red, almacenamiento, seguridad, observabilidad).
- Llevar unikernels a producción o, al menos, a una prueba de concepto seria.

**Requisitos previos:** experiencia con Linux, línea de comandos, virtualización (KVM/QEMU), contenedores (Docker) y orquestación (Kubernetes). Nociones de compilación y del ciclo *build → ship → run*.

---

## Estructura del curso

| Módulo | Fichero | Contenido |
|--------|---------|-----------|
| 0 | Este `README.md` | Índice, terminología y ruta de aprendizaje |
| 1 | [`01-introduccion-y-comparativa.md`](01-introduccion-y-comparativa.md) | Qué es un unikernel, historia, modelo de ejecución y **comparativa detallada con Docker y Kubernetes** |
| 2 | [`02-instalacion-ubuntu-24.04.md`](02-instalacion-ubuntu-24.04.md) | **Instalación paso a paso** del stack de unikernels sobre Ubuntu Server 24.04 LTS |
| 3 | [`03-componentes-y-funcionalidades.md`](03-componentes-y-funcionalidades.md) | **Cada componente y funcionalidad** en detalle: library OS, hipervisores, red, almacenamiento, seguridad, observabilidad |
| 4 | [`04-ejemplos-practicos.md`](04-ejemplos-practicos.md) | **Laboratorios prácticos**, incluida la migración de un contenedor a unikernel y benchmarking |
| 5 | [`05-produccion-orquestacion-y-alternativas.md`](05-produccion-orquestacion-y-alternativas.md) | Orquestación, patrones de producción, casos de uso y **alternativas** (microVMs, WASM) |
| A | [`APENDICE-glosario-y-referencias.md`](APENDICE-glosario-y-referencias.md) | Glosario, bibliografía, *papers* fundacionales y recursos |

### Ruta de aprendizaje recomendada

```
Módulo 1 (teoría y encaje)
   │
   ▼
Módulo 2 (montar el laboratorio)  ──►  Módulo 4 (labs 0–2, primeras imágenes)
   │                                        │
   ▼                                        ▼
Módulo 3 (internals)  ─────────────►  Módulo 4 (labs 3–6, migración y avanzado)
                                            │
                                            ▼
                                    Módulo 5 (producción y alternativas)
```

Puedes leer el módulo 3 (internals) en paralelo a los laboratorios: entenderás mejor cada componente cuando lo veas en acción.

---

## Familias de unikernels que usaremos

El curso es agnóstico, pero se apoya sobre todo en dos implementaciones **activas y con buen tooling** en 2026, y menciona otras como referencia:

| Proyecto | Lenguaje/enfoque | Compatibilidad | Estado | Uso en el curso |
|----------|------------------|----------------|--------|-----------------|
| **Unikraft** (`kraft`) | Modular en C, POSIX-like, *app-elfloader* para binarios Linux | Alta (apps existentes) | Muy activo, respaldo comercial | **Principal** |
| **NanoVMs / Nanos** (`ops`) | POSIX-like, ejecuta binarios Linux | Alta (un proceso) | Activo | **Principal** |
| **MirageOS** | *Clean-slate* en OCaml (Solo5) | Solo apps OCaml | Activo | Ejemplo *clean-slate* |
| **OSv** | POSIX-like, compat. binaria Linux | Alta | Comunidad (último *release* 2022) | Referencia |
| **IncludeOS** | *Clean-slate* en C++ | Solo apps C++ | Actividad reducida | Referencia histórica |

> Las diferencias entre los enfoques **clean-slate** (reescribir en un lenguaje seguro, máxima especialización) y **POSIX/compat** (ejecutar lo que ya tienes) se explican en el módulo 1 y son clave para decidir la estrategia de migración.

---

## Cómo se ha construido este material

Siguiendo el principio de este espacio de formación: **no se inventa información**. Los comandos de instalación y flujos de trabajo se han contrastado con la documentación oficial de cada proyecto (Unikraft/KraftKit, NanoVMs/Ops, MirageOS, OSv) en septiembre de 2026. Aun así, el tooling de unikernels evoluciona rápido: **verifica siempre las versiones y comandos contra la documentación oficial** enlazada en cada módulo antes de aplicar nada en un entorno real.
