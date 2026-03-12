#!/usr/bin/env bash

# Purpose: run app prestart checks and migrations before service startup.
# Problem Solved: preserve the reference sequence used by the original Python app before launch.

set -euo pipefail

PRESTART_MODULE="app.backend_pre_start"
MIGRATIONS_MODULE="app.backend_migrations"
DRY_RUN=false

usage() {
    cat <<EOF
Usage:
  $0 [--prestart-module MODULE] [--migrations-module MODULE] [--dry-run]

Description:
  Runs the backend pre-start module and backend migrations via uv.

Options:
  --prestart-module MODULE     Module to run before migrations
                              (default: app.backend_pre_start)
  --migrations-module MODULE   Module to run for migrations
                              (default: app.backend_migrations)
  --dry-run                    Print the planned uv commands without running them
  -h, --help                   Show this help message
EOF
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: required command '$1' was not found." >&2
        exit 1
    }
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prestart-module)
            [[ $# -ge 2 ]] || { echo "Error: --prestart-module requires a value." >&2; exit 1; }
            PRESTART_MODULE="$2"
            shift 2
            ;;
        --migrations-module)
            [[ $# -ge 2 ]] || { echo "Error: --migrations-module requires a value." >&2; exit 1; }
            MIGRATIONS_MODULE="$2"
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
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would run 'uv run python -m $PRESTART_MODULE'."
    echo "Dry run: would run 'uv run python -m $MIGRATIONS_MODULE'."
    exit 0
fi

require_command uv

uv run python -m "$PRESTART_MODULE"
uv run python -m "$MIGRATIONS_MODULE"
