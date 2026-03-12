#!/usr/bin/env bash

# Purpose: reset one or more Superset user passwords inside a running container.
# Problem Solved: batch password resets while capturing a credentials file and audit-style CSV report.

set -euo pipefail

OUTPUT_FILE="superset_passwords.txt"
REPORT_FILE="superset_passwords_report.csv"
CONTAINER=""
USERNAMES=()
USERS_FILE=""
CSV_FILE=""
USERNAME_COLUMN="username"
EMAIL_COLUMN="email"
ROLE_COLUMN="role"
FILTER_ROLE=""
EXCLUDE_ROLE=""
DOCKER_BIN="sudo docker"
PASSWORD_BYTES=4
DRY_RUN=false
TEMP_CSV_RECORDS=""

usage() {
  cat <<EOF
Usage:
  $0 CONTAINER [--usernames user1 user2 ...] [--users-file users.txt] [--csv users.csv]
               [--username-column username] [--email-column email] [--role-column role]
               [--filter-role ROLE] [--exclude-role ROLE]
               [--output FILE] [--report FILE] [--password-bytes N] [--dry-run]

Arguments:
  CONTAINER              Docker container name or ID running Superset

Input options:
  --usernames            One or more Superset usernames
  --users-file           Plain text file with one username per line
  --csv                  CSV file containing usernames and optional metadata

CSV options:
  --username-column      Username column name in CSV (default: username)
  --email-column         Email column name in CSV (default: email)
  --role-column          Role column name in CSV (default: role)
  --filter-role          Only process rows matching this role
  --exclude-role         Skip rows matching this role

Output options:
  --output               File to write username:password pairs
                         (default: superset_passwords.txt)
  --report               CSV report file
                         (default: superset_passwords_report.csv)

Other:
  --password-bytes       Number of random bytes passed to 'openssl rand -hex'
                         (default: 4, resulting in 8 hex chars)
  --dry-run              Print the planned reset operations without changing Superset
  -h, --help             Show this help message

Examples:
  $0 superset_app --usernames admin analyst viewer
  $0 superset_app --users-file users.txt
  $0 superset_app --csv users.csv
  $0 superset_app --csv users.csv --filter-role Gamma
  $0 superset_app --csv users.csv --exclude-role Admin --output creds.txt --report report.csv
EOF
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

cleanup() {
  [[ -n "$TEMP_CSV_RECORDS" ]] && rm -f "$TEMP_CSV_RECORDS"
}

trap cleanup EXIT

parse_csv_records() {
  local csv_path="$1"
  local username_column="$2"
  local email_column="$3"
  local role_column="$4"
  local filter_role="$5"
  local exclude_role="$6"

  python3 - "$csv_path" "$username_column" "$email_column" "$role_column" "$filter_role" "$exclude_role" <<'PY'
import csv
import sys

csv_path, username_column, email_column, role_column, filter_role, exclude_role = sys.argv[1:7]

with open(csv_path, newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    if reader.fieldnames is None:
        print("Error: CSV file is empty", file=sys.stderr)
        sys.exit(1)
    if username_column not in reader.fieldnames:
        print(f"Error: username column '{username_column}' not found in CSV", file=sys.stderr)
        sys.exit(1)

    for row in reader:
        username = (row.get(username_column) or "").strip()
        email = (row.get(email_column) or "").strip() if email_column in reader.fieldnames else ""
        role = (row.get(role_column) or "").strip() if role_column in reader.fieldnames else ""
        if not username:
            continue
        if filter_role and role != filter_role:
            continue
        if exclude_role and role == exclude_role:
            continue
        print(f"{username}|{email}|{role}")
PY
}

# ---- parse args ----

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --*)
    echo "Error: first argument must be the container name or ID"
    usage
    exit 1
    ;;
  *)
    CONTAINER="$1"
    shift
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --usernames)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        USERNAMES+=("$1")
        shift
      done
      ;;
    --users-file)
      [[ $# -lt 2 ]] && { echo "Error: --users-file requires a value"; exit 1; }
      USERS_FILE="$2"
      shift 2
      ;;
    --csv)
      [[ $# -lt 2 ]] && { echo "Error: --csv requires a value"; exit 1; }
      CSV_FILE="$2"
      shift 2
      ;;
    --username-column)
      [[ $# -lt 2 ]] && { echo "Error: --username-column requires a value"; exit 1; }
      USERNAME_COLUMN="$2"
      shift 2
      ;;
    --email-column)
      [[ $# -lt 2 ]] && { echo "Error: --email-column requires a value"; exit 1; }
      EMAIL_COLUMN="$2"
      shift 2
      ;;
    --role-column)
      [[ $# -lt 2 ]] && { echo "Error: --role-column requires a value"; exit 1; }
      ROLE_COLUMN="$2"
      shift 2
      ;;
    --filter-role)
      [[ $# -lt 2 ]] && { echo "Error: --filter-role requires a value"; exit 1; }
      FILTER_ROLE="$2"
      shift 2
      ;;
    --exclude-role)
      [[ $# -lt 2 ]] && { echo "Error: --exclude-role requires a value"; exit 1; }
      EXCLUDE_ROLE="$2"
      shift 2
      ;;
    --output)
      [[ $# -lt 2 ]] && { echo "Error: --output requires a value"; exit 1; }
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --report)
      [[ $# -lt 2 ]] && { echo "Error: --report requires a value"; exit 1; }
      REPORT_FILE="$2"
      shift 2
      ;;
    --password-bytes)
      [[ $# -lt 2 ]] && { echo "Error: --password-bytes requires a value"; exit 1; }
      PASSWORD_BYTES="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

[[ "$PASSWORD_BYTES" =~ ^[0-9]+$ ]] || {
  echo "Error: --password-bytes must be a positive integer" >&2
  exit 1
}
(( PASSWORD_BYTES > 0 )) || {
  echo "Error: --password-bytes must be greater than zero" >&2
  exit 1
}

# ---- validate dependencies ----

command -v openssl >/dev/null 2>&1 || {
  echo "Error: openssl is required"
  exit 1
}

if [[ -n "$CSV_FILE" ]]; then
  command -v python3 >/dev/null 2>&1 || {
    echo "Error: python3 is required for robust CSV parsing." >&2
    exit 1
  }
fi

if [[ "$DRY_RUN" == false ]]; then
  command -v sudo >/dev/null 2>&1 || {
    echo "Error: sudo is not installed or not in PATH"
    exit 1
  }

  command -v docker >/dev/null 2>&1 || {
    echo "Error: docker is not installed or not in PATH"
    exit 1
  }
fi

if [[ -n "$USERS_FILE" && ! -f "$USERS_FILE" ]]; then
  echo "Error: users file '$USERS_FILE' not found"
  exit 1
fi

if [[ -n "$CSV_FILE" && ! -f "$CSV_FILE" ]]; then
  echo "Error: CSV file '$CSV_FILE' not found"
  exit 1
fi

# ---- collect from plain users file ----

if [[ -n "$USERS_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    USERNAMES+=("$line")
  done < "$USERS_FILE"
fi

# ---- prepare CSV temp records ----
# format: username|email|role

CSV_RECORDS=()

if [[ -n "$CSV_FILE" ]]; then
  TEMP_CSV_RECORDS="$(mktemp /tmp/reset_superset_csv_records.XXXXXX)"
  parse_csv_records "$CSV_FILE" "$USERNAME_COLUMN" "$EMAIL_COLUMN" "$ROLE_COLUMN" "$FILTER_ROLE" "$EXCLUDE_ROLE" > "$TEMP_CSV_RECORDS"

  while IFS='|' read -r username email role; do
    USERNAMES+=("$username")
    CSV_RECORDS+=("$username|$email|$role")
  done < "$TEMP_CSV_RECORDS"
fi

if [[ ${#USERNAMES[@]} -eq 0 ]]; then
  echo "Error: no usernames provided"
  usage
  exit 1
fi

# de-duplicate usernames while preserving first occurrence
mapfile -t USERNAMES < <(printf '%s\n' "${USERNAMES[@]}" | awk '!seen[$0]++')

if [[ "$DRY_RUN" == false ]]; then
  if ! sudo -n true 2>/dev/null; then
    echo "Notice: sudo may prompt for your password."
  fi

  $DOCKER_BIN inspect "$CONTAINER" >/dev/null 2>&1 || {
    echo "Error: container '$CONTAINER' not found"
    exit 1
  }

  if ! $DOCKER_BIN exec "$CONTAINER" sh -c "command -v superset >/dev/null 2>&1"; then
    echo "Error: 'superset' command not found inside container '$CONTAINER'"
    exit 1
  fi

  touch "$OUTPUT_FILE"
  touch "$REPORT_FILE"
  chmod 600 "$OUTPUT_FILE" "$REPORT_FILE" 2>/dev/null || true

  if [[ ! -s "$REPORT_FILE" ]]; then
    echo "username,email,role,status,password" > "$REPORT_FILE"
  fi
fi

get_csv_meta() {
  local lookup_user="$1"
  local record
  for record in "${CSV_RECORDS[@]:-}"; do
    IFS='|' read -r u e r <<< "$record"
    if [[ "$u" == "$lookup_user" ]]; then
      printf '%s|%s' "$e" "$r"
      return 0
    fi
  done
  printf '|'
}

SUCCESS_COUNT=0
FAIL_COUNT=0

echo "Container: $CONTAINER"
echo "Output file: $OUTPUT_FILE"
echo "Report file: $REPORT_FILE"
echo "Users to process: ${#USERNAMES[@]}"
[[ -n "$USERS_FILE" ]] && echo "Users file: $USERS_FILE"
[[ -n "$CSV_FILE" ]] && echo "CSV file: $CSV_FILE"
[[ -n "$FILTER_ROLE" ]] && echo "Filter role: $FILTER_ROLE"
[[ -n "$EXCLUDE_ROLE" ]] && echo "Exclude role: $EXCLUDE_ROLE"
echo

for USERNAME in "${USERNAMES[@]}"; do
  PASSWORD="$(openssl rand -hex "$PASSWORD_BYTES")"
  META="$(get_csv_meta "$USERNAME")"
  EMAIL="${META%%|*}"
  ROLE="${META#*|}"

  echo "Resetting password for user: $USERNAME"

  if [[ "$DRY_RUN" == true ]]; then
    echo "  Dry run -> would run: $DOCKER_BIN exec $CONTAINER superset fab reset-password --username $USERNAME --password <generated>"
    echo "  Dry run -> would record status in $REPORT_FILE and credentials in $OUTPUT_FILE"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  elif $DOCKER_BIN exec "$CONTAINER" \
      superset fab reset-password \
      --username "$USERNAME" \
      --password "$PASSWORD"; then

    echo "${USERNAME}:${PASSWORD}" >> "$OUTPUT_FILE"
    echo "\"$USERNAME\",\"$EMAIL\",\"$ROLE\",\"success\",\"$PASSWORD\"" >> "$REPORT_FILE"
    echo "  Success -> ${USERNAME}:${PASSWORD}"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo "\"$USERNAME\",\"$EMAIL\",\"$ROLE\",\"failed\",\"\"" >> "$REPORT_FILE"
    echo "  Failed for user: $USERNAME" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  echo
done

echo "Done."
echo "Successful: $SUCCESS_COUNT"
echo "Failed: $FAIL_COUNT"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: no files were written."
else
  echo "Credentials saved to: $OUTPUT_FILE"
  echo "Report saved to: $REPORT_FILE"
  echo "File permissions set to: 600 (best effort)"
fi
