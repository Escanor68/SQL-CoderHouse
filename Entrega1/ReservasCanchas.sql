SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS reserva_canchas CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE reserva_canchas;

CREATE TABLE user_player (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  phone VARCHAR(20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_field (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  phone VARCHAR(20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE soccer_field (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_id INT UNSIGNED NOT NULL,
  name VARCHAR(100) NOT NULL,
  location VARCHAR(150),
  price_per_slot DECIMAL(10,2),
  INDEX idx_soccer_field_owner (owner_id),
  CONSTRAINT fk_field_owner
    FOREIGN KEY (owner_id) REFERENCES user_field(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE reservation (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  player_id INT UNSIGNED NOT NULL,
  field_id INT UNSIGNED NOT NULL,
  start_time DATETIME NOT NULL,
  end_time DATETIME NOT NULL,
  status ENUM('Pending','Confirmed','Cancelled') DEFAULT 'Pending',
  INDEX idx_res_player (player_id),
  INDEX idx_res_field_time (field_id, start_time, end_time),
  CONSTRAINT fk_res_player
    FOREIGN KEY (player_id) REFERENCES user_player(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_res_field
    FOREIGN KEY (field_id) REFERENCES soccer_field(id)
    ON DELETE CASCADE,
  CONSTRAINT chk_time_order CHECK (start_time < end_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payment (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reservation_id INT UNSIGNED NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  method VARCHAR(50),
  date_time DATETIME NOT NULL,
  INDEX idx_pay_res (reservation_id),
  CONSTRAINT fk_pay_res
    FOREIGN KEY (reservation_id) REFERENCES reservation(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Trigger para evitar solapamientos de reservas por cancha
DELIMITER $$
CREATE TRIGGER trg_reservation_no_overlap
BEFORE INSERT ON reservation
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT DEFAULT 0;
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

-- Datos de ejemplo mínimos
INSERT INTO user_player (name, email, phone) VALUES
('Juan Pérez', 'juanperez@example.com', '1122334455'),
('María Gómez', 'mariagomez@example.com', '1133445566');

INSERT INTO user_field (name, email, phone) VALUES
('Carlos López', 'carloslopez@example.com', '1144556677'),
('Ana Martínez', 'anamartinez@example.com', '1155667788');

INSERT INTO soccer_field (owner_id, name, location, price_per_slot) VALUES
(1, 'Cancha 1', 'Av. Siempreviva 123', 5000.00),
(1, 'Cancha 2', 'Av. Siempreviva 123', 5000.00),
(2, 'Cancha Norte', 'Calle Fútbol 456', 6000.00);

INSERT INTO reservation (player_id, field_id, start_time, end_time, status) VALUES
(1, 1, '2025-08-15 09:00:00', '2025-08-15 10:30:00', 'Confirmed'),
(2, 3, '2025-08-16 17:00:00', '2025-08-16 18:30:00', 'Pending');

INSERT INTO payment (reservation_id, amount, method, date_time) VALUES
(1, 5000.00, 'MercadoPago', '2025-08-14 12:00:00');

-- Consultas de verificación
SELECT * FROM user_player;
SELECT * FROM user_field;
SELECT * FROM soccer_field;
SELECT r.id, up.name AS jugador, sf.name AS cancha, r.start_time, r.end_time, r.status
FROM reservation r
JOIN user_player up ON r.player_id = up.id
JOIN soccer_field sf ON r.field_id = sf.id;
SELECT p.id, up.name AS jugador, p.amount, p.method, p.date_time
FROM payment p
JOIN reservation r ON p.reservation_id = r.id
JOIN user_player up ON r.player_id = up.id;

-- ¿Está libre la cancha 1 entre @from y @to?
SET @from = '2025-08-15 09:00:00';
SET @to   = '2025-08-15 10:30:00';
SELECT sf.id, sf.name
FROM soccer_field sf
WHERE sf.id = 1
  AND NOT EXISTS (
    SELECT 1
    FROM reservation r
    WHERE r.field_id = sf.id
      AND r.status IN ('Pending','Confirmed')
      AND r.start_time < @to
      AND r.end_time > @from
  );