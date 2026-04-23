USE movilidad;

--Datos de Compañias
INSERT INTO company (nombre) VALUES
('FastRide'),
('CityCab');

--Datos de Usuarios
INSERT INTO user (nombre, email, rol) VALUES
('Alice', 'alice@test.com', 'rider'),
('Bob', 'bob@test.com', 'rider'),
('Carlos', 'carlos@test.com', 'driver'),
('Diana', 'diana@test.com', 'driver');

--Datos de Conductores
INSERT INTO driver (id_driver, id_company, rating) VALUES
(3, 1, 4.8),
(4, 2, 4.9);

--Datos de Vehículos
INSERT INTO vehicle (id_driver, matricula, modelo) VALUES
(3, '1234ABC', 'Toyota Prius'),
(4, '5678DEF', 'Tesla Model 3');

--Datos de Viajes
INSERT INTO trip (
  id_rider,
  estado,
  origen_lat, origen_lng,
  destino_lat, destino_lng
) VALUES
(
  1,
  'solicitado',
  40.4168, -3.7038,
  40.4200, -3.7050
);

--Datos de Ofertas
INSERT INTO offer (id_trip, id_driver) VALUES
(1, 3),
(1, 4);

--Datos de Historial de Estados de Viajes
INSERT INTO trip_status_history (id_trip, estado) VALUES
(1, 'solicitado');