-- queries.sql — Consultas para la operativa (MySQL 8 / InnoDB)
-- Base de datos: movilidad
-- Este fichero contiene consultas CRUD y flujos operativos:
-- - Alta de usuarios, conductores, vehículos
-- - Solicitud de viajes
-- - Creación de ofertas
-- - Aceptación / rechazo / expiración de ofertas
-- - Transiciones de estado del viaje con historial
-- - Auditoría básica en audit_log

USE movilidad;

-- Recomendación: evitar lecturas sucias en operativa
-- (InnoDB por defecto usa REPEATABLE READ; READ COMMITTED suele ir bien para APIs).
-- Ajustad según necesidad.
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- -------------------------------------------------------------------
-- 0) Utilidades comunes
-- -------------------------------------------------------------------

-- 0.1 Insertar auditoría (patrón)
-- INSERT INTO audit_log(entidad, id_entidad, accion) VALUES ('trip', 123, 'CREATED');

-- 0.2 Registrar historial de estado de viaje (patrón)
-- INSERT INTO trip_status_history(id_trip, estado) VALUES (123, 'solicitado');

-- -------------------------------------------------------------------
-- 1) Usuarios (riders / drivers)
-- Tablas: user(id_user, nombre, email, rol, ...)
-- -------------------------------------------------------------------

-- 1.1 Crear rider
-- Parámetros: (nombre, email)
INSERT INTO user (nombre, email, rol)
VALUES (?, ?, 'rider');

-- (opcional) auditoría del alta
-- SET @new_user_id = LAST_INSERT_ID();
-- INSERT INTO audit_log(entidad, id_entidad, accion) VALUES ('user', @new_user_id, 'CREATED_RIDER');

-- 1.2 Crear driver (usuario + fila en driver) en una transacción
-- Parámetros: (nombre, email, id_company)
START TRANSACTION;

INSERT INTO user (nombre, email, rol)
VALUES (?, ?, 'driver');

SET @new_driver_user_id = LAST_INSERT_ID();

INSERT INTO driver (id_driver, id_company, rating)
VALUES (@new_driver_user_id, ?, 5.0);

INSERT INTO audit_log(entidad, id_entidad, accion)
VALUES ('user', @new_driver_user_id, 'CREATED_DRIVER_USER'),
       ('driver', @new_driver_user_id, 'CREATED_DRIVER');

COMMIT;

-- 1.3 Obtener usuario por email (login / validación)
SELECT id_user, nombre, email, rol, created_at, updated_at
FROM user
WHERE email = ?;

-- -------------------------------------------------------------------
-- 2) Companies
-- Tabla: company(id_company, nombre, ...) 
-- -------------------------------------------------------------------

-- 2.1 Crear company
INSERT INTO company (nombre) VALUES (?);

-- 2.2 Listar companies
SELECT id_company, nombre, created_at, updated_at
FROM company
ORDER BY nombre;

-- -------------------------------------------------------------------
-- 3) Vehículos
-- Tabla: vehicle(id_vehicle, id_driver, matricula, modelo, ...)
-- -------------------------------------------------------------------

-- 3.1 Registrar vehículo para un driver
-- Parámetros: (id_driver, matricula, modelo)
INSERT INTO vehicle (id_driver, matricula, modelo)
VALUES (?, ?, ?);

INSERT INTO audit_log(entidad, id_entidad, accion)
VALUES ('vehicle', LAST_INSERT_ID(), 'CREATED_VEHICLE');

-- 3.2 Listar vehículos de un conductor
SELECT v.id_vehicle, v.matricula, v.modelo, v.created_at
FROM vehicle v
WHERE v.id_driver = ?
ORDER BY v.created_at DESC;

-- -------------------------------------------------------------------
-- 4) Viajes (trips)
-- Tabla: trip(id_trip, id_rider, id_driver, estado, origen/destino, ... ) schema
-- Historial: trip_status_history(...)  schema
-- -------------------------------------------------------------------

-- 4.1 Solicitar viaje (crear trip en estado 'solicitado' + historial + auditoría)
-- Parámetros: (id_rider, origen_lat, origen_lng, destino_lat, destino_lng)
START TRANSACTION;

INSERT INTO trip (
  id_rider,
  id_driver,
  estado,
  origen_lat, origen_lng,
  destino_lat, destino_lng
) VALUES (
  ?,
  NULL,
  'solicitado',
  ?, ?,
  ?, ?
);

SET @new_trip_id = LAST_INSERT_ID();

INSERT INTO trip_status_history (id_trip, estado)
VALUES (@new_trip_id, 'solicitado');

INSERT INTO audit_log(entidad, id_entidad, accion)
VALUES ('trip', @new_trip_id, 'CREATED_TRIP_REQUEST');

COMMIT;

-- 4.2 Ver detalle de un viaje
SELECT
  t.id_trip, t.id_rider, t.id_driver, t.estado,
  t.origen_lat, t.origen_lng, t.destino_lat, t.destino_lng,
  t.distancia_km, t.duracion_min, t.precio_eur,
  t.created_at, t.accepted_at, t.started_at, t.finished_at
FROM trip t
WHERE t.id_trip = ?;

-- 4.3 Listar viajes de un rider (más recientes primero)
SELECT
  t.id_trip, t.estado, t.created_at, t.accepted_at, t.started_at, t.finished_at,
  t.id_driver, t.distancia_km, t.duracion_min, t.precio_eur
FROM trip t
WHERE t.id_rider = ?
ORDER BY t.created_at DESC
LIMIT ? OFFSET ?;

-- 4.4 Listar viajes asignados a un driver (operativa del conductor)
SELECT
  t.id_trip, t.estado, t.created_at, t.accepted_at, t.started_at, t.finished_at,
  t.id_rider, t.distancia_km, t.duracion_min, t.precio_eur
FROM trip t
WHERE t.id_driver = ?
ORDER BY t.created_at DESC
LIMIT ? OFFSET ?;

-- -------------------------------------------------------------------
-- 5) Ofertas (offers)
-- Tabla: offer(id_offer, id_trip, id_driver, estado, ...)  schema
-- Importante: UNIQUE(id_trip, id_driver) evita duplicar oferta por driver schema
-- -------------------------------------------------------------------

-- 5.1 Crear ofertas para un viaje a una lista de conductores
-- Opción A: multi-values (cuando ya tenéis la lista en la app)
-- Parámetros: (id_trip, id_driver_1) ... (id_trip, id_driver_n)
-- INSERT INTO offer (id_trip, id_driver) VALUES (?, ?), (?, ?), ...;

-- Opción B: crear ofertas desde un SELECT (cuando la selección se hace en SQL)
-- Ejemplo: enviar a N conductores mejor valorados de una company concreta
-- Parámetros: (id_trip, id_company, N)
INSERT INTO offer (id_trip, id_driver)
SELECT
  ? AS id_trip,
  d.id_driver
FROM driver d
WHERE d.id_company = ?
ORDER BY d.rating DESC
LIMIT ?;

-- 5.2 Obtener ofertas pendientes de un driver (bandeja del conductor)
SELECT
  o.id_offer, o.id_trip, o.estado AS estado_oferta, o.created_at AS oferta_creada,
  t.estado AS estado_viaje,
  t.origen_lat, t.origen_lng, t.destino_lat, t.destino_lng,
  t.created_at AS viaje_creado
FROM offer o
JOIN trip t ON t.id_trip = o.id_trip
WHERE o.id_driver = ?
  AND o.estado = 'pendiente'
ORDER BY o.created_at ASC
LIMIT ?;

-- 5.3 Rechazar una oferta (driver)
-- Parámetros: (id_offer, id_driver)
START TRANSACTION;

UPDATE offer
SET estado = 'rechazada',
    responded_at = NOW()
WHERE id_offer = ?
  AND id_driver = ?
  AND estado = 'pendiente';

INSERT INTO audit_log(entidad, id_entidad, accion)
VALUES ('offer', ?, 'REJECTED_BY_DRIVER');

COMMIT;

-- 5.4 Expirar ofertas antiguas (job/cron)
-- Parámetros: (minutos_expiracion)
UPDATE offer
SET estado = 'expirada',
    responded_at = NOW()
WHERE estado = 'pendiente'
  AND created_at < NOW() - INTERVAL ? MINUTE;

-- -------------------------------------------------------------------
-- 6) Aceptación de oferta (CRÍTICO: concurrencia + lock)
-- Garantiza: solo el primero que acepta asigna el trip y se queda el viaje.
-- Tablas afectadas: trip, offer, trip_status_history, audit_log  schema
-- -------------------------------------------------------------------

-- 6.1 Aceptar oferta (patrón transaccional)
-- Parámetros:
--   (id_trip, id_offer, id_driver)
--
-- IMPORTANTE PARA LA APP:
-- Tras el UPDATE del trip, comprobar ROW_COUNT():
--   - Si ROW_COUNT() = 1 -> aceptación ganada (COMMIT)
--   - Si ROW_COUNT() = 0 -> alguien se adelantó o el viaje no está "solicitado" (ROLLBACK)
--
-- Razón:
-- - SELECT ... FOR UPDATE bloquea la fila de trip durante la transacción.
-- - UPDATE condicional (estado='solicitado' AND id_driver IS NULL) solo puede tener éxito una vez.
START TRANSACTION;

-- Bloquea el viaje para evitar carreras (InnoDB row lock)
SELECT id_trip, estado, id_driver
FROM trip
WHERE id_trip = ?
FOR UPDATE;

-- Intento de asignación atómica del viaje al conductor que acepta
UPDATE trip
SET id_driver = ?,
    estado = 'aceptado',
    accepted_at = NOW()
WHERE id_trip = ?
  AND estado = 'solicitado'
  AND id_driver IS NULL;

-- La app debe leer ROW_COUNT() aquí:
-- SELECT ROW_COUNT() AS affected;

-- Si la app detecta éxito (affected = 1), entonces:
-- 1) marcar la oferta como aceptada
UPDATE offer
SET estado = 'aceptada',
    responded_at = NOW()
WHERE id_offer = ?
  AND id_trip = ?
  AND id_driver = ?
  AND estado = 'pendiente';

-- 2) cerrar el resto de ofertas pendientes del mismo viaje (rechazadas por sistema)
UPDATE offer
SET estado = 'rechazada',
    responded_at = NOW()
WHERE id_trip = ?
  AND id_offer <> ?
  AND estado = 'pendiente';

-- 3) historial + auditoría
INSERT INTO trip_status_history (id_trip, estado)
VALUES (?, 'aceptado');

INSERT INTO audit_log(entidad, id_entidad, accion)
VALUES ('trip', ?, 'ACCEPTED'),
       ('offer', ?, 'OFFER_ACCEPTED');

COMMIT;

-- Si la app detecta ROW_COUNT() = 0 después del UPDATE trip, ejecutar:
-- ROLLBACK;
-- (y opcionalmente marcar la oferta como expirada o rechazada por "ya asignado")

-- -------------------------------------------------------------------
-- 7) Transiciones del viaje: en_curso, finalizado, cancelado
-- -------------------------------------------------------------------

-- 7.1 Iniciar viaje (driver)
-- Parámetros: (id_trip, id_driver)
START TRANSACTION;

UPDATE trip
SET estado = 'en_curso',
    started_at = NOW()
WHERE id_trip = ?
  AND id_driver = ?
  AND estado = 'aceptado';

INSERT INTO trip_status_history(id_trip, estado)
VALUES (?, 'en_curso');

INSERT INTO audit_log(entidad, id_entidad, accion)
VALUES ('trip', ?, 'STARTED');

COMMIT;

-- 7.2 Finalizar viaje (driver)
-- Parámetros: (id_trip, id_driver, distancia_km, duracion_min, precio_eur)
START TRANSACTION;

UPDATE trip
SET estado = 'finalizado',
    finished_at = NOW(),
    distancia_km = ?,
    duracion_min = ?,
    precio_eur = ?
WHERE id_trip = ?
  AND id_driver = ?
  AND estado = 'en_curso';

INSERT INTO trip_status_history(id_trip, estado)
VALUES (?, 'finalizado');

INSERT INTO audit_log(entidad, id_entidad, accion)
VALUES ('trip', ?, 'FINISHED');

COMMIT;

-- 7.3 Cancelar viaje (rider) si aún no ha empezado
-- Reglas típicas:
-- - Si está 'solicitado': cancelar y expirar ofertas.
-- - Si está 'aceptado': cancelar (opcional: penalización) y cerrar ofertas.
-- Parámetros: (id_trip, id_rider)
START TRANSACTION;

-- Bloqueo del viaje para consistencia en cancelación
SELECT id_trip, estado, id_driver
FROM trip
WHERE id_trip = ?
  AND id_rider = ?
FOR UPDATE;

UPDATE trip
SET estado = 'cancelado'
WHERE id_trip = ?
  AND id_rider = ?
  AND estado IN ('solicitado', 'aceptado');

-- cerrar ofertas pendientes si las hubiera
UPDATE offer
SET estado = 'expirada',
    responded_at = NOW()
WHERE id_trip = ?
  AND estado = 'pendiente';

INSERT INTO trip_status_history(id_trip, estado)
VALUES (?, 'cancelado');

INSERT INTO audit_log(entidad, id_entidad, accion)
VALUES ('trip', ?, 'CANCELLED_BY_RIDER');

COMMIT;

-- -------------------------------------------------------------------
-- 8) Consultas operativas “rápidas” (soporte / backoffice básico)
-- -------------------------------------------------------------------

-- 8.1 Ver historial de estados de un viaje
SELECT id_history, id_trip, estado, created_at
FROM trip_status_history
WHERE id_trip = ?
ORDER BY created_at ASC;

-- 8.2 Ver ofertas de un viaje (para debugging/operativa)
SELECT id_offer, id_trip, id_driver, estado, created_at, responded_at
FROM offer
WHERE id_trip = ?
ORDER BY created_at ASC;

-- 8.3 Últimos eventos de auditoría de una entidad
-- Parámetros: (entidad, id_entidad)
SELECT id_log, entidad, id_entidad, accion, created_at
FROM audit_log
WHERE entidad = ?
  AND id_entidad = ?
ORDER BY created_at DESC
LIMIT 50;

-- 8.4 Viajes “activos” (solicitado/aceptado/en_curso) para monitorización operativa
SELECT id_trip, id_rider, id_driver, estado, created_at, accepted_at, started_at
FROM trip
WHERE estado IN ('solicitado', 'aceptado', 'en_curso')
ORDER BY created_at DESC
LIMIT 200;