---
tags:
  - DBT_CORE
---

## Parámetros de Configuración en `dbt_project.yml` 
El archivo `dbt_project.yml` es crucial para configurar y gestionar un proyecto dbt. A continuación, se detallan los parámetros principales en este archivo, se puede ver todo el detalle y listado ed configuraciónes en la documentación oficial en <https://docs.getdbt.com/reference/dbt_project.yml?version=2>: 

### General 
-  **name**: Nombre del proyecto dbt.
- **version**: Versión del proyecto dbt.
- **description**: Descripción breve del proyecto.
- **plugins**: Configuraciones adicionales para plugins de dbt.
- **docs**: Información sobre los documentos del proyecto. 

____
### Modelos 
 - **models**: Configuración específica para modelos SQL, incluidas sus carpetas. 
	 - **model-paths**: Directorios donde se buscarán modelos SQL. 
	 - **materialized**: Define el tipo de materialización para los modelos (`table`, `view`, `incremental`).
	 - **schema**: Esquema al que se asignarán los modelos.
	 - **tags**: Etiquetas personalizadas para filtrar modelos. 
 ____
### Variables 
 - **vars**: Variables globales utilizables en la configuración y scripts de dbt. 
	 - **<variable_name>**: Valor de la variable.

____
### Seeds 
- **seed-paths**: Directorios donde se buscarán archivos CSV que se importarán como tablas. 
	- **<path_to_directory>**: Ruta al directorio de semillas. 
	
### Snapshots 
- **snapshot-paths**: Directorios donde se guardarán las instantáneas SCD2. 
	- **<path_to_directory>**: Ruta al directorio de snapshots. 
	 
____
### Macros 
- **macros**: Definiciones de macros Jinja reutilizables en scripts y modelos. 
	- **<macro_name>**: Nombre de la macro. 
	- **< template>**: Cuerpo de la macro como plantilla Jinja.
___
### Tests 
- **tests**: Configuración de pruebas para modelos SQL. 
	- **models**: Modelos a los que se aplican las pruebas. 
	- **columns**: Columnas específicas a probar. 
	- **conditions**: Condiciones para ejecutar las pruebas. 
	- **tests**: Definición de pruebas específicas. 
____
### Sources 
- **sources**: Configuración de fuentes de datos externas. 
	- **<source_name>**: Nombre de la fuente. 
	- **name**: Nombre del modelo o tabla en dbt. 
	- **schema**: Esquema en el que se creará la tabla. 
	- **config**: Otras configuraciones específicas para la fuente. 
___
### Resources 
- **resources**: Configuración de recursos compartidos entre modelos. 
	- **<resource_name>**: Nombre del recurso. 
	- **target**: Fichero de configuración de destino (por ejemplo, `source`, `transform`). 
	- **<config_variable>**: Variables de configuración específicas para el recurso. 
____
### Environments 
- **environments**: Configuraciones específicas para entornos (desarrollo, pruebas, producción). 
	- **<environment_name>**: Nombre del entorno. 
	- **target**: Target activo en este entorno. 
	- **outputs**: Configuraciones de salida específicas para el entorno. 
### Customization 
- **custom**: Otras configuraciones personalizadas. 
	- **<config_key>**: Clave de la configuración personalizada. 
	- **<config_value>**: Valor de la configuración personalizada. 

Este archivo es flexible y permite una gran variedad de ajustes según las necesidades del proyecto. Aquí hay un ejemplo básico: 
```yaml 
name: "mi_proyecto_dbt" 
version: "1.0.0" 
description: "Un proyecto dbt para análisis de datos." 

models: 
	model-paths: 
		- "models" 
	seed-paths: 
		- "seeds" 
	vars: 
		mi_variable: "valor" 
	tests: 
		my_test: 
			columns: 
				- id 
				- name 
``` 

Este archivo debe ser ajustado según las necesidades específicas del proyecto y los requerimientos de la infraestructura de datos.