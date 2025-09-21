#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./send_email.sh 20251029            # 실제 발송 (DRY_RUN=0일 때)
#   DRY_RUN=1 ./send_email.sh 20251029  # 메일 미발송, 콘솔 미리보기
#
# Requirements:
#   - Python 3.x (email/smtplib 표준 라이브러리 사용)
#   - mysqlclient 파이썬 모듈 (pip install mysqlclient) 또는 시스템 libmysqlclient 설치 필요
#   - /opt/apec-booking/.env 에 DB/SMTP 설정 존재
#
# .env keys (예시)
#   MYSQL_HOST=127.0.0.1
#   MYSQL_PORT=3306
#   MYSQL_DB=apec_booking
#   MYSQL_USER=apec
#   MYSQL_PASSWORD=******
#   SMTP_HOST=smtp.gmail.com
#   SMTP_PORT=587
#   SMTP_USER=sender@example.com
#   SMTP_PASSWORD=******
#   SMTP_FROM="APEC Booking" <sender@example.com>

ENV_FILE="${ENV_FILE:-/opt/apec-booking/.env}"
DRY_RUN="${DRY_RUN:-0}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 yyyymmdd   (e.g., $0 20251029)"
  exit 1
fi

YMD="$1"
if [[ ! "$YMD" =~ ^[0-9]{8}$ ]]; then
  echo "Invalid date format: $YMD (expected yyyymmdd)"
  exit 1
fi
DATE="${YMD:0:4}-${YMD:4:2}-${YMD:6:2}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[-] .env not found at: $ENV_FILE"
  exit 1
fi

# ---- dotenv getter (robust) --------------------------------------------------
dotenv_get() {
  local key="$1"
  awk -v k="$key" '
    {
      gsub(/\r/,"")                    # CR 제거
      if ($0 ~ /^[ \t]*#/) next        # 주석
      if ($0 ~ /^[ \t]*$/) next        # 빈줄
      sub(/^[ \t]*/,"")                # 좌공백 제거
      sub(/^export[ \t]+/,"")          # export 제거
      if ($0 ~ ("^" k "[ \t]*=")) {
        line=$0
        n = index(line, "=")
        val = substr(line, n+1)
        sub(/^[ \t]*/,"", val)
        sub(/[ \t]*$/,"", val)
        v = val
      }
    }
    END{
      if (v ~ /^".*"$/) { sub(/^"/,"",v); sub(/"$/,"",v) }
      else if (v ~ /^'\''.*'\''$/) { sub(/^'\''/,"",v); sub(/'\''$/,"",v) }
      print v
    }
  ' "$ENV_FILE"
}

# ---- read required config ----------------------------------------------------
MYSQL_HOST="$(dotenv_get MYSQL_HOST)";    : "${MYSQL_HOST:?MYSQL_HOST missing}"
MYSQL_PORT="$(dotenv_get MYSQL_PORT)";    : "${MYSQL_PORT:?MYSQL_PORT missing}"
MYSQL_DB="$(dotenv_get MYSQL_DB)";        : "${MYSQL_DB:?MYSQL_DB missing}"
MYSQL_USER="$(dotenv_get MYSQL_USER)";    : "${MYSQL_USER:?MYSQL_USER missing}"
MYSQL_PASSWORD="$(dotenv_get MYSQL_PASSWORD)"; : "${MYSQL_PASSWORD:?MYSQL_PASSWORD missing}"

SMTP_HOST="$(dotenv_get SMTP_HOST)";      : "${SMTP_HOST:?SMTP_HOST missing}"
SMTP_PORT="$(dotenv_get SMTP_PORT)";      : "${SMTP_PORT:?SMTP_PORT missing}"
SMTP_USER="$(dotenv_get SMTP_USER)";      : "${SMTP_USER:?SMTP_USER missing}"
SMTP_PASSWORD="$(dotenv_get SMTP_PASSWORD)"; : "${SMTP_PASSWORD:?SMTP_PASSWORD missing}"
SMTP_FROM="$(dotenv_get SMTP_FROM)";      : "${SMTP_FROM:?SMTP_FROM missing}"

echo "[*] Preparing emails for ${DATE}"
echo "    DB=${MYSQL_USER}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}"
echo "    SMTP=${SMTP_USER}@${SMTP_HOST}:${SMTP_PORT}  FROM=${SMTP_FROM}"
[[ "$DRY_RUN" = "1" ]] && echo "    (DRY_RUN=1: preview only, no send)"

# ---- call embedded Python to query & send -----------------------------------
PYTHONIOENCODING=UTF-8 \
MYSQL_HOST="$MYSQL_HOST" MYSQL_PORT="$MYSQL_PORT" MYSQL_DB="$MYSQL_DB" \
MYSQL_USER="$MYSQL_USER" MYSQL_PASSWORD="$MYSQL_PASSWORD" \
SMTP_HOST="$SMTP_HOST" SMTP_PORT="$SMTP_PORT" SMTP_USER="$SMTP_USER" SMTP_PASSWORD="$SMTP_PASSWORD" \
SMTP_FROM="$SMTP_FROM" TARGET_DATE="$DATE" DRY_RUN="$DRY_RUN" \
python3 - <<'PY'
import os, sys
import smtplib
from email.message import EmailMessage
from collections import defaultdict

import MySQLdb

def get_env(name, required=True, cast=str, default=None):
    val = os.environ.get(name, default)
    if required and (val is None or str(val).strip() == ""):
        print(f"Missing env: {name}", file=sys.stderr); sys.exit(2)
    return cast(val) if val is not None else None

# ---- env
MYSQL_HOST = get_env("MYSQL_HOST")
MYSQL_PORT = get_env("MYSQL_PORT", cast=int)
MYSQL_DB   = get_env("MYSQL_DB")
MYSQL_USER = get_env("MYSQL_USER")
MYSQL_PW   = get_env("MYSQL_PASSWORD")
SMTP_HOST  = get_env("SMTP_HOST")
SMTP_PORT  = get_env("SMTP_PORT", cast=int)
SMTP_USER  = get_env("SMTP_USER")
SMTP_PW    = get_env("SMTP_PASSWORD")
SMTP_FROM  = get_env("SMTP_FROM")
TARGET_DATE= get_env("TARGET_DATE")
DRY_RUN    = get_env("DRY_RUN", required=False, default="0")

# ---- query bookings for target date
conn = MySQLdb.connect(host=MYSQL_HOST, port=MYSQL_PORT, user=MYSQL_USER,
                       passwd=MYSQL_PW, db=MYSQL_DB, charset="utf8mb4")
cur = conn.cursor()
cur.execute("""
SELECT email, company, tier, room_code, start_hour, end_hour, date
FROM bookings
WHERE date = %s
ORDER BY email, start_hour, room_code
""", (TARGET_DATE,))
rows = cur.fetchall()
cur.close(); conn.close()

if not rows:
    print(f"[i] No bookings on {TARGET_DATE}. Nothing to send.")
    sys.exit(0)

# group by email
by_email = defaultdict(list)
for email, company, tier, room, sh, eh, dt in rows:
    by_email[email].append({
        "company": company, "tier": tier, "room": room,
        "sh": sh, "eh": eh, "date": str(dt)
    })

def fmt_time(h): return f"{h:02d}:00"


SERVER_BASE_URL = os.environ.get("SERVER_BASE_URL", "http://99.79.51.11")

def build_body(recipient, items):
    lines = []
    company_name = items[0]["company"] if items else ""

    lines.append(f"Dear {company_name},")
    lines.append("")
    lines.append("Warm greetings from the Secretariat of the APEC CEO Summit Korea 2025.")
    lines.append("We are pleased to inform you that your meeting room reservation has been successfully received.")
    lines.append("Please find the details of your booking below for your confirmation.")
    lines.append("")
    lines.append("Reservation Details:")

    for idx, it in enumerate(items):
        room = it["room"]
        date = it["date"]
        link = f"{SERVER_BASE_URL}/display?room={room}&date={date}"
        if idx > 0:
            lines.append("")
        lines.append(f"- {it['company']}")
        lines.append(f"- {date}")
        lines.append(f"- {fmt_time(it['sh'])} - {fmt_time(it['eh'])}")
        lines.append(f"- {it['tier']} / {room}")
        lines.append(f"- Check Schedule : {link}")

    lines.append("")
    lines.append("We kindly ask you to review the above information and ensure that all details are correct.")
    lines.append("Should you require any assistance or additional arrangements, please do not hesitate to contact us.")
    lines.append("")
    lines.append("We look forward to supporting your successful participation at the APEC CEO Summit Korea 2025.")
    lines.append("")
    lines.append("Warm regards,")
    lines.append("APEC CEO Summit Korea 2025 Secretariat")

    return "\n".join(lines)


def send_one(to_addr, items):
    subject = "[APEC CEO Summit Korea 2025] Meeting Room Reservation Confirmation"
    body = build_body(to_addr, items)

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"]    = SMTP_FROM
    msg["To"]      = to_addr
    msg.set_content(body)

    if DRY_RUN == "1":
        print("----- DRY RUN -----")
        print("TO:", to_addr)
        print(msg.as_string())
        print("-------------------")
        return

    if SMTP_PORT == 465:
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=20) as s:
            s.login(SMTP_USER, SMTP_PW)
            s.send_message(msg)
    else:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=20) as s:
            s.ehlo()
            try:
                s.starttls()
                s.ehlo()
            except smtplib.SMTPException:
                pass
            if SMTP_USER:
                s.login(SMTP_USER, SMTP_PW)
            s.send_message(msg)

count = 0
for email, items in by_email.items():
    if not email:
        continue
    try:
        send_one(email, items)
        count += 1
    except Exception as e:
        print(f"[WARN] send failed to {email}: {e}", file=sys.stderr)

print(f"[✓] Done. Recipients: {count}, Bookings: {len(rows)}")
PY

