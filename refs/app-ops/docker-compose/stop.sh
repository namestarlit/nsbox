#!/usr/bin/env bash

# Purpose: stop the reference Docker Compose app and optionally back up or clean its data.
# Problem Solved: preserve the original stop/cleanup sequence for this app pattern.

set -euo pipefail

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --db CONTAINER_ID    Backup database from this container before stopping"
    echo "  --clean              Remove all volumes, images, and the data directory defined in DATA_DIRECTORY"
    echo "  --project-dir DIR    Run the workflow from DIR instead of the current directory"
    echo "  --help               Show this help message"
}

BACKUP_CONTAINER=""
CLEAN=false
DRY_RUN=false
PROJECT_ROOT="$PWD"

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
        --db)
            [[ $# -ge 2 ]] || { echo "Error: --db requires a value." >&2; show_help; exit 1; }
            BACKUP_CONTAINER="$2"
            shift
            ;;
        --clean) CLEAN=true ;;
        --project-dir)
            [[ $# -ge 2 ]] || { echo "Error: --project-dir requires a value." >&2; show_help; exit 1; }
            PROJECT_ROOT="$2"
            shift
            ;;
        --dry-run) DRY_RUN=true ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# 1. Backup if requested
if [ -n "$BACKUP_CONTAINER" ]; then
    echo "💾 Backing up database..."
    if [ -f "$SCRIPT_DIR/dump_db.sh" ]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "Dry run: would run '$SCRIPT_DIR/dump_db.sh $BACKUP_CONTAINER' from '$PROJECT_ROOT'."
        else
            "$SCRIPT_DIR/dump_db.sh" "$BACKUP_CONTAINER"
        fi
    else
        echo "⚠️ sibling dump_db.sh not found, skipping backup."
    fi
fi

# 2. Stop the stack
echo "🛑 Stopping Docker Compose stack..."
if [ "$CLEAN" = true ]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "Dry run: would run from '$PROJECT_ROOT'."
        echo "Dry run: would run 'sudo docker compose down --rmi all --volumes --remove-orphans'."
    else
        sudo docker compose down --rmi all --volumes --remove-orphans
    fi
else
    if [[ "$DRY_RUN" == true ]]; then
        echo "Dry run: would run from '$PROJECT_ROOT'."
        echo "Dry run: would run 'sudo docker compose down'."
    else
        sudo docker compose down
    fi
fi

# 3. Clean local data if requested
if [ "$CLEAN" = true ]; then
    # Load DATA_DIRECTORY from .env if it exists, fallback to /data
    if [ -f ".env" ]; then
        DATA_DIRECTORY="$(load_env_value DATA_DIRECTORY || true)"
    fi
    DATA_DIRECTORY=${DATA_DIRECTORY:-/data}

    echo "⚠️ CLEAN option enabled. Removing data directory at $DATA_DIRECTORY/middleware..."
    if [ -d "$DATA_DIRECTORY/middleware" ]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "Dry run: would remove '$DATA_DIRECTORY/middleware'."
        else
            sudo rm -rf "$DATA_DIRECTORY/middleware"
            echo "✅ Data directory removed."
        fi
    else
        echo "ℹ️  Data directory $DATA_DIRECTORY/middleware not found."
    fi
fi

echo "✅ System stopped successfully."
