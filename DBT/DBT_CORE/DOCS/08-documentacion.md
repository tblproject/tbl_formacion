# Fase 08 – Documentación y linaje

## Objetivo

Generar documentación navegable de tu proyecto (con el grafo de linaje interactivo) y conocer los **doc blocks** y las **exposures**.

---

## 1. La documentación vive junto al código

En dbt la documentación no es un documento aparte que se queda obsoleto: son las **descripciones** que escribes en los mismos ficheros YAML de propiedades, junto a la definición de cada modelo, columna, source y test. Ya las hemos ido añadiendo:

```yaml
models:
  - name: dim_customers
    description: "Dimensión de clientes con métricas de negocio."
    columns:
      - name: lifetime_value_eur
        description: "Suma del importe de todos los pedidos del cliente."
```

dbt combina esas descripciones con los metadatos que ya conoce (tipos de columna, dependencias, tests, código compilado) para generar un sitio web completo.

## 2. Doc blocks: descripciones largas y reutilizables

Para textos largos o que se repiten, usa **doc blocks**: bloques de markdown definidos en un fichero `.md` dentro de `models/` y referenciados desde el YAML.

```markdown
{% docs lifetime_value %}
El **valor de vida del cliente** (LTV) es la suma del importe de todos sus
pedidos. Se calcula en `dim_customers` a partir de `int_orders_aggregated`.
{% enddocs %}
```

```yaml
      - name: lifetime_value_eur
        description: "{{ doc('lifetime_value') }}"
```

Así puedes escribir documentación rica (markdown, enlaces, imágenes) sin ensuciar el YAML.

## 3. Generar y ver la documentación

```bash
cd proyecto/jaffle_shop
dbt docs generate --profiles-dir .    # construye el catálogo (catalog.json + manifest.json)
dbt docs serve --profiles-dir .        # levanta un servidor web local (http://localhost:8080)
```

`dbt docs generate` consulta el almacén para obtener el catálogo real (columnas y tipos de cada tabla). `dbt docs serve` abre un sitio donde puedes:

- Navegar por cada modelo, ver su descripción, columnas, tests y **el SQL compilado**.
- Ver de qué source procede cada dato.
- Explorar el **grafo de linaje (DAG) interactivo**, el famoso botón azul abajo a la derecha.

> El grafo de linaje es una de las funciones que más venden dbt en una demo: de un vistazo ves cómo un dato crudo fluye hasta el dashboard.

## 4. Exposures: documentar el consumo final

Una **exposure** declara un uso *aguas abajo* de tus modelos: un dashboard, un informe, una aplicación de ML… Así el linaje no termina en los marts, sino que llega hasta el producto que consume los datos.

De nuestro [`models/marts/_marts.yml`](../proyecto/jaffle_shop/models/marts/_marts.yml):

```yaml
exposures:
  - name: cuadro_mando_ventas
    label: "Cuadro de mando de ventas"
    type: dashboard
    maturity: high
    url: https://bi.example.com/dashboards/ventas
    depends_on:
      - ref('fct_orders')
      - ref('dim_customers')
    owner:
      name: Equipo de Analítica
      email: analitica@example.com
```

Ventajas:

- Aparece en el grafo de linaje: sabes qué dashboards dependen de qué modelos.
- Puedes ejecutar todo lo que alimenta un dashboard con selección de nodos:

  ```bash
  dbt build --profiles-dir . -s +exposure:cuadro_mando_ventas
  ```

  Esto reconstruye `fct_orders`, `dim_customers` y todas sus dependencias, y pasa sus tests. Perfecto antes de una reunión importante.

## 5. `persist_docs`: llevar las descripciones al propio almacén

Con `persist_docs` dbt escribe las descripciones como **comentarios en las tablas/columnas** del almacén, para que las vean también quienes consultan directamente la base de datos (no todos los motores lo soportan igual).

```yaml
models:
  jaffle_shop:
    +persist_docs:
      relation: true
      columns: true
```

---

## Referencias

- Documentación del proyecto: <https://docs.getdbt.com/docs/build/documentation>
- Doc blocks: <https://docs.getdbt.com/docs/build/documentation#using-docs-blocks>
- Exposures: <https://docs.getdbt.com/docs/build/exposures>
- `dbt docs`: <https://docs.getdbt.com/reference/commands/cmd-docs>

## Siguiente paso

➡️ [Fase 09 – Snapshots (SCD tipo 2)](09-snapshots.md)
