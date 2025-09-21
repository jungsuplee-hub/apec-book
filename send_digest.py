import os, smtplib
from email.message import EmailMessage
from datetime import datetime
from zoneinfo import ZoneInfo
from db import get_conn


SMTP_HOST=os.getenv('SMTP_HOST')
SMTP_PORT=int(os.getenv('SMTP_PORT','587'))
SMTP_TLS=os.getenv('SMTP_TLS','true').lower()=='true'
SMTP_USER=os.getenv('SMTP_USER')
SMTP_PASS=os.getenv('SMTP_PASS')
MAIL_FROM=os.getenv('MAIL_FROM','no-reply@example.com')
MAIL_TZ=os.getenv('MAIL_TIMEZONE','UTC')


def build_rows(target_date:str):
with get_conn() as conn:
cur=conn.cursor()
cur.execute("SELECT company,email,tier,room_code,date,start_hour,end_hour FROM bookings WHERE date=%s ORDER BY email,start_hour", (target_date,))
rows=cur.fetchall()
data={}
for c,e,t,r,d,s,eend in rows:
data.setdefault(e, []).append((c,t,r,d.strftime('%Y-%m-%d'),s,eend))
return data


def send_for_date(target_date:str):
data=build_rows(target_date)
if not data: return 0
sent=0
with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as smtp:
if SMTP_TLS: smtp.starttls()
if SMTP_USER: smtp.login(SMTP_USER, SMTP_PASS)
for email, items in data.items():
msg=EmailMessage()
msg['Subject']=f"Your meeting room bookings for {target_date}"
msg['From']=MAIL_FROM
msg['To']=email
lines=["Hello,","","Here is your booking summary:",""]
for c,t,r,d,s,e in items:
lines.append(f"- {d} {s:02d}:00–{e:02d}:00 {r} ({t}) – {c}")
lines.append("","Thank you.")
msg.set_content("
".join(lines))
smtp.send_message(msg); sent+=1
return sent


if __name__=='__main__':
tz=ZoneInfo(MAIL_TZ)
today=datetime.now(tz).strftime('%Y-%m-%d')
n=send_for_date(today)
print(f"sent {n} digests for {today}")
