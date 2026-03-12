#!/usr/bin/env bash

# Purpose: prepare data and log directories for the referenced docker-compose app.
# Problem Solved: recreate the expected host-mounted directory structure and permissions.

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $0 [--dry-run]

Description:
  Reads DATA_DIRECTORY from .env when present and creates the middleware data/log paths.
EOF
}

load_env_value() {
    local key="$1"
    local line value
    line="$(grep -E "^${key}=" .env | tail -n 1 || true)"
    [[ -n "$line" ]] || return 1
    value="${line#*=}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    printf '%s' "$value"
}

DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        "")
            break
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Load DATA_DIRECTORY from .env if it exists, fallback to /data
if [ -f ".env" ]; then
    DATA_DIRECTORY="$(load_env_value DATA_DIRECTORY || true)"
fi
DATA_DIRECTORY=${DATA_DIRECTORY:-/data}

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would create middleware directories under '$DATA_DIRECTORY'."
    echo "Dry run: would set ownership to 1000:1000 and permissions to 775 for logs."
    exit 0
fi

echo "Ensuring data directories exist at $DATA_DIRECTORY..."
sudo mkdir -p "$DATA_DIRECTORY/middleware/db"
sudo mkdir -p "$DATA_DIRECTORY/middleware/logs/api"
sudo mkdir -p "$DATA_DIRECTORY/middleware/logs/beat"

echo "Setting permissions for logs..."
# Middleware user UID 1000 needs write access to logs
sudo chown -R 1000:1000 "$DATA_DIRECTORY/middleware/logs"
sudo chmod -R 775 "$DATA_DIRECTORY/middleware/logs"

echo "Log directories setup complete."
ls -R "$DATA_DIRECTORY/middleware/logs"
