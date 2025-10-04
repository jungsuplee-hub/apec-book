#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# APEC Booking - Reset `disabled_slots` table
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
  local line
  line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" | tail -n1 || true)"
  if [[ -z "$line" ]]; then
    printf '%s' "$def"
    return 0
  fi
  line="${line%%$'\r'}"
  line="${line#*=}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  if [[ ( "$line" == \"*\" && "$line" == *\" ) || ( "$line" == \'*\' && "$line" == *\' ) ]]; then
    line="${line:1:${#line}-2}"
  fi
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

export MYSQL_PWD="$MYSQL_PASSWORD"

echo "[*] Resetting disabled_slots table in database '$MYSQL_DB'..."

mysql --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DB" <<'SQL'
DROP TABLE IF EXISTS disabled_slots;
CREATE TABLE disabled_slots (
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
SQL

echo "[✓] disabled_slots table has been reset."
