-- Entrega2: Creación de Vistas, Funciones, Stored Procedures y Triggers
-- Configuración de codificación UTF-8 para caracteres especiales
SET NAMES utf8mb4;
-- Selección de la base de datos
USE reserva_canchas;

-- Vista que muestra detalles completos de reservas con información de jugadores, canchas y pagos
CREATE OR REPLACE VIEW view_reservation_details AS
SELECT
  r.id AS reservation_id,
  r.start_time,
  r.end_time,
  r.status,
  up.id AS player_id,
  up.name AS player_name,
  sf.id AS field_id,
  sf.name AS field_name,
  uf.id AS owner_id,
  uf.name AS owner_name,
  p.id AS payment_id,
  p.amount AS payment_amount,
  p.method AS payment_method,
  p.date_time AS payment_date
FROM reservation r
JOIN user_player up ON r.player_id = up.id
JOIN soccer_field sf ON r.field_id = sf.id
JOIN user_field uf ON sf.owner_id = uf.id
LEFT JOIN payment p ON p.reservation_id = r.id;

-- Vista que verifica la disponibilidad de canchas en un rango de fechas
CREATE OR REPLACE VIEW view_field_availability AS
SELECT
  sf.id AS field_id,
  sf.name AS field_name,
  sf.location,
  CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM reservation r
      WHERE r.field_id = sf.id
        AND r.status IN ('Pending','Confirmed')
        AND r.start_time < IFNULL(@to, '9999-12-31 23:59:59')
        AND r.end_time > IFNULL(@from, '0000-01-01 00:00:00')
    ) THEN 'Available'
    ELSE 'Busy'
  END AS availability
FROM soccer_field sf;

-- Función que verifica si existe solapamiento de horarios para una cancha específica
DROP FUNCTION IF EXISTS fn_is_overlap;
DELIMITER $$
CREATE FUNCTION fn_is_overlap(fieldId INT, startTime DATETIME, endTime DATETIME)
RETURNS TINYINT DETERMINISTIC
BEGIN
  DECLARE cnt INT DEFAULT 0;
  -- Cuenta reservas que se solapan con el horario solicitado
  SELECT COUNT(*) INTO cnt
  FROM reservation
  WHERE field_id = fieldId
    AND status IN ('Pending','Confirmed')
    AND start_time < endTime
    AND end_time > startTime;
  IF cnt > 0 THEN
    RETURN 1; -- Existe solapamiento
  ELSE
    RETURN 0; -- No hay solapamiento
  END IF;
END$$
DELIMITER ;

-- Procedimiento para crear reservas con validación de solapamiento y pago opcional
DROP PROCEDURE IF EXISTS sp_create_reservation;
DELIMITER $$
CREATE PROCEDURE sp_create_reservation(
  IN p_player_id INT,
  IN p_field_id INT,
  IN p_start DATETIME,
  IN p_end DATETIME,
  IN p_status VARCHAR(20),
  IN p_amount DECIMAL(10,2),
  IN p_method VARCHAR(50)
)
BEGIN
  DECLARE v_overlap TINYINT;
  DECLARE v_res_id INT;
  START TRANSACTION;
    -- Verificar solapamiento de horarios
    SET v_overlap = fn_is_overlap(p_field_id, p_start, p_end);
    IF v_overlap = 1 THEN
      ROLLBACK;
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No es posible crear la reserva: solapamiento detectado.';
    ELSE
      -- Crear la reserva
      INSERT INTO reservation (player_id, field_id, start_time, end_time, status)
      VALUES (p_player_id, p_field_id, p_start, p_end, p_status);
      SET v_res_id = LAST_INSERT_ID();
      -- Crear pago si se proporciona monto
      IF p_amount IS NOT NULL AND p_amount > 0 THEN
        INSERT INTO payment (reservation_id, amount, method, date_time)
        VALUES (v_res_id, p_amount, p_method, NOW());
      END IF;
    END IF;
  COMMIT;
END$$
DELIMITER ;

-- Procedimiento para insertar datos de prueba adicionales de forma segura
DROP PROCEDURE IF EXISTS sp_seed_more_data;
DELIMITER $$
CREATE PROCEDURE sp_seed_more_data()
BEGIN
  -- Inserciones idempotentes: se evitan duplicados básicos por email
  INSERT INTO user_player (name, email, phone)
  SELECT 'Luis Fernández', 'luisfernandez@example.com', '1167788990'
  FROM DUAL
  WHERE NOT EXISTS (SELECT 1 FROM user_player WHERE email='luisfernandez@example.com');

  INSERT INTO user_field (name, email, phone)
  SELECT 'Diego Torres', 'diegotorres@example.com', '1178899001'
  FROM DUAL
  WHERE NOT EXISTS (SELECT 1 FROM user_field WHERE email='diegotorres@example.com');

  INSERT INTO soccer_field (owner_id, name, location, price_per_slot)
  SELECT uf.id, 'Cancha Sur', 'Bulevar Sur 200', 5500.00
  FROM user_field uf
  WHERE uf.email='diegotorres@example.com'
    AND NOT EXISTS (SELECT 1 FROM soccer_field WHERE name='Cancha Sur' AND owner_id=uf.id);

END$$
DELIMITER ;

-- Trigger que previene la inserción de reservas con horarios solapados
DROP TRIGGER IF EXISTS trg_reservation_no_overlap;
DELIMITER $$
CREATE TRIGGER trg_reservation_no_overlap
BEFORE INSERT ON reservation
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT DEFAULT 0;
  -- Verificar si existe solapamiento con reservas existentes
  SELECT COUNT(*) INTO overlap_count
  FROM reservation
  WHERE field_id = NEW.field_id
    AND status IN ('Pending','Confirmed')
    AND NEW.start_time < end_time
    AND NEW.end_time > start_time;
  IF overlap_count > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reserva solapada para la cancha';
  END IF;
END$$
DELIMITER ;

-- Trigger que confirma automáticamente una reserva cuando se registra un pago
DROP TRIGGER IF EXISTS trg_payment_after_insert;
DELIMITER $$
CREATE TRIGGER trg_payment_after_insert
AFTER INSERT ON payment
FOR EACH ROW
BEGIN
  -- Cambiar el estado de la reserva a 'Confirmed' cuando se procesa el pago
  UPDATE reservation
  SET status = 'Confirmed'
  WHERE id = NEW.reservation_id
    AND status = 'Pending';
END$$
DELIMITER ;
