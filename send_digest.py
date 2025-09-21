import os
import smtplib
from datetime import datetime
from email.message import EmailMessage
from zoneinfo import ZoneInfo

from db import get_conn


SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_TLS = os.getenv("SMTP_TLS", "true").lower() == "true"
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD") or os.getenv("SMTP_PASS")
MAIL_FROM = os.getenv("MAIL_FROM") or os.getenv("SMTP_FROM") or "no-reply@example.com"
MAIL_TZ = os.getenv("MAIL_TIMEZONE", "UTC")


def build_rows(target_date: str):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "SELECT company,email,tier,room_code,date,start_hour,end_hour "
            "FROM bookings WHERE date=%s ORDER BY email,start_hour",
            (target_date,),
        )
        rows = cur.fetchall()

    data = {}
    for company, email, tier, room_code, date, start_hour, end_hour in rows:
        data.setdefault(email, []).append(
            (company, tier, room_code, date.strftime("%Y-%m-%d"), start_hour, end_hour)
        )
    return data


def send_for_date(target_date: str):
    data = build_rows(target_date)
    if not data:
        return 0

    sent = 0
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as smtp:
        if SMTP_TLS:
            smtp.starttls()
        if SMTP_USER and SMTP_PASSWORD:
            smtp.login(SMTP_USER, SMTP_PASSWORD)

        for email, items in data.items():
            msg = EmailMessage()
            msg["Subject"] = f"Your meeting room bookings for {target_date}"
            msg["From"] = MAIL_FROM
            msg["To"] = email
            lines = [
                "Hello,",
                "",
                "Here is your booking summary:",
                "",
            ]
            for company, tier, room, day, start_hour, end_hour in items:
                lines.append(
                    f"- {day} {start_hour:02d}:00–{end_hour:02d}:00 {room} ({tier}) – {company}"
                )
            lines.append("")
            lines.append("Thank you.")
            msg.set_content("\n".join(lines))
            smtp.send_message(msg)
            sent += 1

    return sent


if __name__ == "__main__":
    tz = ZoneInfo(MAIL_TZ)
    today = datetime.now(tz).strftime("%Y-%m-%d")
    num_sent = send_for_date(today)
    print(f"sent {num_sent} digests for {today}")
