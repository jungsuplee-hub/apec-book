#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/opt/apec-booking/.env}"
[[ -f "$ENV_FILE" ]] || { echo "No .env at $ENV_FILE"; exit 1; }

# tiny dotenv getter
get() { awk -v k="$1" 'BEGIN{v=""}{
  gsub(/\r/,"");
  if($0~/^[ \t]*#/||$0~/^[ \t]*$/)next;
  sub(/^[ \t]*/,""); sub(/^export[ \t]+/,"");
  if($0~("^"k"[ \t]*=")){ n=index($0,"="); v=substr($0,n+1);
    sub(/^[ \t]*/,"",v); sub(/[ \t]*$/,"",v);
    if(v~/^".*"$/){sub(/^"/,"",v);sub(/"$/,"",v)}
    else if(v~/^'\''.*'\''$/){sub(/^'\''/,"",v);sub(/'\''$/,"",v)}
  }
} END{print v}' "$ENV_FILE"; }

MYSQL_HOST="$(get MYSQL_HOST)"; MYSQL_PORT="$(get MYSQL_PORT)"
MYSQL_DB="$(get MYSQL_DB)";   MYSQL_USER="$(get MYSQL_USER)"
MYSQL_PASSWORD="$(get MYSQL_PASSWORD)"

: "${MYSQL_HOST:?}"; : "${MYSQL_PORT:?}"; : "${MYSQL_DB:?}"; : "${MYSQL_USER:?}"; : "${MYSQL_PASSWORD:?}"

export MYSQL_PWD="$MYSQL_PASSWORD"

echo "--------------"
echo "Checking distinct tiers in bookings..."
echo "--------------"
mysql --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DB" -e \
"SELECT DISTINCT tier FROM bookings ORDER BY tier;"

echo "--------------"
echo "Step 1) Expand ENUM to include both General and Other (safe widen)"
echo "--------------"
mysql --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DB" <<'SQL'
ALTER TABLE bookings
  MODIFY COLUMN tier ENUM(
    'Diamond','Platinum','Gold','Legal Partner','Knowledge Partner',
    'Media Partner - Premier','Media Partner - Platinum','Media Partner - Gold',
    'General','Other'
  ) NOT NULL;
SQL

echo "--------------"
echo "Step 2) Migrate data: General -> Other"
echo "--------------"
mysql --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DB" -e \
"UPDATE bookings SET tier='Other' WHERE tier='General'; SELECT ROW_COUNT() AS updated_rows;"

echo "--------------"
echo "Step 3) Shrink ENUM to remove General"
echo "--------------"
mysql --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DB" <<'SQL'
ALTER TABLE bookings
  MODIFY COLUMN tier ENUM(
    'Diamond','Platinum','Gold','Legal Partner','Knowledge Partner',
    'Media Partner - Premier','Media Partner - Platinum','Media Partner - Gold',
    'Other'
  ) NOT NULL;
SQL

echo "--------------"
echo "[✓] Done. Final distinct tiers:"
echo "--------------"
mysql --protocol=TCP -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DB" -e \
"SELECT DISTINCT tier FROM bookings ORDER BY tier;"

