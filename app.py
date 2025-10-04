import os
from datetime import datetime
from urllib.parse import quote_plus
from typing import List, Dict, Any, Tuple, Optional

from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from dotenv import load_dotenv
import MySQLdb
from MySQLdb import IntegrityError
from MySQLdb.cursors import DictCursor

load_dotenv()

APP_HOST = os.getenv("APP_HOST", "0.0.0.0")
APP_PORT = int(os.getenv("APP_PORT", "80"))
STORAGE = os.getenv("STORAGE", "mysql")

MYSQL_HOST = os.getenv("MYSQL_HOST", "127.0.0.1")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
MYSQL_DB = os.getenv("MYSQL_DB", "apec_booking")
MYSQL_USER = os.getenv("MYSQL_USER", "apec")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "")

# 이벤트/운영시간
EVENT_DATES = ["2025-10-29", "2025-10-30", "2025-10-31"]
HOURS = list(range(9, 18))  # 09~18 보기(시작 슬롯은 9~17)
MAX_BLOCKS = 2              # 1h/block, 최대 2블록 = 2시간

# 룸/티어 정의
ROOM_TIER_LABELS = {
    "Diamond": "Diamond Sponsor Only",
    "Platinum": "Platinum Sponsor Only",
    "Gold": "Gold Sponsor Only",
    "General": "General Only",
}

TIER_ORDER = list(ROOM_TIER_LABELS)
TIER_INDEX = {tier: idx for idx, tier in enumerate(TIER_ORDER)}

COMPANY_MANAGED_TIERS = [tier for tier in TIER_ORDER if tier != "General"]

OTHER_ROOM_CODE = "NM1"

ROOMS_DATA = [
    {
        "code": "DM1",
        "tier": "Diamond",
        "name": "Meeting Room 1",
        "category": "Indoor Meeting Suite",
        "location": "1F",
        "capacity": 8,
        "meeting_code": "DM1",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/indoor-suite.svg",
        "order": 1,
    },
    {
        "code": "DM2",
        "tier": "Diamond",
        "name": "Meeting Room 2",
        "category": "Indoor Meeting Suite",
        "location": "1F",
        "capacity": 13,
        "meeting_code": "DM2",
        "summary": "",
        "features": ["Chair and Table", "Podium", "Wired Mic."],
        "image": "/static/images/rooms/indoor-suite.svg",
        "order": 2,
    },
    {
        "code": "DM3",
        "tier": "Diamond",
        "name": "Meeting Room 3",
        "category": "Indoor Meeting Suite",
        "location": "1F",
        "capacity": 6,
        "meeting_code": "DM3",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/indoor-suite.svg",
        "order": 3,
    },
    {
        "code": "DM4",
        "tier": "Diamond",
        "name": "Outdoor F&B Zone, Office Bus",
        "category": "Outdoor F&B Zone, Office Bus",
        "location": "F&B Zone",
        "capacity": 7,
        "meeting_code": "DM4",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/outdoor-terrace.svg",
        "order": 4,
    },
    {
        "code": "PM1",
        "tier": "Platinum",
        "name": "Meeting Room 1",
        "category": "Indoor Meeting Suite",
        "location": "1F",
        "capacity": 8,
        "meeting_code": "PM1",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/indoor-suite.svg",
        "order": 1,
    },
    {
        "code": "PM2",
        "tier": "Platinum",
        "name": "Meeting Room 2",
        "category": "Indoor Meeting Suite",
        "location": "B1",
        "capacity": 8,
        "meeting_code": "PM2",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/indoor-suite.svg",
        "order": 2,
    },
    {
        "code": "PM3",
        "tier": "Platinum",
        "name": "Meeting Room 3",
        "category": "Indoor Meeting Suite",
        "location": "B1",
        "capacity": 6,
        "meeting_code": "PM3",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/indoor-suite.svg",
        "order": 3,
    },
    {
        "code": "PM4",
        "tier": "Platinum",
        "name": "Outdoor F&B Zone, Office Bus",
        "category": "Outdoor F&B Zone, Office Bus",
        "location": "F&B Zone",
        "capacity": 7,
        "meeting_code": "PM4",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/outdoor-terrace.svg",
        "order": 4,
    },
    {
        "code": "GM1",
        "tier": "Gold",
        "name": "Meeting Room 1",
        "category": "Indoor Meeting Suite",
        "location": "B1",
        "capacity": 6,
        "meeting_code": "GM1",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/indoor-suite.svg",
        "order": 1,
    },
    {
        "code": "GM2",
        "tier": "Gold",
        "name": "Meeting Room 2",
        "category": "Indoor Meeting Suite",
        "location": "B1",
        "capacity": 6,
        "meeting_code": "GM2",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/indoor-suite.svg",
        "order": 2,
    },
    {
        "code": "GM3",
        "tier": "Gold",
        "name": "OUTDOOR F&B ZONE_OFFICE BUS",
        "category": "OUTDOOR F&B ZONE_OFFICE BUS",
        "location": "F&B ZONE",
        "capacity": 7,
        "meeting_code": "GM3",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/indoor-suite.svg",
        "order": 3,
    },
    {
        "code": "NM1",
        "tier": "General",
        "name": "OUTDOOR F&B ZONE_OFFICE BUS",
        "category": "OUTDOOR F&B ZONE_OFFICE BUS",
        "location": "MAIN ENTERANCE",
        "capacity": 7,
        "meeting_code": "NM1",
        "summary": "",
        "features": ["Sofa and Table"],
        "image": "/static/images/rooms/outdoor-terrace.svg",
        "order": 1,
    },
]

ROOM_DETAILS = {room["code"]: room for room in ROOMS_DATA}
ROOM_LABEL = {
    code: f"{details['meeting_code']} · {details['name']}"
    for code, details in ROOM_DETAILS.items()
}

ROOMS_BY_TIER: dict[str, list[str]] = {tier: [] for tier in ROOM_TIER_LABELS}
for room in sorted(
    ROOMS_DATA,
    key=lambda r: (TIER_INDEX[r["tier"]], r["order"]),
):
    ROOMS_BY_TIER.setdefault(room["tier"], []).append(room["code"])

app = FastAPI(title="APEC Meeting Rooms Booking")
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# -------------------------- DB helpers --------------------------
def get_db():
    if STORAGE != "mysql":
        raise RuntimeError("Only mysql supported")
    return MySQLdb.connect(
        host=MYSQL_HOST, port=MYSQL_PORT, user=MYSQL_USER,
        passwd=MYSQL_PASSWORD, db=MYSQL_DB, charset="utf8mb4"
    )

def fetch_bookings(date_str: str) -> List[Dict[str, Any]]:
    conn = get_db()
    try:
        cur = conn.cursor(DictCursor)
        cur.execute(
            """
            SELECT id, date, room_code, tier, company, email,
                   start_hour, end_hour, blocks, created_at
            FROM bookings
            WHERE date = %s
            ORDER BY room_code, start_hour
            """,
            (date_str,),
        )
        return list(cur.fetchall())
    finally:
        conn.close()


def fetch_disabled_slots(date_str: Optional[str] = None, room_code: Optional[str] = None) -> List[Dict[str, Any]]:
    conn = get_db()
    try:
        cur = conn.cursor(DictCursor)
        query = """
            SELECT id, date, room_code, start_hour, end_hour, note, created_at
            FROM disabled_slots
        """
        conditions = []
        params: List[Any] = []
        if date_str:
            conditions.append("date=%s")
            params.append(date_str)
        if room_code:
            conditions.append("room_code=%s")
            params.append(room_code)
        if conditions:
            query += " WHERE " + " AND ".join(conditions)
        query += " ORDER BY date, room_code, start_hour"
        cur.execute(query, params)
        return list(cur.fetchall())
    finally:
        conn.close()

def ensure_rooms_seeded(conn=None):
    """Ensure the static room catalog exists in the database."""

    owns_connection = conn is None
    if owns_connection:
        conn = get_db()

    try:
        cur = conn.cursor()
        rows = [
            (code, ROOM_LABEL[code], ROOM_DETAILS[code]["tier"])
            for code in ROOM_LABEL
        ]
        cur.executemany(
            """
            INSERT INTO rooms (code, label, tier)
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE label=VALUES(label), tier=VALUES(tier)
            """,
            rows,
        )
        if owns_connection:
            conn.commit()
    finally:
        if owns_connection:
            conn.close()


def insert_booking(date_str, room_code, tier, company, email, start_hour, blocks):
    end_hour = start_hour + blocks
    conn = get_db()
    try:
        ensure_rooms_seeded(conn)
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO bookings
              (date, room_code, tier, company, email, start_hour, end_hour, blocks, created_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,NOW())
            """,
            (date_str, room_code, tier, company, email, start_hour, end_hour, blocks),
        )
        conn.commit()
        return cur.lastrowid
    finally:
        conn.close()


def find_disabled_conflicts(date_str, room_code, start_hour, end_hour) -> bool:
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT 1 FROM disabled_slots
            WHERE date=%s AND room_code=%s
              AND NOT (%s <= start_hour OR end_hour <= %s)
            LIMIT 1
            """,
            (date_str, room_code, end_hour, start_hour),
        )
        return cur.fetchone() is not None
    finally:
        conn.close()


def insert_disabled_slot(date_str: str, room_code: str, start_hour: int, blocks: int, note: Optional[str] = None) -> int:
    end_hour = start_hour + blocks
    if start_hour not in HOURS or end_hour > HOURS[-1] + 1:
        raise ValueError("Invalid start hour or duration")

    conn = get_db()
    try:
        ensure_rooms_seeded(conn)
        cur = conn.cursor()
        cur.execute(
            """
            SELECT 1 FROM bookings
            WHERE date=%s AND room_code=%s
              AND NOT (%s <= start_hour OR end_hour <= %s)
            LIMIT 1
            """,
            (date_str, room_code, end_hour, start_hour),
        )
        if cur.fetchone():
            raise ValueError("A booking already exists in that period")

        cur.execute(
            """
            SELECT 1 FROM disabled_slots
            WHERE date=%s AND room_code=%s
              AND NOT (%s <= start_hour OR end_hour <= %s)
            LIMIT 1
            """,
            (date_str, room_code, end_hour, start_hour),
        )
        if cur.fetchone():
            raise ValueError("Slot already disabled for that period")

        cur.execute(
            """
            INSERT INTO disabled_slots (date, room_code, start_hour, end_hour, note, created_at)
            VALUES (%s,%s,%s,%s,%s,NOW())
            """,
            (date_str, room_code, start_hour, end_hour, note or None),
        )
        conn.commit()
        return cur.lastrowid
    finally:
        conn.close()


def delete_disabled_slot(slot_id: int) -> None:
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM disabled_slots WHERE id=%s", (slot_id,))
        if cur.rowcount == 0:
            raise ValueError("Disabled slot not found")
        conn.commit()
    finally:
        conn.close()


def delete_booking(booking_id: int):
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM bookings WHERE id=%s", (booking_id,))
        conn.commit()
    finally:
        conn.close()

def find_conflicts(date_str, room_code, start_hour, end_hour) -> bool:
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT 1 FROM bookings
            WHERE date=%s AND room_code=%s
              AND NOT (%s <= start_hour OR end_hour <= %s)
            LIMIT 1
            """,
            (date_str, room_code, end_hour, start_hour),
        )
        return cur.fetchone() is not None
    finally:
        conn.close()

def fetch_companies(tier=None):
    conn = get_db()
    try:
        cur = conn.cursor(DictCursor)
        if tier:
            cur.execute("SELECT id, name, tier FROM companies WHERE tier=%s ORDER BY name", (tier,))
        else:
            cur.execute("SELECT id, name, tier FROM companies ORDER BY name")
        return list(cur.fetchall())
    finally:
        conn.close()


def insert_company(name: str, tier: str) -> None:
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO companies (name, tier) VALUES (%s, %s)",
            (name, tier),
        )
        conn.commit()
    finally:
        conn.close()


def remove_company(company_id: int) -> Tuple[bool, str]:
    """Delete a company if it has no bookings. Returns (ok, message)."""

    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute("SELECT name FROM companies WHERE id=%s", (company_id,))
        row = cur.fetchone()
        if not row:
            return False, "Company not found"

        company_name = row[0]
        cur.execute("SELECT COUNT(*) FROM bookings WHERE company=%s", (company_name,))
        count = int(cur.fetchone()[0] or 0)
        if count:
            conn.rollback()
            return False, f"Cannot delete '{company_name}': {count} booking(s) exist."

        cur.execute("DELETE FROM companies WHERE id=%s", (company_id,))
        conn.commit()
        return True, f"Deleted '{company_name}'"
    finally:
        conn.close()

def get_company_tier(name):
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute("SELECT tier FROM companies WHERE name=%s", (name.strip(),))
        row = cur.fetchone()
        return row[0] if row else None
    finally:
        conn.close()

def get_company_daily_total(date_str: str, company_name: str) -> int:
    """특정 회사의 해당 날짜 총 예약 블록 수 합계 반환"""
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT COALESCE(SUM(blocks), 0)
            FROM bookings
            WHERE date=%s AND company=%s
            """,
            (date_str, company_name),
        )
        total = cur.fetchone()[0]
        return int(total or 0)
    finally:
        conn.close()

# --------------------------- pages ------------------------------
@app.get("/booking", response_class=HTMLResponse)
def booking_page(request: Request):
    today = datetime.utcnow().date().isoformat()
    initial_date = EVENT_DATES[0] if (today < EVENT_DATES[0] or today > EVENT_DATES[-1]) else today
    return templates.TemplateResponse(
        "booking.html",
        dict(
            request=request,
            event_dates=EVENT_DATES,
            rooms_by_tier=ROOMS_BY_TIER,
            room_label=ROOM_LABEL,
            hours=HOURS,
            initial_date=initial_date,
            max_blocks=MAX_BLOCKS,
            OTHER_ROOM_CODE=OTHER_ROOM_CODE,
        ),
    )

@app.get("/launcher", response_class=HTMLResponse)
def launcher_page(request: Request):
    return templates.TemplateResponse(
        "launcher.html",
        dict(
            request=request,
            event_dates=EVENT_DATES,
            rooms_by_tier=ROOMS_BY_TIER,
            room_label=ROOM_LABEL,
            tier_order=TIER_ORDER,
        ),
    )

@app.get("/display", response_class=HTMLResponse)
def display_page(request: Request, room: str, date: str):
    if date not in EVENT_DATES:
        raise HTTPException(status_code=400, detail="Invalid date")
    if room not in ROOM_LABEL:
        raise HTTPException(status_code=400, detail="Invalid room")

    raw = [r for r in fetch_bookings(date) if r["room_code"] == room]
    items = [
        {
            "company": r["company"],
            "tier": r["tier"],
            "room_code": r["room_code"],
            "date": str(r["date"]),
            "start_hour": int(r["start_hour"]),
            "end_hour": int(r["end_hour"]),
        }
        for r in raw
    ]
    return templates.TemplateResponse(
        "display.html",
        dict(request=request, room=room, room_name=ROOM_LABEL[room], date=date, hours=HOURS, items=items),
    )


@app.get("/", response_class=HTMLResponse)
def redirect_to_booking() -> RedirectResponse:
    """Serve the booking page as the default landing screen."""
    return RedirectResponse(url="/booking", status_code=302)


@app.get("/rooms", response_class=HTMLResponse)
def rooms_overview(request: Request):
    """Grouped overview of rooms by sponsor tier."""
    sections = []
    for tier in TIER_ORDER:
        codes = ROOMS_BY_TIER.get(tier, [])
        if not codes:
            continue
        sections.append(
            dict(
                tier=tier,
                tier_label=ROOM_TIER_LABELS.get(tier, tier),
                rooms=[ROOM_DETAILS[c] for c in codes],
            )
        )
    return templates.TemplateResponse("rooms.html", dict(request=request, sections=sections))


@app.get("/rooms/{room_code}", response_class=HTMLResponse)
def room_detail(request: Request, room_code: str):
    if room_code not in ROOM_DETAILS:
        raise HTTPException(status_code=404, detail="Room not found")
    details = ROOM_DETAILS[room_code]
    schedule_date = request.query_params.get("date") or EVENT_DATES[0]
    tier_label = ROOM_TIER_LABELS.get(details["tier"], details["tier"])
    return templates.TemplateResponse(
        "room_detail.html",
        dict(
            request=request,
            room_code=room_code,
            room_name=details["name"],
            details=details,
            tier_label=tier_label,
            schedule_date=schedule_date,
        ),
    )


@app.get("/admin", response_class=HTMLResponse)
def admin_page(
    request: Request,
    date: str | None = None,
    room: str | None = None,
    company_msg: str | None = None,
    company_error: str | None = None,
    disable_msg: str | None = None,
    disable_error: str | None = None,
):
    date_val = date or EVENT_DATES[0]
    all_items = fetch_bookings(date_val)
    room_filter = room or None
    if room_filter:
        all_items = [x for x in all_items if x["room_code"] == room_filter]

    disabled_items = fetch_disabled_slots(date_val, room_filter)

    companies = fetch_companies()
    company_groups: Dict[str, List[Dict[str, Any]]] = {tier: [] for tier in COMPANY_MANAGED_TIERS}
    for item in companies:
        tier = item["tier"]
        company_groups.setdefault(tier, []).append(item)
    return templates.TemplateResponse(
        "admin.html",
        dict(
            request=request,
            date=date_val,
            room=room_filter,
            items=all_items,
            disabled_items=disabled_items,
            event_dates=EVENT_DATES,
            room_label=ROOM_LABEL,
            hours=HOURS,
            max_blocks=MAX_BLOCKS,
            company_groups=company_groups,
            company_tiers=COMPANY_MANAGED_TIERS,
            company_msg=company_msg,
            company_error=company_error,
            disable_msg=disable_msg,
            disable_error=disable_error,
        ),
    )

# ------------------------ actions / APIs ------------------------
@app.post("/book")
def create_booking(
    company: str = Form(...),          # select 값 ('Other' 포함)
    email: str = Form(...),
    tier: str = Form(...),             # 클라이언트에서 세팅되지만 서버에서 검증
    date: str = Form(...),
    room: str = Form(...),
    start_hour: int = Form(...),
    blocks: int = Form(...),
    company_other: str | None = Form(None),  # Other일 때 수동 입력
):
    company = (company or "").strip()
    room = (room or "").strip()

    if date not in EVENT_DATES:
        raise HTTPException(status_code=400, detail="Invalid date")
    if room not in ROOM_LABEL:
        raise HTTPException(status_code=400, detail="Invalid room")

    # --- 회사/티어 확정 ---
    if company == "Other":
        real_company = (company_other or "").strip()
        if not real_company:
            raise HTTPException(status_code=400, detail="Company name required for Other")
        tier = "General"
        if room != OTHER_ROOM_CODE:
            raise HTTPException(status_code=400, detail="Other must use designated general room")
        company_to_save = real_company
    else:
        db_tier = get_company_tier(company)
        if not db_tier:
            raise HTTPException(status_code=400, detail="Unknown company")
        tier = db_tier
        # 티어-룸 매핑 검증
        if room not in ROOMS_BY_TIER.get(tier, []):
            raise HTTPException(status_code=400, detail="Room not allowed for company tier")
        company_to_save = company.strip()

    # --- 시간/블록 검증 ---
    blocks = max(1, min(MAX_BLOCKS, int(blocks)))
    start_hour = int(start_hour)
    end_hour = start_hour + blocks
    if start_hour not in HOURS or end_hour > HOURS[-1] + 1:
        raise HTTPException(status_code=400, detail="Invalid start hour")

    # --- 하루 총 2시간 제한(모든 티어/모든 룸 합산) ---
    current_total = get_company_daily_total(date, company_to_save)  # 현재까지 합계(블록)
    if current_total + blocks > MAX_BLOCKS:
        raise HTTPException(
            status_code=409,
            detail=f"Daily limit exceeded: {company_to_save} already has {current_total}h booked on {date}. Max {MAX_BLOCKS}h/day."
        )

    # --- 룸 시간대 충돌 ---
    if find_conflicts(date, room, start_hour, end_hour):
        raise HTTPException(status_code=409, detail="Time slot already taken")
    if find_disabled_conflicts(date, room, start_hour, end_hour):
        raise HTTPException(status_code=409, detail="Time slot blocked by administrator")

    # --- 저장 ---
    insert_booking(date, room, tier, company_to_save, email.strip(), start_hour, blocks)

    # 리다이렉트(입력 복원)
    params = {
        "ok": "1",
        "date": date,
        "room": room,
        "blocks": str(blocks),
        "picked": str(start_hour),
        "company": "Other" if company == "Other" else company_to_save,
    }
    if company == "Other":
        params["company_other"] = company_to_save
    qs = "&".join(f"{k}={quote_plus(v)}" for k, v in params.items())
    return RedirectResponse(url=f"/booking?{qs}", status_code=303)

@app.get("/api/availability")
def availability(date: str, room: str):
    if date not in EVENT_DATES:
        return JSONResponse({"error": "invalid date"}, status_code=400)
    rows = fetch_bookings(date)
    busy = [r for r in rows if r["room_code"] == room]
    disabled = fetch_disabled_slots(date, room)
    taken = [(int(r["start_hour"]), int(r["end_hour"])) for r in busy]
    taken.extend((int(r["start_hour"]), int(r["end_hour"])) for r in disabled)
    return {"room": room, "date": date, "taken": taken, "items": busy, "disabled": disabled}

@app.get("/api/companies")
def api_companies(tier: str | None = None):
    if tier and tier not in ROOMS_BY_TIER:
        return JSONResponse({"error": "invalid tier"}, status_code=400)
    return {"items": fetch_companies(tier)}

# 프런트 사전 안내용: 하루 총합 사용시간
@app.get("/api/daily_check")
def api_daily_check(date: str, company: str):
    if date not in EVENT_DATES:
        return {"ok": False, "reason": "invalid date"}
    total = get_company_daily_total(date, company)
    return {"ok": True, "total": total, "limit": MAX_BLOCKS}

# -------------------- Admin: Disabled slots --------------------
@app.post("/admin/disabled/add")
def admin_disabled_add(
    date: str = Form(...),
    room: str = Form(...),
    start_hour: int = Form(...),
    blocks: int = Form(...),
    note: str | None = Form(None),
):
    redirect_params: List[Tuple[str, str]] = []
    if date:
        redirect_params.append(("date", date))
    if room:
        redirect_params.append(("room", room))

    message: Optional[Tuple[str, str]] = None
    try:
        if date not in EVENT_DATES:
            raise ValueError("Invalid date selected")
        if room not in ROOM_LABEL:
            raise ValueError("Invalid room selected")
        start_val = int(start_hour)
        blocks_val = max(1, min(MAX_BLOCKS, int(blocks)))
        note_val = (note or "").strip()
        insert_disabled_slot(date, room, start_val, blocks_val, note_val or None)
    except ValueError as exc:
        message = ("disable_error", str(exc))
    except Exception:
        message = ("disable_error", "Failed to disable time slot")
    else:
        end_val = start_val + blocks_val
        label = ROOM_LABEL.get(room, room)
        message = ("disable_msg", f"Disabled {label} {date} {start_val:02d}:00 – {end_val:02d}:00")

    if message:
        redirect_params.append(message)

    qs = ""
    if redirect_params:
        qs = "?" + "&".join(f"{key}={quote_plus(value)}" for key, value in redirect_params)
    return RedirectResponse(url=f"/admin{qs}", status_code=303)


@app.post("/admin/disabled/delete")
def admin_disabled_delete(
    disabled_id: int = Form(...),
    date: str | None = Form(None),
    room: str | None = Form(None),
):
    redirect_params: List[Tuple[str, str]] = []
    if date:
        redirect_params.append(("date", date))
    if room:
        redirect_params.append(("room", room))

    try:
        delete_disabled_slot(disabled_id)
    except Exception as exc:
        redirect_params.append(("disable_error", str(exc)))
    else:
        redirect_params.append(("disable_msg", "Disabled slot removed"))

    qs = ""
    if redirect_params:
        qs = "?" + "&".join(f"{key}={quote_plus(value)}" for key, value in redirect_params)
    return RedirectResponse(url=f"/admin{qs}", status_code=303)


# ------------------------ Admin: Delete -------------------------
@app.post("/admin/delete")
def admin_delete(booking_id: int = Form(...), date: str | None = Form(None), room: str | None = Form(None)):
    """
    예약 삭제 후 /admin 으로 리다이렉트. (필터가 유지되도록 date/room 전달 지원)
    """
    try:
        delete_booking(booking_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # 필터 유지
    q = []
    if date: q.append(f"date={quote_plus(date)}")
    if room: q.append(f"room={quote_plus(room)}")
    qs = ("?" + "&".join(q)) if q else ""
    return RedirectResponse(url=f"/admin{qs}", status_code=303)


@app.post("/admin/companies/add")
def admin_company_add(tier: str = Form(...), name: str = Form(...)):
    tier = (tier or "").strip()
    name = (name or "").strip()

    params: List[tuple[str, str]] = []

    if tier not in COMPANY_MANAGED_TIERS:
        params.append(("company_error", "Invalid tier selected"))
    elif not name:
        params.append(("company_error", "Company name is required"))
    else:
        try:
            insert_company(name, tier)
        except IntegrityError:
            params.append(("company_error", f"'{name}' already exists"))
        else:
            params.append(("company_msg", f"Added '{name}' to {tier}"))

    qs = ""
    if params:
        qs = "?" + "&".join(f"{key}={quote_plus(value)}" for key, value in params)
    return RedirectResponse(url=f"/admin{qs}", status_code=303)


@app.post("/admin/companies/delete")
def admin_company_delete(company_id: int = Form(...)):
    ok, message = remove_company(company_id)
    key = "company_msg" if ok else "company_error"
    qs = f"?{key}={quote_plus(message)}" if message else ""
    return RedirectResponse(url=f"/admin{qs}", status_code=303)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=APP_HOST, port=APP_PORT)

