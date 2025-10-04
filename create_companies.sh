#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# APEC Booking - create and seed `companies` table (idempotent)
# - DOES NOT 'source' .env. Instead, it parses KEY=VALUE lines safely.
# - Works even with CRLF, quotes, surrounding spaces, comments.
# ------------------------------------------------------------

ENV_FILE="${ENV_FILE:-/opt/apec-booking/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[-] .env not found at: $ENV_FILE"
  echo "    Set ENV_FILE=/path/to/.env or place it at /opt/apec-booking/.env"
  exit 1
fi

# read_env VAR_NAME [default]
read_env() {
  local key="$1"; local def="${2:-}"
  # Grab the last occurrence of KEY=... (ignores commented lines)
  local line
  line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" | tail -n1 || true)"
  if [[ -z "$line" ]]; then
    printf '%s' "$def"
    return 0
  fi
  # Remove leading/trailing spaces, split on first '=' only
  line="${line%%$'\r'}"
  line="${line#*=}"
  # Trim spaces and CR
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  # Strip surrounding single/double quotes if present
  if [[ ( "$line" == \"*\" && "$line" == *\" ) || ( "$line" == \'*\' && "$line" == *\' ) ]]; then
    line="${line:1:${#line}-2}"
  fi
  # Remove any trailing CR (from CRLF files)
  line="${line%%$'\r'}"
  printf '%s' "$line"
}

MYSQL_HOST="$(read_env MYSQL_HOST 127.0.0.1)"
MYSQL_PORT="$(read_env MYSQL_PORT 3306)"
MYSQL_DB="$(read_env MYSQL_DB apec_booking)"
MYSQL_USER="$(read_env MYSQL_USER apec)"
MYSQL_PASSWORD="$(read_env MYSQL_PASSWORD "")"

if [[ -z "$MYSQL_PASSWORD" ]]; then
  echo "[-] MYSQL_PASSWORD is empty (check $ENV_FILE: MYSQL_PASSWORD=...)"
  exit 1
fi

if ! command -v mysql >/dev/null 2>&1; then
  echo "[-] mysql client not found. Install it first (e.g., 'sudo dnf install -y mysql' or 'sudo apt-get install -y mysql-client')."
  exit 1
fi

echo "[*] Using MySQL:"
echo "    HOST=${MYSQL_HOST} PORT=${MYSQL_PORT} DB=${MYSQL_DB} USER=${MYSQL_USER}"
echo "    PASS=********"

# Use MYSQL_PWD to avoid exposing password in process list
export MYSQL_PWD="$MYSQL_PASSWORD"

mysql --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" <<'SQL'
-- Ensure DB (if this user has permission)
-- NOTE: If the DB already exists and this user lacks CREATE DATABASE, this block will be ignored by server.
CREATE DATABASE IF NOT EXISTS apec_booking
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;

USE apec_booking;

-- Companies table
CREATE TABLE IF NOT EXISTS companies (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(200) NOT NULL UNIQUE,
  tier ENUM(
    'Diamond','Platinum','Gold','Legal Partner','Knowledge Partner',
    'Media Partner - Premier','Media Partner - Platinum','Media Partner - Gold'
  ) NOT NULL,
  INDEX idx_tier_name (tier, name)
) ENGINE=InnoDB;

-- Reset and seed companies
DELETE FROM companies;
ALTER TABLE companies AUTO_INCREMENT = 1;

INSERT INTO companies(name, tier) VALUES
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
SQL

echo "[✓] companies table ensured and seed data inserted."

