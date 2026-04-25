-- ============================================================
--  CLÍNICA DENTAL · SCRIPT LIMPIO Y ORDENADO
--  Ejecutar de arriba a abajo en DBeaver
-- ============================================================


-- ============================================================
--  BLOQUE 0 · LIMPIEZA PREVIA (borrar todo lo existente)
-- ============================================================

-- 1. Tabla de hechos
DROP TABLE IF EXISTS fact_cobros CASCADE;

-- 2. Dimensiones
DROP TABLE IF EXISTS dim_paciente CASCADE;
DROP TABLE IF EXISTS dim_profesional CASCADE;
DROP TABLE IF EXISTS dim_tratamiento CASCADE;
DROP TABLE IF EXISTS dim_tratamiento_fact CASCADE;
DROP TABLE IF EXISTS dim_fecha CASCADE;

-- 3. Vistas
DROP VIEW IF EXISTS vw_facturacion_total;
DROP VIEW IF EXISTS vw_facturacion_mensual;
DROP VIEW IF EXISTS vw_crecimiento_mensual;
DROP VIEW IF EXISTS vw_ingreso_medio_cita;
DROP VIEW IF EXISTS vw_ingreso_medio_paciente;
DROP VIEW IF EXISTS vw_ventas_tratamiento;
DROP VIEW IF EXISTS vw_presupuestos_resumen;
DROP VIEW IF EXISTS vw_estado_citas;
DROP VIEW IF EXISTS vw_pacientes_nuevos;
DROP VIEW IF EXISTS vw_dias_facturacion;
DROP VIEW vw_tasa_aceptacion;
-- 4. Tablas gold
DROP TABLE IF EXISTS citas_gold;
DROP TABLE IF EXISTS cobros_gold;
DROP TABLE IF EXISTS facturas_gold;
DROP TABLE IF EXISTS presupuestos_gold;
DROP TABLE IF EXISTS profesionales_gold;
DROP TABLE IF EXISTS tratamientos_gold;


-- ============================================================
--  BLOQUE 1 · CAPA GOLD (tablas limpias desde silver)
-- ============================================================

CREATE TABLE citas_gold AS
SELECT
    ROW_NUMBER() OVER ()              AS id_cita,
    SPLIT_PART(cita, ' - ', 1)::DATE  AS fecha_cita,
    SPLIT_PART(cita, ' - ', 2)        AS hora_inicio,
    hora_fin,
    estado,
    paciente,
    "teléfono",
    LOWER(profesional)                AS profesional,
    gabinete,
    "tratamiento/s"                   AS tratamiento,
    tipo_de_cita,
    observaciones                     AS observacion
FROM citas_silver;

-- ------------------------------------------------------------

CREATE TABLE cobros_gold AS
SELECT
    id_cobro,
    TO_DATE(fecha_cobro,      'DD/MM/YYYY') AS fecha_cobro,
    TO_DATE(fecha_tratamiento,'DD/MM/YYYY') AS fecha_tratamiento,
    id_paciente,
    tratamiento,
    metodo_de_pago,
    facturado,
    pago_completo,
    pago_pendiente,
    LOWER(profesional)               AS profesional,
    total_cobro::NUMERIC             AS total_cobro
FROM cobros_silver
WHERE total_cobro IS NOT NULL;

-- ------------------------------------------------------------

CREATE TABLE facturas_gold AS
SELECT
    id_factura,
    TO_DATE(fecha_factura,    'DD/MM/YYYY') AS fecha_factura,
    TO_DATE(fecha_tratamiento,'DD/MM/YYYY') AS fecha_tratamiento,
    id_paciente,
    "NIF"                                   AS nif,
    localidad,
    "CP"                                    AS cp,
   
    "tratamiento "                          AS tratamiento,
    dias_hasta_facturacion,
    LOWER(profesional)                      AS profesional,
    metodo_de_pago                          AS metodo_pago,
    importe::NUMERIC                        AS importe,
    "importe_IVA"::NUMERIC                  AS importe_iva
FROM facturas_silver;

-- ------------------------------------------------------------

CREATE TABLE presupuestos_gold AS
SELECT
    NULLIF("id_presupuesto", '')::INTEGER                                        AS id_presupuesto,
    nombre_presupuesto,
    id_paciente,
    LOWER(estado_presupuesto)                                                    AS estado,
    motivo_del_rechazo                                                           AS motivo,
    TO_DATE(fecha_inicio,  'DD/MM/YYYY')                                        AS fecha_presupuesto,
    TO_DATE("Vencimiento", 'DD/MM/YYYY')                                        AS fecha_vencimiento,
    REPLACE(REPLACE(NULLIF(cobro_total,       ''), '.', ''), ',', '.')::NUMERIC  AS importe_presupuesto,
    REPLACE(REPLACE(NULLIF("cobro_total_IVA", ''), '.', ''), ',', '.')::NUMERIC  AS importe_presupuesto_iva
FROM presupuestos_silver
WHERE NULLIF("id_presupuesto", '') IS NOT NULL;

-- ------------------------------------------------------------

CREATE TABLE profesionales_gold AS
SELECT
    ROW_NUMBER() OVER ()                      AS id_profesional,
    LOWER("Nombre")                           AS nombre,
    LOWER("Apellidos")                        AS apellidos,
    LOWER(CONCAT("Nombre", ' ', "Apellidos")) AS profesional
FROM profesionales_silver;

-- ------------------------------------------------------------

CREATE TABLE tratamientos_gold AS
SELECT
    id_tratamiento,
    id_paciente,
    dientes,
    nro_dientes,
    TO_DATE(fecha_inicio, 'DD/MM/YYYY') AS fecha_inicio,
    TO_DATE(fecha_fin,    'DD/MM/YYYY') AS fecha_fin,
    LOWER(profesional)                  AS profesional,
    LOWER(estado_tratamiento)           AS estado_tratamiento
FROM tratamientos_silver;


-- ============================================================
--  BLOQUE 2 · DIMENSIONES
-- ============================================================

CREATE TABLE dim_paciente AS
SELECT
    ROW_NUMBER() OVER (ORDER BY nombre_paciente) AS id_paciente_sk,
    nombre_paciente,
    telefono
FROM (
    SELECT
        LPAD(TRIM(paciente), 5, '0') AS nombre_paciente,
        MAX("teléfono")              AS telefono
    FROM citas_gold
    GROUP BY LPAD(TRIM(paciente), 5, '0')
) t;

-- ------------------------------------------------------------

CREATE TABLE dim_profesional AS
SELECT DISTINCT
    ROW_NUMBER() OVER (ORDER BY id_profesional) AS id_profesional_sk,
    id_profesional,
    CONCAT(nombre, ' ', apellidos)              AS nombre_completo,
    profesional                                 AS tipo_profesional
FROM profesionales_gold;

-- ------------------------------------------------------------

CREATE TABLE dim_tratamiento AS
SELECT
    ROW_NUMBER() OVER (ORDER BY id_tratamiento) AS id_tratamiento_sk,
    id_tratamiento,
    MAX(dientes)            AS tipo_dientes,
    MAX(nro_dientes)        AS numero_dientes,
    MAX(estado_tratamiento) AS estado_tratamiento
FROM tratamientos_gold
GROUP BY id_tratamiento;

-- ------------------------------------------------------------

CREATE TABLE dim_tratamiento_fact AS
SELECT
    ROW_NUMBER() OVER (ORDER BY tratamiento_raw) AS id_tratamiento_fact_sk,
    tratamiento_raw,
    TRIM(SPLIT_PART(tratamiento_raw, ' - ', 2))  AS tratamiento_limpio
FROM (
    SELECT DISTINCT tratamiento AS tratamiento_raw
    FROM facturas_gold
) t;

-- ------------------------------------------------------------

CREATE TABLE dim_fecha AS
SELECT
    d::date               AS fecha,
    EXTRACT(YEAR  FROM d) AS anio,
    EXTRACT(MONTH FROM d) AS mes,
    EXTRACT(DAY   FROM d) AS dia,
    TO_CHAR(d, 'Month')   AS nombre_mes,
    TO_CHAR(d, 'Day')     AS nombre_dia,
    EXTRACT(WEEK  FROM d) AS semana
FROM generate_series(
    '2025-01-01'::date,
    '2027-12-31'::date,
    interval '1 day'
) d;


-- ============================================================
--  BLOQUE 3 · CLAVES PRIMARIAS EN DIMENSIONES
-- ============================================================

ALTER TABLE dim_paciente         ADD PRIMARY KEY (id_paciente_sk);
ALTER TABLE dim_profesional      ADD PRIMARY KEY (id_profesional_sk);
ALTER TABLE dim_tratamiento      ADD PRIMARY KEY (id_tratamiento_sk);
ALTER TABLE dim_tratamiento_fact ADD PRIMARY KEY (id_tratamiento_fact_sk);
ALTER TABLE dim_fecha            ADD PRIMARY KEY (fecha);


-- ============================================================
--  BLOQUE 4 · TABLA DE HECHOS (única)
-- ============================================================

CREATE TABLE fact_cobros AS
SELECT
    ROW_NUMBER() OVER ()       AS id_fact,
    dp.id_paciente_sk,
    dpr.id_profesional_sk,
    dtf.id_tratamiento_fact_sk,
    c.fecha_cobro              AS fecha,
    c.total_cobro              AS ingreso,
    c.metodo_de_pago
FROM cobros_gold c
LEFT JOIN dim_paciente dp
    ON LPAD(c.id_paciente::text, 5, '0') = dp.nombre_paciente
LEFT JOIN dim_profesional dpr
    ON LOWER(TRIM(REPLACE(REPLACE(c.profesional, 'dra. ', ''), 'dr. ', '')))
       = LOWER(TRIM(dpr.tipo_profesional))
LEFT JOIN dim_tratamiento_fact dtf
    ON c.tratamiento = dtf.tratamiento_raw
WHERE c.total_cobro > 0;


-- ============================================================
--  BLOQUE 5 · CLAVES FORÁNEAS EN FACT_COBROS
-- ============================================================

ALTER TABLE fact_cobros
    ADD CONSTRAINT fk_cobros_paciente
    FOREIGN KEY (id_paciente_sk) REFERENCES dim_paciente(id_paciente_sk);

ALTER TABLE fact_cobros
    ADD CONSTRAINT fk_cobros_profesional
    FOREIGN KEY (id_profesional_sk) REFERENCES dim_profesional(id_profesional_sk);

ALTER TABLE fact_cobros
    ADD CONSTRAINT fk_cobros_tratamiento
    FOREIGN KEY (id_tratamiento_fact_sk) REFERENCES dim_tratamiento_fact(id_tratamiento_fact_sk);

ALTER TABLE fact_cobros
    ADD CONSTRAINT fk_cobros_fecha
    FOREIGN KEY (fecha) REFERENCES dim_fecha(fecha);


-- ============================================================
--  BLOQUE 6 · VISTAS PARA KPIs
-- ============================================================

-- Bloque 1: Evolución de la facturación
CREATE VIEW vw_facturacion_total AS
SELECT SUM(ingreso) AS facturacion_total
FROM fact_cobros;

CREATE VIEW vw_facturacion_mensual AS
SELECT
    df.anio,
    df.mes,
    df.nombre_mes,
    SUM(c.ingreso)                                                          AS facturacion,
    SUM(c.ingreso) - LAG(SUM(c.ingreso)) OVER (ORDER BY df.anio, df.mes)  AS crecimiento
FROM fact_cobros c
JOIN dim_fecha df ON c.fecha = df.fecha
GROUP BY df.anio, df.mes, df.nombre_mes
ORDER BY df.anio, df.mes;

CREATE VIEW vw_ingreso_medio_cita AS
SELECT ROUND(AVG(ingreso), 2) AS ingreso_medio_por_cita
FROM fact_cobros;

CREATE VIEW vw_ingreso_medio_paciente AS
SELECT
    dp.nombre_paciente,
    COUNT(*)                 AS num_cobros,
    SUM(c.ingreso)           AS total_ingresos,
    ROUND(AVG(c.ingreso), 2) AS ingreso_medio
FROM fact_cobros c
JOIN dim_paciente dp ON c.id_paciente_sk = dp.id_paciente_sk
GROUP BY dp.nombre_paciente;

-- ------------------------------------------------------------
-- Bloque 2: Tratamientos
CREATE VIEW vw_ventas_tratamiento AS
SELECT
    dtf.tratamiento_limpio,
    COUNT(*)       AS num_ventas,
    SUM(c.ingreso) AS ingresos,
    ROUND(SUM(c.ingreso) * 100.0 / SUM(SUM(c.ingreso)) OVER (), 2) AS pct_ingresos
FROM fact_cobros c
JOIN dim_tratamiento_fact dtf ON c.id_tratamiento_fact_sk = dtf.id_tratamiento_fact_sk
GROUP BY dtf.tratamiento_limpio
ORDER BY ingresos DESC;

-- ------------------------------------------------------------
-- Bloque 3: Presupuestos (desde presupuestos_gold directamente)
CREATE VIEW vw_presupuestos_resumen AS
SELECT
    COUNT(*)                                                           AS total_presupuestos,
    COUNT(CASE WHEN estado = 'accepted' THEN 1 END)                   AS aceptados,
    COUNT(CASE WHEN estado = 'rejected' THEN 1 END)                   AS rechazados,
    ROUND(COUNT(CASE WHEN estado = 'accepted' THEN 1 END) * 100.0
          / COUNT(*), 2)                                               AS tasa_aceptacion,
    ROUND(AVG(CASE WHEN estado = 'accepted' THEN importe_presupuesto END), 2) AS precio_medio_aceptados,
    ROUND(AVG(CASE WHEN estado = 'rejected' THEN importe_presupuesto END), 2) AS precio_medio_rechazados
FROM presupuestos_gold;

-- ------------------------------------------------------------
-- Bloque 4: Estado de citas (desde citas_gold directamente)
CREATE VIEW vw_estado_citas AS
SELECT
    COUNT(*)                                                            AS total_citas,
    COUNT(CASE WHEN estado = 'finalizada'    THEN 1 END)               AS realizadas,
    COUNT(CASE WHEN estado = 'cancelada'     THEN 1 END)               AS canceladas,
    COUNT(CASE WHEN estado = 'sin confirmar' THEN 1 END)               AS noshows,
    ROUND(COUNT(CASE WHEN estado = 'finalizada'    THEN 1 END) * 100.0
          / COUNT(*), 2)                                                AS pct_realizadas,
    ROUND(COUNT(CASE WHEN estado = 'cancelada'     THEN 1 END) * 100.0
          / COUNT(*), 2)                                                AS pct_canceladas,
    ROUND(COUNT(CASE WHEN estado = 'sin confirmar' THEN 1 END) * 100.0
          / COUNT(*), 2)                                                AS pct_noshows
FROM citas_gold;

-- ------------------------------------------------------------
-- Bloque 5: Pacientes nuevos (desde citas_gold directamente)
CREATE VIEW vw_pacientes_nuevos AS
WITH primera_visita AS (
    SELECT
        paciente,
        MIN(fecha_cita) AS primera_fecha
    FROM citas_gold
    GROUP BY paciente
)
SELECT
    EXTRACT(YEAR  FROM primera_fecha) AS anio,
    EXTRACT(MONTH FROM primera_fecha) AS mes,
    COUNT(*) AS nuevos_pacientes
FROM primera_visita
GROUP BY anio, mes
ORDER BY anio, mes;

-- ------------------------------------------------------------
-- Bloque 6: Días hasta facturación (desde facturas_gold directamente)
CREATE VIEW vw_dias_facturacion AS
SELECT
    ROUND(AVG(dias_hasta_facturacion), 1)                                   AS media_dias,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dias_hasta_facturacion)     AS mediana_dias,
    COUNT(CASE WHEN dias_hasta_facturacion = 0  THEN 1 END)                AS facturados_mismo_dia,
    ROUND(COUNT(CASE WHEN dias_hasta_facturacion = 0 THEN 1 END) * 100.0
          / COUNT(*), 2)                                                     AS pct_mismo_dia,
    COUNT(CASE WHEN dias_hasta_facturacion > 30 THEN 1 END)                AS facturados_con_retraso
FROM facturas_gold;


============================================================
--  BLOQUE 7 · CONSULTAS DE ANÁLISIS (KPIs)
-- ============================================================

-- Facturación total
SELECT SUM(ingreso) AS facturacion_total
FROM fact_cobros;

-- Facturación por mes
SELECT
    df.anio,
    df.mes,
    SUM(c.ingreso) AS facturacion
FROM fact_cobros c
JOIN dim_fecha df ON c.fecha = df.fecha
GROUP BY df.anio, df.mes
ORDER BY df.anio, df.mes;

-- Mejores meses
SELECT
    df.anio,
    df.mes,
    SUM(c.ingreso) AS facturacion
FROM fact_cobros c
JOIN dim_fecha df ON c.fecha = df.fecha
GROUP BY df.anio, df.mes
ORDER BY facturacion DESC;

-- Top 5 pacientes por dinero generado
SELECT
    dp.nombre_paciente,
    SUM(c.ingreso)  AS total_gastado,
    COUNT(*)        AS num_cobros
FROM fact_cobros c
JOIN dim_paciente dp ON c.id_paciente_sk = dp.id_paciente_sk
GROUP BY dp.nombre_paciente
ORDER BY total_gastado DESC
LIMIT 5;

-- Pacientes recurrentes (top 5 por número de cobros)
SELECT
    dp.nombre_paciente,
    COUNT(DISTINCT c.id_fact) AS num_cobros,
    SUM(c.ingreso)            AS total_cobrado
FROM fact_cobros c
JOIN dim_paciente dp ON c.id_paciente_sk = dp.id_paciente_sk
GROUP BY dp.nombre_paciente
ORDER BY num_cobros DESC
LIMIT 5;

-- Pacientes nuevos por mes
SELECT
    df.anio,
    df.mes,
    COUNT(DISTINCT c.id_paciente_sk) AS nuevos_pacientes
FROM fact_cobros c
JOIN dim_fecha df ON c.fecha = df.fecha
GROUP BY df.anio, df.mes
ORDER BY df.anio, df.mes;

-- Tratamientos más vendidos
SELECT
    dtf.tratamiento_limpio,
    COUNT(*)       AS num_ventas,
    SUM(c.ingreso) AS ingresos
FROM fact_cobros c
JOIN dim_tratamiento_fact dtf ON c.id_tratamiento_fact_sk = dtf.id_tratamiento_fact_sk
GROUP BY dtf.tratamiento_limpio
ORDER BY ingresos DESC;

-- Ticket medio por tratamiento
SELECT
    dtf.tratamiento_limpio,
    COUNT(*)                   AS num_ventas,
    ROUND(AVG(c.ingreso), 2)   AS ticket_medio
FROM fact_cobros c
JOIN dim_tratamiento_fact dtf ON c.id_tratamiento_fact_sk = dtf.id_tratamiento_fact_sk
GROUP BY dtf.tratamiento_limpio
ORDER BY ticket_medio DESC;

-- Facturación por profesional
SELECT
    dpr.nombre_completo AS profesional,
    SUM(c.ingreso)      AS facturacion
FROM fact_cobros c
JOIN dim_profesional dpr ON c.id_profesional_sk = dpr.id_profesional_sk
GROUP BY dpr.nombre_completo
ORDER BY facturacion DESC;

-- Ingreso medio por paciente
SELECT
    dp.nombre_paciente,
    COUNT(*)                 AS num_cobros,
    SUM(c.ingreso)           AS total_gastado,
    ROUND(AVG(c.ingreso), 2) AS ingreso_medio
FROM fact_cobros c
JOIN dim_paciente dp ON c.id_paciente_sk = dp.id_paciente_sk
GROUP BY dp.nombre_paciente
ORDER BY total_gastado DESC;

-- Ticket medio por cita
SELECT ROUND(AVG(ingreso), 2) AS ticket_medio
FROM fact_cobros;

-- % Estado de citas
SELECT
    estado,
    COUNT(*) AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS porcentaje
FROM citas_gold
GROUP BY estado;

-- Días entre tratamiento y facturación
SELECT
    AVG(dias_hasta_facturacion) AS media_dias,
    MIN(dias_hasta_facturacion) AS min_dias,
    MAX(dias_hasta_facturacion) AS max_dias
FROM facturas_gold;

-- Facturación por método de pago
SELECT
    metodo_de_pago,
    SUM(ingreso) AS total
FROM fact_cobros
GROUP BY metodo_de_pago
ORDER BY total DESC;

