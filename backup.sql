-- backup.sql — Plan de backup y recuperación (MySQL 8 / Docker)
-- RPO: <= 1 hora | RTO: <= 2 horas

USE movilidad;


-- -------------------------------------------------------
-- 0. Activar binary log (añadir en my.cnf)
-- -------------------------------------------------------
-- [mysqld]
-- server-id        = 1
-- log_bin          = /var/log/mysql/mysql-bin.log
-- binlog_format    = ROW
-- expire_logs_days = 7
-- sync_binlog      = 1

-- Verificar que está activo:
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_format';


-- -------------------------------------------------------
-- 1. Backup completo diario (mysqldump, cada día a las 02:00)
-- -------------------------------------------------------
-- mysqldump \
--   --host=127.0.0.1 --port=3306 \
--   --user=backup_user --password=<PASSWORD> \
--   --single-transaction \   -- snapshot sin bloquear escrituras (MVCC)
--   --flush-logs \           -- abre un nuevo binlog tras el dump
--   --master-data=2 \        -- anota la posición binlog en el dump
--   --routines --triggers --events \
--   movilidad \
-- | gzip > /backups/daily/movilidad_$(date +%F).sql.gz
--
-- Retención: 14 días
-- Rotación:  find /backups/daily -name "*.sql.gz" -mtime +14 -delete


-- -------------------------------------------------------
-- 2. Backup incremental por hora (binary log)
-- -------------------------------------------------------
-- Permite recuperar hasta el minuto exacto del fallo (PITR).
--
-- mysqladmin --user=backup_user --password=<PASSWORD> flush-logs
-- rsync -av /var/log/mysql/mysql-bin.* /backups/incremental/
--
-- Retención: 7 días


-- -------------------------------------------------------
-- 3. Snapshot del estado antes de cada backup
-- -------------------------------------------------------

DROP PROCEDURE IF EXISTS sp_backup_snapshot;

DELIMITER $$
CREATE PROCEDURE sp_backup_snapshot()
BEGIN
    -- Cuenta filas de cada tabla como punto de control
    SELECT 'company'            AS tabla, COUNT(*) AS filas FROM company          UNION ALL
    SELECT 'user',                        COUNT(*) FROM user                       UNION ALL
    SELECT 'driver',                      COUNT(*) FROM driver                     UNION ALL
    SELECT 'vehicle',                     COUNT(*) FROM vehicle                    UNION ALL
    SELECT 'trip',                        COUNT(*) FROM trip                       UNION ALL
    SELECT 'offer',                       COUNT(*) FROM offer                      UNION ALL
    SELECT 'audit_log',                   COUNT(*) FROM audit_log                  UNION ALL
    SELECT 'trip_status_history',         COUNT(*) FROM trip_status_history;

    SHOW MASTER STATUS;
END$$
DELIMITER ;

-- Uso: CALL sp_backup_snapshot();
-- Salida redirigida a /backups/logs/snapshot_YYYY-MM-DD.log


-- -------------------------------------------------------
-- 4. Verificación del backup restaurado
-- -------------------------------------------------------
-- Se ejecuta cada domingo al restaurar el dump en una BD de prueba.

DROP PROCEDURE IF EXISTS sp_verify_backup;

DELIMITER $$
CREATE PROCEDURE sp_verify_backup()
BEGIN
    DECLARE v_trips  BIGINT DEFAULT 0;
    DECLARE v_users  BIGINT DEFAULT 0;
    DECLARE v_offers BIGINT DEFAULT 0;
    DECLARE v_ok     TINYINT DEFAULT 1;

    SELECT COUNT(*) INTO v_trips  FROM trip;
    SELECT COUNT(*) INTO v_users  FROM user;
    SELECT COUNT(*) INTO v_offers FROM offer;

    IF v_users = 0 THEN
        SET v_ok = 0;
        SELECT 'ERROR: tabla user vacía' AS resultado;
    END IF;

    IF v_trips = 0 THEN
        SET v_ok = 0;
        SELECT 'ERROR: tabla trip vacía' AS resultado;
    END IF;

    -- Comprueba que no hay ofertas sin viaje asociado
    IF EXISTS (
        SELECT 1 FROM offer o
        LEFT JOIN trip t ON t.id_trip = o.id_trip
        WHERE t.id_trip IS NULL LIMIT 1
    ) THEN
        SET v_ok = 0;
        SELECT 'ERROR: ofertas sin viaje asociado' AS resultado;
    END IF;

    IF v_ok = 1 THEN
        SELECT CONCAT('OK: ', v_users, ' usuarios, ', v_trips, ' viajes, ', v_offers, ' ofertas') AS resultado;
    END IF;
END$$
DELIMITER ;

-- Uso: CALL sp_verify_backup();


-- -------------------------------------------------------
-- 5. Recuperación punto-en-tiempo (PITR)
-- -------------------------------------------------------
-- Ejemplo: fallo a las 14:37, último backup a las 02:00.
--
-- Paso 1 — Restaurar el backup diario:
--   gunzip < /backups/daily/movilidad_2025-05-10.sql.gz | mysql -u root -p movilidad
--
-- Paso 2 — Localizar la posición del fallo en el binlog:
--   mysqlbinlog /backups/incremental/mysql-bin.000042 | grep -A2 "14:3[5-7]"
--
-- Paso 3 — Aplicar binlogs hasta justo antes del fallo (ej. posición 198432):
--   mysqlbinlog \
--     --start-datetime="2025-05-10 02:00:00" \
--     --stop-position=198432 \
--     /backups/incremental/mysql-bin.000040 \
--     /backups/incremental/mysql-bin.000041 \
--     /backups/incremental/mysql-bin.000042 \
--   | mysql -u root -p movilidad
--
-- Paso 4 — Verificar: CALL sp_verify_backup();


-- -------------------------------------------------------
-- 6. Política de retención
-- -------------------------------------------------------
-- Tipo                  Frecuencia    Retención   Ruta
-- Completo (mysqldump)  Diario 02:00  14 días     /backups/daily/
-- Incremental (binlog)  Horario       7 días      /backups/incremental/
-- Snapshot              Diario 02:00  30 días     /backups/logs/
-- Restore test          Dom 04:00     --          BD temporal aislada
--
-- Los backups deben almacenarse en un volumen externo (NAS / S3 / GCS).


-- -------------------------------------------------------
-- 7. Limpieza automática de audit_log (cada 90 días)
-- -------------------------------------------------------

SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS ev_purge_audit_log;

CREATE EVENT ev_purge_audit_log
  ON SCHEDULE EVERY 1 DAY
  STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
  DO
    DELETE FROM audit_log
    WHERE created_at < NOW() - INTERVAL 90 DAY;

-- SHOW EVENTS FROM movilidad;


-- -------------------------------------------------------
-- 8. Detección de viajes sin registro de auditoría
-- -------------------------------------------------------

SELECT
    t.id_trip,
    t.estado,
    t.finished_at,
    MAX(al.created_at) AS ultimo_log
FROM trip t
LEFT JOIN audit_log al ON al.entidad = 'trip' AND al.id_entidad = t.id_trip
WHERE t.estado = 'finalizado'
GROUP BY t.id_trip, t.estado, t.finished_at
HAVING ultimo_log IS NULL OR ultimo_log < t.finished_at
ORDER BY t.finished_at DESC
LIMIT 50;
