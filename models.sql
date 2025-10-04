CREATE DATABASE IF NOT EXISTS apec_booking
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;
USE apec_booking;

-- Rooms
CREATE TABLE IF NOT EXISTS rooms (
  id INT PRIMARY KEY AUTO_INCREMENT,
  code VARCHAR(64) NOT NULL UNIQUE,
  label VARCHAR(120) NOT NULL,
  tier ENUM(
    'Diamond','Platinum','Gold','Legal Partner','Knowledge Partner',
    'Media Partner - Premier','Media Partner - Platinum','Media Partner - Gold','Other'
  ) NOT NULL
) ENGINE=InnoDB;

-- Bookings
CREATE TABLE IF NOT EXISTS bookings (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  company VARCHAR(200) NOT NULL,
  email VARCHAR(190) NOT NULL,
  tier ENUM(
    'Diamond','Platinum','Gold','Legal Partner','Knowledge Partner',
    'Media Partner - Premier','Media Partner - Platinum','Media Partner - Gold','Other'
  ) NOT NULL,
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

-- Admin disabled slots
CREATE TABLE IF NOT EXISTS disabled_slots (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  room_code VARCHAR(64) NOT NULL,
  date DATE NOT NULL,
  start_hour TINYINT NOT NULL,
  end_hour TINYINT NOT NULL,
  note VARCHAR(255) DEFAULT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_disabled_room FOREIGN KEY (room_code) REFERENCES rooms(code) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_disabled_room_date (room_code, date),
  INDEX idx_disabled_date (date),
  CONSTRAINT uq_disabled UNIQUE (room_code, date, start_hour, end_hour)
) ENGINE=InnoDB;

-- Companies (신규)
CREATE TABLE IF NOT EXISTS companies (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(200) NOT NULL UNIQUE,
  tier ENUM(
    'Diamond','Platinum','Gold','Legal Partner','Knowledge Partner',
    'Media Partner - Premier','Media Partner - Platinum','Media Partner - Gold'
  ) NOT NULL,
  INDEX idx_tier_name (tier, name)
) ENGINE=InnoDB;

-- seed default rooms (idempotent)
INSERT IGNORE INTO rooms(code,label,tier) VALUES
('DM1','DM1 · Meeting Room 1','Diamond'),
('DM2','DM2 · Meeting Room 2','Diamond'),
('DM3','DM3 · Meeting Room 3','Diamond'),
('DM4','DM4 · Meeting Room 4','Diamond'),
('PM1','PM1 · Meeting Room 5','Platinum'),
('PM2','PM2 · Meeting Room 6','Platinum'),
('PM3','PM3 · Meeting Room 7','Platinum'),
('PM4','PM4 · Meeting Room 8','Platinum'),
('GM1','GM1 · Meeting Room 9','Gold'),
('GM2','GM2 · Outdoor Meeting Room 1 (Hyundai Office Bus)','Other'),
('GM3','GM3 · Outdoor Meeting Room 2 (Hyundai Office Bus)','Other'),
('NM1','NM1 · Media Interview Room','Other');

-- seed companies (idempotent)
INSERT IGNORE INTO companies(name, tier) VALUES
-- Diamond
('Samsung','Diamond'),
('SK','Diamond'),
('Hyundai','Diamond'),
('LG','Diamond'),
('Lotte','Diamond'),
('Posco International','Diamond'),
('Hanwha','Diamond'),
('HD Hyundai','Diamond'),
('GS','Diamond'),
('Shinsegae Group','Diamond'),
('Korea Hydro & Nuclear Power','Diamond'),
('UPbit','Diamond'),
('Hybe','Diamond'),
('Mebo','Diamond'),

-- Platinum
('Korean Air Lines','Platinum'),
('LS','Platinum'),
('Doosan','Platinum'),
('KT','Platinum'),
('Naver','Platinum'),
('Shinhan Bank','Platinum'),
('Kookmin Bank','Platinum'),
('Woori Bank','Platinum'),
('Hana Bank','Platinum'),
('CJ','Platinum'),
('Korea zinc','Platinum'),
('Megazone Cloud','Platinum'),
('Kolon','Platinum'),
('HS Hyosung','Platinum'),
('Citi','Platinum'),
('Meta','Platinum'),
('AWS','Platinum'),
('Johnsons&Johnson','Platinum'),
('Coupang','Platinum'),
('TicTok','Platinum'),
('Wuliangye','Platinum'),

-- Gold
('AB InBev','Gold'),
('Ananti','Gold'),
('Microsoft','Gold'),
('Google','Gold'),
('LONGi','Gold'),
('Vobile','Gold'),

-- Partners
('Kim & Chang','Legal Partner'),
('Deloitte','Knowledge Partner'),
('Bloomberg','Media Partner - Premier'),
('Caixin','Media Partner - Premier'),
('CGTN','Media Partner - Premier'),
('CNBC','Media Partner - Premier'),
('Economist Imapct','Media Partner - Platinum'),
('Financial Times','Media Partner - Gold'),
('Foreign Affairs','Media Partner - Gold'),
('Time','Media Partner - Gold'),
('The Wall Street Journal','Media Partner - Gold');

