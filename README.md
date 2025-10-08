# apec-book

## Scheduling email sends

To queue the existing `send_email.sh` script so that it runs automatically at a future time (for example, 2025-10-29 at 08:00), use the helper script:

```bash
./schedule_email.sh 20251029 0800
```

This command relies on the system `at` daemon. Make sure the `at` package is installed and the atd service is active. The script forwards the `ENV_FILE` and `DRY_RUN` environment variables (if provided) to `send_email.sh`.

After scheduling, you can check pending jobs with `atq` and cancel a job with `atrm <job_id>`.

## Database setup

The application expects a MySQL schema that matches `models.sql`. The file is idempotent,
so you can rerun it whenever new tables or columns are added. There are two common ways to
apply it:

### Using the MySQL CLI

```bash
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" < models.sql
```

Replace the environment variables with the values from your deployment (they map to the
`MYSQL_*` settings consumed by `app.py`). When prompted, enter the password for the MySQL
user. This command will create any missing tables—including the booking window override
table introduced for the reservation window feature—and seed the default room and company
data.

### From an interactive MySQL shell

```bash
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p
mysql> SOURCE /absolute/path/to/models.sql;
```

If your database runs inside Docker, prefix the commands with `docker exec -i <container>`
so they run in the correct container, for example:

```bash
docker exec -i mysql-container mysql -u apec -p"secret" apec_booking < models.sql
```

Confirm the schema update by checking that the `booking_windows` table exists:

```bash
mysql> USE apec_booking;
mysql> SHOW TABLES LIKE 'booking_windows';
```
