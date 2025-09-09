-- Entrega2: Inserción de datos (archivo: Entrega2_insercion_datos.sql)
-- Configuración de codificación UTF-8 para caracteres especiales
SET NAMES utf8mb4;
-- Selección de la base de datos
USE reserva_canchas;

-- Inserción de jugadores de prueba con manejo de duplicados
INSERT INTO user_player (name, email, phone) VALUES
('Sofía Rojas', 'sofiarojas@example.com', '1166655544')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO user_player (name, email, phone) VALUES
('Martín Díaz', 'martindiaz@example.com', '1166677889')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Inserción de propietario de cancha con manejo de duplicados
INSERT INTO user_field (name, email, phone) VALUES
('Federico Alvarez', 'federicoalvarez@example.com', '1177766554')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Inserción de cancha asociada al propietario con manejo de duplicados
INSERT INTO soccer_field (owner_id, name, location, price_per_slot) VALUES
((SELECT id FROM user_field WHERE email='federicoalvarez@example.com'), 'Cancha Este', 'Av. Este 50', 4800.00)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Creación de una reserva de prueba usando el procedimiento almacenado
CALL sp_create_reservation( (SELECT id FROM user_player WHERE email='sofiarojas@example.com'),
                            (SELECT id FROM soccer_field WHERE name='Cancha Este' LIMIT 1),
                            '2025-09-10 10:00:00',
                            '2025-09-10 11:30:00',
                            'Pending',
                            4800.00,
                            'MercadoPago');

-- Ejecutar procedimiento para insertar datos adicionales de prueba
CALL sp_seed_more_data();
