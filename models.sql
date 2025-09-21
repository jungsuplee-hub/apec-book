CREATE DATABASE IF NOT EXISTS apec_booking
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;
USE apec_booking;

-- Rooms
CREATE TABLE IF NOT EXISTS rooms (
  id INT PRIMARY KEY AUTO_INCREMENT,
  code VARCHAR(64) NOT NULL UNIQUE,
  label VARCHAR(100) NOT NULL,
  tier ENUM('Diamond','Platinum','Gold','General') NOT NULL
) ENGINE=InnoDB;

-- Bookings
CREATE TABLE IF NOT EXISTS bookings (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  company VARCHAR(200) NOT NULL,
  email VARCHAR(190) NOT NULL,
  tier ENUM('Diamond','Platinum','Gold','General') NOT NULL,
  room_code VARCHAR(64) NOT NULL,
  date DATE NOT NULL,
  start_hour TINYINT NOT NULL,
  end_hour TINYINT NOT NULL,
  blocks TINYINT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_room FOREIGN KEY (room_code) REFERENCES rooms(code) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_room_date (room_code, date),
  INDEX idx_company_date (company, date),
  INDEX idx_email_date (email, date)
) ENGINE=InnoDB;

-- Companies (신규)
CREATE TABLE IF NOT EXISTS companies (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(200) NOT NULL UNIQUE,
  tier ENUM('Diamond','Platinum','Gold') NOT NULL,
  INDEX idx_tier_name (tier, name)
) ENGINE=InnoDB;

-- seed default rooms (idempotent)
INSERT IGNORE INTO rooms(code,label,tier) VALUES
('Indoor-1','Indoor 1','Diamond'),
('Indoor-2','Indoor 2','Diamond'),
('Outdoor-1','Outdoor 1','Diamond'),
('Indoor-3','Indoor 3','Platinum'),
('Indoor-4','Indoor 4','Platinum'),
('Outdoor-2','Outdoor 2','Platinum'),
('Outdoor-3','Outdoor 3','Gold'),
('Outdoor-Annex','Outdoor Annex','Gold'),
('Indoor-5','Indoor 5','General');

-- seed companies (idempotent)
INSERT IGNORE INTO companies(name, tier) VALUES
-- Diamond
('MEBO','Diamond'),
('UPbit','Diamond'),
('Korea Hydro & Nuclear Power Co., Ltd. (KHNP)','Diamond'),
('SK hynix Inc.','Diamond'),
('Samsung','Diamond'),
('Posco Holdings','Diamond'),
('Hyundai Motor Group','Diamond'),
('Hanwha','Diamond'),
('GS','Diamond'),

-- Platinum
('KB Kookmin Bank','Platinum'),
('MegazoneCloud','Platinum'),
('Woori Bank','Platinum'),
('LS Corp.','Platinum'),
('Wuliangye','Platinum'),
('Citi','Platinum'),
('Johnson & Johnson','Platinum'),
('Doosan','Platinum'),
('Shinhan Bank','Platinum'),
('NAVER Corporation','Platinum'),
('TikTok','Platinum'),

-- Gold
('Microsoft','Gold'),
('Google Korea','Gold');

