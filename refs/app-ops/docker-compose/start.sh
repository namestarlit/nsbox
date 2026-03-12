#!/usr/bin/env bash

# Purpose: start the reference Docker Compose app after its expected prep steps.
# Problem Solved: preserve the original start sequence for this app pattern.

set -euo pipefail

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --db CONTAINER_ID    Import a SQL file into the specified database container"
    echo "  --project-dir DIR    Run the workflow from DIR instead of the current directory"
    echo "  --help               Show this help message"
    echo "  --migrations         Only generate migrations and exit"
    echo ""
    echo "Example:"
    echo "  $0 --db middleware-db-1"
}

# Parse arguments
DB_CONTAINER=""
MIGRATIONS_ONLY=false
DRY_RUN=false
PROJECT_ROOT="$PWD"
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --db)
            [[ $# -ge 2 ]] || { echo "Error: --db requires a value." >&2; show_help; exit 1; }
            DB_CONTAINER="$2"
            shift
            ;;
        --project-dir)
            [[ $# -ge 2 ]] || { echo "Error: --project-dir requires a value." >&2; show_help; exit 1; }
            PROJECT_ROOT="$2"
            shift
            ;;
        --migrations) MIGRATIONS_ONLY=true ;;
        --dry-run) DRY_RUN=true ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$PROJECT_ROOT"

# 0. Generate Migrations
if [ -f "$SCRIPT_DIR/makemigrations.sh" ]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "Dry run: would run '$SCRIPT_DIR/makemigrations.sh --project-dir $PROJECT_ROOT'."
    else
        "$SCRIPT_DIR/makemigrations.sh" --project-dir "$PROJECT_ROOT"
    fi
else
    echo "⚠️ sibling makemigrations.sh not found, skipping."
fi

if [ "$MIGRATIONS_ONLY" = true ]; then
    echo "Migrations generated. Exiting because --migrations was requested."
    exit 0
fi

# 1. Run Linting
echo "🔍 Running lint checks..."
if [ -f "$SCRIPT_DIR/lint.sh" ]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "Dry run: would run '$SCRIPT_DIR/lint.sh' from '$PROJECT_ROOT'."
    else
        "$SCRIPT_DIR/lint.sh"
    fi
else
    echo "⚠️ sibling lint.sh not found, skipping."
fi

# 2. Run Setup Logs
echo "📁 Preparing data directories..."
if [ -f "$SCRIPT_DIR/setup_logs.sh" ]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "Dry run: would run '$SCRIPT_DIR/setup_logs.sh' from '$PROJECT_ROOT'."
    else
        "$SCRIPT_DIR/setup_logs.sh"
    fi
else
    echo "⚠️ sibling setup_logs.sh not found, skipping."
fi

# 3. Start the Stack
echo "🚀 Starting Docker Compose up -d --build..."
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would run 'sudo docker compose up -d --build'."
else
    sudo docker compose up -d --build
fi

# 4. Optional DB Import
if [ -n "$DB_CONTAINER" ]; then
    if [ -f "$SCRIPT_DIR/import_db.sh" ]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "Dry run: would run '$SCRIPT_DIR/import_db.sh $DB_CONTAINER' from '$PROJECT_ROOT'."
        else
            "$SCRIPT_DIR/import_db.sh" "$DB_CONTAINER"
        fi
    else
        echo "⚠️ sibling import_db.sh not found, skipping DB import."
    fi
fi

# 5. Show Logs
echo "📜 Tailing logs (Ctrl+C to stop)..."
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would run 'sudo docker compose logs -f'."
    exit 0
fi
sudo docker compose logs -f
