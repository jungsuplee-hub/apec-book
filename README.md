# apec-book

## Scheduling email sends

To queue the existing `send_email.sh` script so that it runs automatically at a future time (for example, 2025-10-29 at 08:00), use the helper script:

```bash
./schedule_email.sh 20251029 0800
```

This command relies on the system `at` daemon. Make sure the `at` package is installed and the atd service is active. The script forwards the `ENV_FILE` and `DRY_RUN` environment variables (if provided) to `send_email.sh`.

After scheduling, you can check pending jobs with `atq` and cancel a job with `atrm <job_id>`.
