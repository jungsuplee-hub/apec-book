RHEL9 quick start
-----------------
1) Install system deps & MySQL & Nginx (see previous section in this canvas if needed)
2) Create /opt/apec-booking, copy project files, create venv, install requirements
3) Configure `/opt/apec-booking/.env`
   - Copy `.env.example` as a starting point: `cp /opt/apec-booking/.env.example /opt/apec-booking/.env`
   - Set `APP_HOST` / `APP_PORT` (the systemd unit below reads both values).
   - Choose storage backend (`STORAGE=mysql` or `STORAGE=xml`) and provide the matching connection details.
   - Fill in SMTP credentials used by both the web hooks and the 08:00 digest job: `SMTP_HOST`,
     `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, and `SMTP_FROM`/`MAIL_FROM`.
   - Update `SERVER_BASE_URL` so outgoing emails link to the correct public hostname.
4) MySQL: run models.sql to init schema & seed rooms
5) systemd service for API (example for `/etc/systemd/system/apec-booking.service`):


[Unit]
Description=APEC Booking API (FastAPI)
After=network.target mysqld.service


[Service]
# 실행 계정: 실제 사용 중인 계정으로 변경 (예: ec2-user)
User=ec2-user
WorkingDirectory=/opt/apec-booking

# 환경 변수 (.env 사용)
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/opt/apec-booking/.env

# 애플리케이션 실행 (APP_HOST/APP_PORT는 .env에서 읽음)
ExecStart=/opt/apec-booking/venv/bin/uvicorn app:app --host ${APP_HOST} --port ${APP_PORT}

# 자동 재시작 정책
Restart=always
RestartSec=3

# (선택) 기본 하드닝
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true


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


예약 차단 테이블 초기화 방법
---------------------------
1) `/opt/apec-booking/.env` 또는 `ENV_FILE` 환경 변수로 지정한 경로에 데이터베이스 접속 정보가 올바르게 설정되어 있는지 확인합니다.
2) 프로젝트 루트에서 `./reset_disabled_slots.sh`를 실행합니다.
   - 이 스크립트는 `disabled_slots` 테이블을 **DROP** 한 뒤 동일한 스키마로 다시 생성합니다.
   - 실행 시 테이블에 저장돼 있던 예약 차단 데이터가 모두 삭제되니 주의하세요.
