#!/usr/bin/env bash

# Purpose: dump a Postgres database from a running container used by the reference app stack.
# Problem Solved: preserve the container-based export flow used in the original repo.

set -euo pipefail

# Function to display help
show_help() {
    echo "Usage: $0 CONTAINER_ID/NAME [--file SQL_FILE] [--dry-run]"
    echo ""
    echo "Options:"
    echo "  CONTAINER      ID or name of the database container"
    echo "  --file         Path to save the SQL dump file (default: scripts/lims.sql in the original app)"
    echo "  --dry-run      Print the planned export without running pg_dump"
    echo "  --help         Show this help message"
}

CONTAINER=""
SQL_FILE="scripts/lims.sql"
DB_USER=""
DB_NAME=""
DRY_RUN=false

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

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        --file)
            [[ $# -ge 2 ]] || { echo "Error: --file requires a value." >&2; show_help; exit 1; }
            SQL_FILE="$2"
            shift
            ;;
        --dry-run) DRY_RUN=true ;;
        --*)
            echo "Unknown parameter: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$CONTAINER" ]]; then
                CONTAINER="$1"
            else
                echo "Unexpected positional argument: $1"
                show_help
                exit 1
            fi
            ;;
    esac
    shift
done

if [ -z "$CONTAINER" ]; then
    echo "❌ Error: container is required."
    show_help
    exit 1
fi

if [[ "$DRY_RUN" == false ]]; then
    if [ ! -f ".env" ]; then
        echo "❌ Error: .env file not found. Cannot determine database credentials."
        exit 1
    fi

    DB_USER="$(load_env_value DB_USER || true)"
    DB_NAME="$(load_env_value DB_NAME || true)"
    if [[ -z "$DB_USER" || -z "$DB_NAME" ]]; then
        echo "❌ Error: DB_USER and DB_NAME must be present in .env." >&2
        exit 1
    fi
else
    DB_USER="${DB_USER:-<from .env>}"
    DB_NAME="${DB_NAME:-<from .env>}"
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would export database from container '$CONTAINER' to '$SQL_FILE'."
    echo "Dry run: would run pg_dump with DB_USER='$DB_USER' and DB_NAME='$DB_NAME'."
    exit 0
fi

mkdir -p "$(dirname "$SQL_FILE")"

echo "💾 Exporting database from container $CONTAINER to $SQL_FILE..."
# Use pg_dump to create the dump
sudo docker exec "$CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" > "$SQL_FILE"
echo "✅ Database dump completed: $SQL_FILE"
