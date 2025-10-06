#!/usr/bin/env bash
set -euo pipefail

# Schedules send_email.sh to run at a given date/time using the `at` command.
#
# Usage:
#   ./schedule_email.sh 20251029 0800
#     -> schedules send_email.sh 20251029 to run at 2025-10-29 08:00 local time
#
# Environment variables:
#   ENV_FILE - forwarded to send_email.sh (default: /opt/apec-booking/.env)
#   DRY_RUN  - forwarded to send_email.sh (default: 0)
#
# Requirements:
#   - `at` command must be installed and the atd service running.
#   - send_email.sh must be executable.

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 yyyymmdd hhmm" >&2
  echo "Example: $0 20251029 0800" >&2
  exit 1
fi

YMD="$1"
HM="$2"

if [[ ! "$YMD" =~ ^[0-9]{8}$ ]]; then
  echo "Invalid date: $YMD (expected yyyymmdd)" >&2
  exit 1
fi

if [[ ! "$HM" =~ ^[0-9]{4}$ ]]; then
  echo "Invalid time: $HM (expected hhmm in 24h format)" >&2
  exit 1
fi

HH="${HM:0:2}"
MM="${HM:2:2}"
if (( 10#$HH > 23 )) || (( 10#$MM > 59 )); then
  echo "Invalid time: $HM (hour 00-23, minute 00-59)" >&2
  exit 1
fi

if ! command -v at >/dev/null 2>&1; then
  echo "The 'at' command is required but not found in PATH." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEND_SCRIPT="${SCRIPT_DIR}/send_email.sh"

if [[ ! -x "$SEND_SCRIPT" ]]; then
  echo "send_email.sh is not executable at $SEND_SCRIPT" >&2
  exit 1
fi

ENV_FILE_DEFAULT="/opt/apec-booking/.env"
ENV_FILE_VALUE="${ENV_FILE:-$ENV_FILE_DEFAULT}"
DRY_RUN_VALUE="${DRY_RUN:-0}"

JOB_TIME="${YMD}${HM}"

printf -v CMD 'cd %q && ENV_FILE=%q DRY_RUN=%q %q %q' \
  "$SCRIPT_DIR" \
  "$ENV_FILE_VALUE" \
  "$DRY_RUN_VALUE" \
  "$SEND_SCRIPT" \
  "$YMD"

printf '%s\n' "$CMD" | at -t "$JOB_TIME"

AT_JOB_ID=$(atq | awk 'NR==1 {print $1}')
if [[ -n "${AT_JOB_ID:-}" ]]; then
  echo "[+] Scheduled send_email.sh for ${YMD} at ${HH}:${MM}. at job id: ${AT_JOB_ID}"
  echo "    Use 'atq' to list or 'atrm ${AT_JOB_ID}' to cancel."
else
  echo "[+] Scheduled send_email.sh for ${YMD} at ${HH}:${MM}."
fi
