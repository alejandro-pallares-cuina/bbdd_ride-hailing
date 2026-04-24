-- Creacion del esquema
CREATE DATABASE IF NOT EXISTS movilidad
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE movilidad;

-- Tabla de Compañias
CREATE TABLE company (
  id_company   BIGINT       NOT NULL AUTO_INCREMENT,
  nombre       VARCHAR(120) NOT NULL,

  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                 ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id_company),
  UNIQUE KEY uk_company_nombre (nombre)
) ENGINE=InnoDB;

-- Tabla de Usuarios
CREATE TABLE user (
  id_user      BIGINT       NOT NULL AUTO_INCREMENT,
  nombre       VARCHAR(80)  NOT NULL,
  email        VARCHAR(120) NOT NULL,
  rol          ENUM('rider','driver') NOT NULL,

  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                 ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id_user),
  UNIQUE KEY uk_user_email (email)
) ENGINE=InnoDB;

-- Tabla de Conductores
CREATE TABLE driver (
  id_driver    BIGINT NOT NULL,
  id_company   BIGINT NOT NULL,
  rating       DECIMAL(2,1) DEFAULT 5.0,

  PRIMARY KEY (id_driver),

  CONSTRAINT fk_driver_user
    FOREIGN KEY (id_driver)
    REFERENCES user(id_user)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_driver_company
    FOREIGN KEY (id_company)
    REFERENCES company(id_company)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Tabla de Vehículos
CREATE TABLE vehicle (
  id_vehicle   BIGINT       NOT NULL AUTO_INCREMENT,
  id_driver    BIGINT       NOT NULL,
  matricula    VARCHAR(20)  NOT NULL,
  modelo       VARCHAR(80)  NOT NULL,

  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (id_vehicle),
  UNIQUE KEY uk_vehicle_matricula (matricula),

  CONSTRAINT fk_vehicle_driver
    FOREIGN KEY (id_driver)
    REFERENCES driver(id_driver)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Tabla de Viajes
CREATE TABLE trip (
  id_trip       BIGINT NOT NULL AUTO_INCREMENT,

  id_rider      BIGINT NOT NULL,
  id_driver     BIGINT NULL,

  estado ENUM(
    'solicitado',
    'aceptado',
    'en_curso',
    'finalizado',
    'cancelado'
  ) NOT NULL, 

  origen_lat DECIMAL(9,6) NOT NULL,
  origen_lng DECIMAL(9,6) NOT NULL,
  destino_lat DECIMAL(9,6) NOT NULL,
  destino_lng DECIMAL(9,6) NOT NULL,

  distancia_km DECIMAL(6,2),
  duracion_min DECIMAL(6,2),
  precio_eur   DECIMAL(8,2),

  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  accepted_at  DATETIME,
  started_at   DATETIME,
  finished_at  DATETIME,

  PRIMARY KEY (id_trip),

  INDEX idx_trip_rider (id_rider),
  INDEX idx_trip_driver (id_driver),
  INDEX idx_trip_estado_fecha (estado, created_at),

  CONSTRAINT fk_trip_rider
    FOREIGN KEY (id_rider)
    REFERENCES user(id_user)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_trip_driver
    FOREIGN KEY (id_driver)
    REFERENCES driver(id_driver)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
-- Tabla de Ofertas
CREATE TABLE offer (
  id_offer     BIGINT NOT NULL AUTO_INCREMENT,
  id_trip      BIGINT NOT NULL,
  id_driver    BIGINT NOT NULL,

  estado ENUM(
    'pendiente',
    'aceptada',
    'rechazada',
    'expirada'
  ) NOT NULL DEFAULT 'pendiente',

  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  responded_at DATETIME,

  PRIMARY KEY (id_offer),

  UNIQUE KEY uk_offer_trip_driver (id_trip, id_driver),

  INDEX idx_offer_trip (id_trip),
  INDEX idx_offer_driver (id_driver),
  INDEX idx_offer_estado (estado),

  CONSTRAINT fk_offer_trip
    FOREIGN KEY (id_trip)
    REFERENCES trip(id_trip)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_offer_driver
    FOREIGN KEY (id_driver)
    REFERENCES driver(id_driver)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Tabla de Log de Auditoría
CREATE TABLE audit_log (
  id_log      BIGINT NOT NULL AUTO_INCREMENT,
  entidad     VARCHAR(50),
  id_entidad  BIGINT,
  accion      VARCHAR(50),

  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (id_log)
) ENGINE=InnoDB;

-- Tabla de Historial de Estados de Viajes
CREATE TABLE trip_status_history (
  id_history  BIGINT NOT NULL AUTO_INCREMENT,
  id_trip     BIGINT NOT NULL,

  estado ENUM(
    'solicitado',
    'aceptado',
    'en_curso',
    'finalizado',
    'cancelado'
  ) NOT NULL,

  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (id_history),

  INDEX idx_tsh_trip (id_trip),
  INDEX idx_tsh_estado_fecha (estado, created_at),

  CONSTRAINT fk_tsh_trip
    FOREIGN KEY (id_trip)
    REFERENCES trip(id_trip)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;