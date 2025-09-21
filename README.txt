RHEL9 quick start
-----------------
1) Install system deps & MySQL & Nginx (see previous section in this canvas if needed)
2) Create /opt/apec-booking, copy project files, create venv, install requirements
3) Configure .env (STORAGE=mysql or xml, SMTP_*, EVENT_* dates)
4) MySQL: run models.sql to init schema & seed rooms
5) systemd service for API:


[Unit]
Description=APEC Booking API (FastAPI)
After=network.target mysqld.service


[Service]
User=apec
WorkingDirectory=/opt/apec-booking
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/opt/apec-booking/.env
ExecStart=/opt/apec-booking/venv/bin/uvicorn app:app --host ${APP_HOST} --port ${APP_PORT}
Restart=always


[Install]
WantedBy=multi-user.target


6) Daily 08:00 digest emails (systemd timer)


# /etc/systemd/system/apec-digest.service
[Unit]
Description=APEC Booking – 08:00 daily digest mailer
After=network.target apec-booking.service


[Service]
Type=oneshot
User=apec
WorkingDirectory=/opt/apec-booking
EnvironmentFile=/opt/apec-booking/.env
ExecStart=/opt/apec-booking/venv/bin/python send_digest.py


# /etc/systemd/system/apec-digest.timer
[Unit]
Description=Run APEC digest at 08:00 local time


[Timer]
OnCalendar=*-*-* 08:00:00
Persistent=true


[Install]
WantedBy=timers.target


# enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now apec-booking
sudo systemctl enable --now apec-digest.timer
