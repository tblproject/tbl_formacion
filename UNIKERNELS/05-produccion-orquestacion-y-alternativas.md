# Módulo 5 — Producción, orquestación, casos de uso y alternativas

> **Objetivos del módulo**
> - Conocer las **estrategias reales para operar unikernels en producción**.
> - Ver cómo **conservar Kubernetes** ganando aislamiento (microVMs).
> - Repasar **casos de uso reales** y patrones de éxito/fracaso.
> - Comparar unikernels con sus **alternativas** (microVMs, gVisor, WASM) para elegir con criterio.

---

## 5.1. El problema de operar unikernels en producción

Recordatorio del módulo 1: **no existe un orquestador de unikernels estándar** equivalente a Kubernetes. Además, la observabilidad y la depuración son inmaduras (módulo 3, §3.11). Por tanto, "poner unikernels en producción" consiste en **elegir un plano de control** entre estas tres familias.

```
              ┌──────────────────────────────────────────────────────┐
              │   ¿Quieres conservar tu plataforma Kubernetes?        │
              └──────────────────────────────────────────────────────┘
                        │ Sí                              │ No
                        ▼                                 ▼
        ┌───────────────────────────┐      ┌──────────────────────────────────┐
        │  A) microVMs en K8s        │      │  ¿Cuántas cargas / qué entorno?  │
        │  (Kata + Firecracker/CH)   │      └──────────────────────────────────┘
        │  vía RuntimeClass          │            │ Muchas / nube        │ Pocas / edge
        └───────────────────────────┘            ▼                       ▼
                                        ┌──────────────────┐   ┌────────────────────────┐
                                        │ B) Plataforma de │   │ C) Gestión clásica de   │
                                        │ unikernels        │   │ VMs (libvirt/systemd/   │
                                        │ (NanoVMs, Unikraft│   │ Terraform + Firecracker)│
                                        │ Cloud)            │   │                          │
                                        └──────────────────┘   └────────────────────────┘
```

---

## 5.2. Estrategia A — MicroVMs dentro de Kubernetes (la vía pragmática)

La forma más realista de "sustituir contenedores por algo más aislado **sin tirar tu plataforma**" es cambiar el *runtime* de contenedor por uno basado en **microVM**:

- **Kata Containers:** implementa la interfaz de *runtime* de contenedores (CRI/OCI) pero ejecuta cada *pod* dentro de una **microVM** (Firecracker, Cloud Hypervisor o QEMU). Para Kubernetes es casi transparente: defines una `RuntimeClass` y tus *pods* pasan a estar aislados por hardware.

Ejemplo de `RuntimeClass` + Pod con Kata:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata-fc
handler: kata-fc          # handler configurado en el nodo (kata + firecracker)
---
apiVersion: v1
kind: Pod
metadata:
  name: app-aislada
spec:
  runtimeClassName: kata-fc   # este pod corre en una microVM
  containers:
    - name: app
      image: registry.example.com/mi-app:1.0
      ports: [{ containerPort: 8080 }]
```

**Matiz importante:** Kata ejecuta *contenedores* dentro de microVMs; **no** ejecuta unikernels directamente. Es la opción cuando lo que buscas es **el aislamiento de VM manteniendo el flujo de contenedores**. Si de verdad quieres *unikernels* en K8s, hoy es terreno experimental (proyectos que empaquetan unikernels como imágenes OCI y VMMs que los arrancan); evalúalo como PoC, no como base de producción.

| Ventaja | Inconveniente |
|---------|---------------|
| Conservas `kubectl`, Deployments, Services, CI/CD | No son unikernels "puros" (es contenedor en microVM) |
| Aislamiento de hardware por pod | Overhead algo mayor que un contenedor normal |
| Cambio casi transparente para los equipos | Requiere nodos que soporten virtualización anidada si el clúster es virtual |

---

## 5.3. Estrategia B — Plataformas específicas de unikernel

Cuando el objetivo es explotar unikernels "de verdad" a escala, existen plataformas que gestionan su ciclo de vida:

- **NanoVMs (`ops` + integración con nubes):** `ops` construye la imagen y la despliega en AWS, GCP, Azure, etc. como una VM/imagen nativa. Gestión pensada para Nanos.
- **Unikraft Cloud / KraftCloud:** plataforma comercial del proyecto Unikraft orientada a arranques ultrarrápidos y *scale-to-zero* de unikernels.

```bash
# Ejemplo conceptual con ops hacia una nube (requiere credenciales configuradas)
ops image create server -c config.json -t aws -i mi-servicio
ops instance create mi-servicio -t aws -z eu-west-1a
ops instance list -t aws
```

| Ventaja | Inconveniente |
|---------|---------------|
| Explotas de lleno arranque/densidad/seguridad | Menos ecosistema que K8s; posible *lock-in* de plataforma |
| Flujo pensado para unikernels | Curva de aprendizaje y madurez operativa |

---

## 5.4. Estrategia C — Gestión clásica de VMs (edge / appliances)

Para pocos nodos, *edge* o *appliances*, orquestar unikernels como **VMs normales** es perfectamente válido:

- **`libvirt` + plantillas de dominio** para definir cada unikernel como una VM.
- **`systemd` units** que lanzan procesos QEMU/Firecracker y los supervisan (reinicio, dependencias).
- **Terraform / Ansible / IaC** para provisionar los hosts y las imágenes.

Ejemplo de *systemd unit* que supervisa un unikernel bajo Firecracker:

```ini
# /etc/systemd/system/mi-unikernel.service
[Unit]
Description=Mi unikernel (Firecracker)
After=network.target

[Service]
ExecStart=/usr/local/bin/firecracker --api-sock /run/mi-uk.sock --config-file /etc/mi-uk/config.json
Restart=always
User=unikernel

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now mi-unikernel.service
sudo systemctl status mi-unikernel.service
```

| Ventaja | Inconveniente |
|---------|---------------|
| Simple, sin dependencias de orquestador | No escala como K8s; *self-healing* limitado |
| Ideal para edge/appliances/on-prem pequeño | Operativa manual o con IaC propia |

---

## 5.5. Recomendaciones operativas transversales

Independientemente de la estrategia:

- **Imágenes inmutables + estado externo.** Igual que con contenedores bien hechos: nada de estado en la imagen; usa volúmenes o servicios gestionados.
- **Logs por consola serie → colector.** Redirige la salida a un agregador (Loki, ELK, CloudWatch...). No hay `kubectl logs` nativo.
- **Métricas dentro de la app.** Expón `/metrics` (Prometheus) desde la propia aplicación; no hay *sidecars*.
- **CI/CD reproducible.** Versiona el `Kraftfile`/`config.json` y construye imágenes en pipeline. El "kernel" viaja **con** la app: prueba cada build como un todo.
- **Superficie del VMM mínima en prod.** Prefiere **Firecracker/Cloud Hypervisor** frente a QEMU para cargas expuestas.
- **Estrategia de parcheo.** Un CVE en una lib incluida = reconstruir y redeplegar la imagen. Ten el pipeline engrasado para reconstruir rápido ante vulnerabilidades.
- **Plan B documentado.** Si una carga no migra limpiamente, ten claro el *fallback* a microVM (Kata) o a contenedor.

---

## 5.6. Casos de uso reales (dónde ha funcionado)

- **NFV (Network Function Virtualization):** ClickOS demostró middleboxes (routers, firewalls, NAT) como unikernels con latencia y densidad excelentes. Caso histórico de éxito.
- **Serverless / FaaS:** el patrón "una microVM por invocación" que popularizó **Firecracker** para AWS Lambda/Fargate es el mismo que habilitan los unikernels: arranque en ms, aislamiento fuerte, densidad alta.
- **Edge computing / IoT:** imágenes mínimas, actualizaciones atómicas, superficie de ataque reducida en dispositivos con recursos limitados.
- **Componentes de seguridad:** *appliances* de red, TLS-terminators, DNS, cargas donde reducir el código en ejecución es un objetivo de seguridad primario (MirageOS ha tenido despliegues notables aquí, p. ej. componentes en el ecosistema Qubes/MirageVPN).
- **Cargas multi-tenant sensibles:** cuando el aislamiento por hardware compensa el coste operativo.

**Dónde NO ha cuajado (sé honesto con tu equipo):** aplicaciones empresariales monolíticas, pilas con muchos procesos, equipos que dependen del ecosistema completo de K8s y de la depuración interactiva. En estos casos, **contenedores (o Kata para más aislamiento) siguen siendo la elección correcta**.

---

## 5.7. Alternativas al unikernel (panorama "post-contenedor")

El proyecto pide comparar siempre con alternativas. Estas son las tecnologías con las que compite o convive un unikernel, con sus diferencias:

### microVMs — Firecracker / Cloud Hypervisor
- **Qué permiten:** ejecutar un kernel Linux recortado + tu app/contenedor dentro de una VM que arranca en ~ms.
- **Diferencia con unikernel:** **no** funden app y SO en un binario; siguen ejecutando Linux (más compatible, algo más de huella). **Mucho más maduras** y en producción a hiperescala.
- **Cuándo elegirlas:** quieres aislamiento de VM y arranque rápido **sin** rediseñar la app ni pelear con compatibilidad. **Es, en la práctica, la alternativa más común y de menor riesgo a "sustituir contenedores".**

### Kata Containers
- **Qué permite:** contenedores OCI que corren en microVMs, integrados en K8s (§5.2).
- **Diferencia con unikernel:** transparente para el desarrollador; sigue siendo un contenedor (con Linux dentro).
- **Cuándo elegirla:** aislamiento fuerte conservando exactamente tu flujo de contenedores/K8s.

### gVisor
- **Qué permite:** un "kernel" en espacio de usuario (Go) que intercepta las syscalls del contenedor, reduciendo la superficie de ataque **sin** VM.
- **Diferencia con unikernel:** no hay hipervisor; el aislamiento es un *sandbox* de syscalls. Menos aislamiento que una VM, pero sin virtualización anidada.
- **Cuándo elegirla:** endurecer contenedores en entornos donde no puedes/quieres usar virtualización (p. ej., ciertos clústeres gestionados).

### WebAssembly + WASI
- **Qué permite:** compilar tu código a **Wasm** y ejecutarlo en runtimes (**Wasmtime, WasmEdge, Wasmer**) con arranque casi instantáneo, portabilidad y *sandbox* por diseño. Orquestable en K8s con **runwasi/SpinKube**.
- **Diferencia con unikernel:** modelo de ejecución totalmente distinto (bytecode + runtime, no una VM). Excelente para *plugins*, funciones y edge; ecosistema aún madurando, compatibilidad con software existente limitada (hay que recompilar a Wasm/WASI).
- **Cuándo elegirla:** cargas nuevas orientadas a funciones/edge donde priman arranque, portabilidad y aislamiento del *runtime*.

### Tabla comparativa final

| Tecnología | Aislamiento | Arranque | Compat. software existente | Madurez | Encaje con K8s |
|------------|-------------|----------|----------------------------|---------|----------------|
| Contenedor | Namespaces (SO) | ms–s | Total | Muy alta | Nativo |
| gVisor | Sandbox syscalls | ms | Alta (con límites) | Alta | Vía runtime |
| Kata / microVM | VM (hardware) | ~ms–100 ms | Total | Alta | Vía RuntimeClass |
| **Unikernel** | VM (hardware) | ~ms | Variable (POSIX) / nula (clean-slate) | **Emergente** | Experimental |
| WASM/WASI | Sandbox runtime | µs–ms | Baja (recompilar) | Emergente | Vía runwasi/SpinKube |

---

## 5.8. Recomendación final (marco de decisión)

1. **¿Necesitas solo más aislamiento y densidad, sin tocar tus apps?** → **microVMs (Kata + Firecracker) en K8s**. Bajo riesgo, alto retorno.
2. **¿Cargas específicas (edge, NFV, funciones, seguridad) donde tamaño/arranque/superficie son críticos y puedes portar o reescribir?** → **Unikernels** (Unikraft/Nanos si migras; MirageOS si reescribes componentes críticos).
3. **¿Cargas nuevas tipo función/plugin, foco en portabilidad y arranque instantáneo?** → **WASM/WASI**.
4. **¿Endurecer contenedores sin virtualización?** → **gVisor**.
5. **¿Nada de lo anterior aporta ventaja clara?** → **Contenedores + Kubernetes** siguen siendo una elección excelente. No cambies por moda; cambia por una métrica de negocio (coste, seguridad, latencia, densidad) que puedas **medir** (módulo 4, Lab 7).

> **Mensaje para llevar a tu organización:** "sustituir contenedores por unikernels" es una decisión **por carga**, no global. Empieza por un caso donde la ventaja sea medible, hazlo con una PoC (labs de este curso), mide, y decide con datos. Mantén siempre un *fallback* a microVM/contenedor.

---

## 5.9. Resumen del módulo

- Operar unikernels = elegir plano de control: **A) microVMs en K8s (Kata)**, **B) plataforma de unikernel (NanoVMs/Unikraft Cloud)**, **C) gestión clásica de VMs** (edge).
- Kubernetes rara vez desaparece: lo habitual es **cambiar la unidad de ejecución** conservando el plano de control, o **especializar** cargas concretas.
- Casos ganadores: **NFV, serverless, edge, seguridad, multi-tenant sensible**. Casos a evitar: monolitos multiproceso, dependencia total del ecosistema K8s.
- Las **alternativas** (microVMs, Kata, gVisor, WASM) cubren distintos puntos del espacio aislamiento/compatibilidad/madurez. **microVMs es la alternativa de menor riesgo** a sustituir contenedores.
- Decide **por carga y con métricas**, no por tendencia.

**Continúa con:** glosario y referencias → [`APENDICE-glosario-y-referencias.md`](APENDICE-glosario-y-referencias.md)

---

### Referencias del módulo

- Kata Containers — https://katacontainers.io/
- Kubernetes RuntimeClass — https://kubernetes.io/docs/concepts/containers/runtime-class/
- Firecracker — https://firecracker-microvm.github.io/
- Cloud Hypervisor — https://www.cloudhypervisor.org/
- gVisor — https://gvisor.dev/
- runwasi (contenedores WASM en containerd) — https://github.com/containerd/runwasi
- SpinKube (WASM en Kubernetes) — https://www.spinkube.dev/
- NanoVMs (despliegue en nubes) — https://docs.ops.city/
- Martins et al., *"ClickOS and the Art of Network Function Virtualization"*, NSDI 2014 — https://www.usenix.org/conference/nsdi14/technical-sessions/presentation/martins
