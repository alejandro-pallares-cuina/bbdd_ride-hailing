-- permissions.sql — Usuarios y permisos (MySQL 8 / Docker)
-- Principio de mínimo privilegio: cada usuario solo accede a lo que necesita.
--
-- Usuarios:
--   app_writer      API backend: lectura y escritura operativa
--   app_reader      Dashboard: solo lectura
--   driver_service  Microservicio de conductores: alcance limitado
--   backup_user     Proceso de backup: solo dump, solo desde localhost
--   audit_user      Servicio de auditoría: solo INSERT en audit_log
--   dba_admin       DBA: acceso completo sin GRANT OPTION

USE movilidad;


-- -------------------------------------------------------
-- Limpieza previa (seguro de re-ejecutar)
-- -------------------------------------------------------

DROP USER IF EXISTS 'app_writer'@'%';
DROP USER IF EXISTS 'app_reader'@'%';
DROP USER IF EXISTS 'driver_service'@'%';
DROP USER IF EXISTS 'backup_user'@'localhost';
DROP USER IF EXISTS 'audit_user'@'%';
DROP USER IF EXISTS 'dba_admin'@'%';


-- -------------------------------------------------------
-- 1. app_writer — API backend
-- -------------------------------------------------------
-- Lee y escribe en todas las tablas operativas.
-- Sin DROP, ALTER ni GRANT para evitar daño por inyección SQL.

CREATE USER 'app_writer'@'%'
  IDENTIFIED BY 'Wr1t3r_S3cur3!'
  PASSWORD EXPIRE INTERVAL 90 DAY
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LOCK_TIME 1;

GRANT SELECT, INSERT, UPDATE ON movilidad.company            TO 'app_writer'@'%';
GRANT SELECT, INSERT, UPDATE ON movilidad.user               TO 'app_writer'@'%';
GRANT SELECT, INSERT, UPDATE ON movilidad.driver             TO 'app_writer'@'%';
GRANT SELECT, INSERT, UPDATE ON movilidad.vehicle            TO 'app_writer'@'%';
GRANT SELECT, INSERT, UPDATE ON movilidad.trip               TO 'app_writer'@'%';
GRANT SELECT, INSERT, UPDATE ON movilidad.offer              TO 'app_writer'@'%';
GRANT SELECT, INSERT        ON movilidad.trip_status_history TO 'app_writer'@'%';
GRANT INSERT                ON movilidad.audit_log           TO 'app_writer'@'%';


-- -------------------------------------------------------
-- 2. app_reader — Dashboard y reporting
-- -------------------------------------------------------
-- Solo SELECT. Si las credenciales se filtran, nadie puede modificar datos.

CREATE USER 'app_reader'@'%'
  IDENTIFIED BY 'R3ad3r_S3cur3!'
  PASSWORD EXPIRE INTERVAL 90 DAY
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LOCK_TIME 1;

GRANT SELECT ON movilidad.company            TO 'app_reader'@'%';
GRANT SELECT ON movilidad.user               TO 'app_reader'@'%';
GRANT SELECT ON movilidad.driver             TO 'app_reader'@'%';
GRANT SELECT ON movilidad.vehicle            TO 'app_reader'@'%';
GRANT SELECT ON movilidad.trip               TO 'app_reader'@'%';
GRANT SELECT ON movilidad.offer              TO 'app_reader'@'%';
GRANT SELECT ON movilidad.trip_status_history TO 'app_reader'@'%';
GRANT SELECT ON movilidad.audit_log          TO 'app_reader'@'%';


-- -------------------------------------------------------
-- 3. driver_service — Microservicio de conductores
-- -------------------------------------------------------
-- Solo gestiona conductores y vehículos. No accede a viajes ni a riders.

CREATE USER 'driver_service'@'%'
  IDENTIFIED BY 'Dr1v3r_S3rv1c3!'
  PASSWORD EXPIRE INTERVAL 90 DAY
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LOCK_TIME 1;

GRANT SELECT, INSERT, UPDATE ON movilidad.driver  TO 'driver_service'@'%';
GRANT SELECT, INSERT, UPDATE ON movilidad.vehicle TO 'driver_service'@'%';
GRANT SELECT                 ON movilidad.company TO 'driver_service'@'%';
GRANT SELECT                 ON movilidad.user    TO 'driver_service'@'%';


-- -------------------------------------------------------
-- 4. backup_user — Proceso de backup
-- -------------------------------------------------------
-- Solo puede conectarse desde localhost.
-- Necesita PROCESS y RELOAD para que mysqldump funcione correctamente.

CREATE USER 'backup_user'@'localhost'
  IDENTIFIED BY 'B4ckUp_S3cur3!'
  PASSWORD EXPIRE INTERVAL 180 DAY;

GRANT PROCESS, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'backup_user'@'localhost';
GRANT SELECT ON movilidad.*                                    TO 'backup_user'@'localhost';
GRANT EXECUTE ON PROCEDURE movilidad.sp_backup_snapshot        TO 'backup_user'@'localhost';


-- -------------------------------------------------------
-- 5. audit_user — Servicio de auditoría
-- -------------------------------------------------------
-- Solo puede insertar en audit_log. Nunca leer ni modificar.

CREATE USER 'audit_user'@'%'
  IDENTIFIED BY 'Aud1t_S3cur3!'
  PASSWORD EXPIRE INTERVAL 90 DAY
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LOCK_TIME 1;

GRANT INSERT ON movilidad.audit_log TO 'audit_user'@'%';


-- -------------------------------------------------------
-- 6. dba_admin — Administrador de base de datos
-- -------------------------------------------------------
-- Acceso completo para mantenimiento y recuperación.
-- Sin GRANT OPTION: no puede delegar permisos a otros usuarios.

CREATE USER 'dba_admin'@'%'
  IDENTIFIED BY 'Dba_Adm1n_S3cur3!'
  PASSWORD EXPIRE INTERVAL 60 DAY
  FAILED_LOGIN_ATTEMPTS 3
  PASSWORD_LOCK_TIME 2;

GRANT ALL PRIVILEGES ON movilidad.*   TO 'dba_admin'@'%';
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'dba_admin'@'%';


-- -------------------------------------------------------
-- Aplicar cambios
-- -------------------------------------------------------

FLUSH PRIVILEGES;


-- -------------------------------------------------------
-- Verificación: estado de los usuarios creados
-- -------------------------------------------------------

SELECT
    u.User                AS usuario,
    u.Host                AS host,
    u.password_expired    AS pwd_expirada,
    u.password_lifetime   AS dias_expiracion,
    u.account_locked      AS cuenta_bloqueada
FROM mysql.user u
WHERE u.User IN ('app_writer', 'app_reader', 'driver_service', 'backup_user', 'audit_user', 'dba_admin')
ORDER BY u.User;

-- Ver permisos detallados:
-- SHOW GRANTS FOR 'app_writer'@'%';
-- SHOW GRANTS FOR 'app_reader'@'%';
-- SHOW GRANTS FOR 'driver_service'@'%';
-- SHOW GRANTS FOR 'backup_user'@'localhost';
-- SHOW GRANTS FOR 'audit_user'@'%';
-- SHOW GRANTS FOR 'dba_admin'@'%';


-- -------------------------------------------------------
-- Notas para producción
-- -------------------------------------------------------
-- - Las contraseñas deben inyectarse como secrets en Docker Compose,
--   no hardcodeadas en este fichero.
-- - Restringir el host '%' a la red interna Docker en producción.
-- - Forzar TLS: ALTER USER 'app_writer'@'%' REQUIRE SSL;
