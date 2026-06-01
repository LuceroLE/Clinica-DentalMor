# Power BI

Dashboard interactivo desarrollado para el análisis de datos de una clínica dental.

## Objetivos

Visualizar los principales indicadores de negocio y facilitar la toma de decisiones mediante cuadros de mando interactivos.

## KPIs Analizados

- Facturación total
- Facturación mensual
- Ingreso medio por paciente
- Ingreso medio por cita
- Tratamientos más rentables
- Pacientes nuevos por mes
- Tasa de aceptación de presupuestos
- Estado de citas
- Días entre tratamiento y facturación

## Modelo de Datos

El dashboard se alimenta desde PostgreSQL mediante un modelo estrella compuesto por:

### Dimensiones
- dim_fecha
- dim_paciente
- dim_profesional
- dim_tratamiento

### Tablas de hechos
- fact_cobros
- fact_facturacion

## Herramientas Utilizadas

- Power BI Desktop
- PostgreSQL
- DBeaver
- Python (Pandas)
- VeviClinic

## Visualizaciones

- Tarjetas KPI
- Gráficos de líneas
- Barras horizontales
- Gráficos de dona
- Tablas dinámicas
- Segmentadores de datos
