-- Datos de ejemplo (ficticios) para la Actividad 07.
-- Se ejecuta conectado a la base de datos propia, con psql o con pgAdmin:
--   psql "host=... dbname=... user=postgres sslmode=require" -f datos-dummy.sql
-- Se puede ejecutar varias veces: no duplica filas ni borra las que se agreguen después.

CREATE SCHEMA IF NOT EXISTS universidad;

CREATE TABLE IF NOT EXISTS universidad.estudiantes (
    id         SERIAL PRIMARY KEY,
    codigo     VARCHAR(10)  NOT NULL UNIQUE,
    nombre     VARCHAR(100) NOT NULL,
    correo     VARCHAR(120) NOT NULL UNIQUE,
    programa   VARCHAR(60)  NOT NULL,
    semestre   SMALLINT     NOT NULL CHECK (semestre BETWEEN 1 AND 10),
    creado_en  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS universidad.cursos (
    id        SERIAL PRIMARY KEY,
    codigo    VARCHAR(10)  NOT NULL UNIQUE,
    nombre    VARCHAR(100) NOT NULL,
    creditos  SMALLINT     NOT NULL CHECK (creditos > 0)
);

CREATE TABLE IF NOT EXISTS universidad.inscripciones (
    estudiante_id  INT          NOT NULL REFERENCES universidad.estudiantes (id),
    curso_id       INT          NOT NULL REFERENCES universidad.cursos (id),
    periodo        VARCHAR(7)   NOT NULL,
    nota           NUMERIC(2,1) CHECK (nota BETWEEN 0 AND 5),
    PRIMARY KEY (estudiante_id, curso_id, periodo)
);

INSERT INTO universidad.estudiantes (codigo, nombre, correo, programa, semestre) VALUES
    ('E001', 'Ana Gómez',       'ana.gomez@ejemplo.edu',       'Ingeniería de Sistemas',    6),
    ('E002', 'Luis Martínez',   'luis.martinez@ejemplo.edu',   'Ingeniería de Sistemas',    7),
    ('E003', 'María Rodríguez', 'maria.rodriguez@ejemplo.edu', 'Ingeniería Electrónica',    5),
    ('E004', 'Carlos Pérez',    'carlos.perez@ejemplo.edu',    'Ingeniería Industrial',     8),
    ('E005', 'Laura Torres',    'laura.torres@ejemplo.edu',    'Ingeniería de Sistemas',    6),
    ('E006', 'Andrés López',    'andres.lopez@ejemplo.edu',    'Ingeniería Electrónica',    9),
    ('E007', 'Sofía Ramírez',   'sofia.ramirez@ejemplo.edu',   'Ingeniería Industrial',     4),
    ('E008', 'Jorge Castro',    'jorge.castro@ejemplo.edu',    'Ingeniería de Sistemas',    7)
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO universidad.cursos (codigo, nombre, creditos) VALUES
    ('INF301', 'Infraestructura en la nube', 3),
    ('BD201',  'Bases de datos',             4),
    ('RED202', 'Redes de computadores',      3),
    ('SO210',  'Sistemas operativos',        3)
ON CONFLICT (codigo) DO NOTHING;

-- Las inscripciones se escriben con los códigos, no con los id numéricos
INSERT INTO universidad.inscripciones (estudiante_id, curso_id, periodo, nota)
SELECT e.id, c.id, v.periodo, v.nota
FROM (VALUES
    ('E001', 'INF301', '2026-2', 4.5),
    ('E001', 'BD201',  '2026-2', 4.0),
    ('E002', 'INF301', '2026-2', 3.8),
    ('E002', 'RED202', '2026-2', 3.2),
    ('E003', 'BD201',  '2026-2', 4.7),
    ('E003', 'SO210',  '2026-2', 2.9),
    ('E004', 'INF301', '2026-2', 3.5),
    ('E005', 'INF301', '2026-2', 4.9),
    ('E005', 'BD201',  '2026-2', 4.2),
    ('E006', 'RED202', '2026-2', 3.0),
    ('E007', 'SO210',  '2026-2', NULL),
    ('E008', 'BD201',  '2026-2', 2.5)
) AS v (est, cur, periodo, nota)
JOIN universidad.estudiantes e ON e.codigo = v.est
JOIN universidad.cursos      c ON c.codigo = v.cur
ON CONFLICT DO NOTHING;

-- Vista para consultar las notas sin escribir los JOIN cada vez
CREATE OR REPLACE VIEW universidad.v_notas AS
SELECT e.codigo AS cod_estudiante, e.nombre AS estudiante,
       c.codigo AS cod_curso, c.nombre AS curso,
       i.periodo, i.nota
FROM universidad.inscripciones i
JOIN universidad.estudiantes e ON e.id = i.estudiante_id
JOIN universidad.cursos      c ON c.id = i.curso_id;

-- Resumen al terminar
SELECT 'estudiantes' AS tabla, count(*) AS filas FROM universidad.estudiantes
UNION ALL SELECT 'cursos',        count(*) FROM universidad.cursos
UNION ALL SELECT 'inscripciones', count(*) FROM universidad.inscripciones;
