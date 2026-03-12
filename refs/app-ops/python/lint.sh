#!/usr/bin/env bash

# Purpose: run type-checking and lint validation for the referenced Python app.
# Problem Solved: encode the expected lint stack for that app layout.

set -euo pipefail

APP_DIR="app"
DRY_RUN=false

usage() {
    cat <<EOF
Usage:
  $0 [--app-dir DIR] [--dry-run]

Description:
  Runs mypy, Ruff checks, and Ruff format validation against the referenced app directory.

Options:
  --app-dir DIR   App directory to lint (default: app)
  --dry-run       Print the lint commands without running them
  -h, --help      Show this help message
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
        --app-dir)
            [[ $# -ge 2 ]] || { echo "Error: --app-dir requires a value." >&2; exit 1; }
            APP_DIR="$2"
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
    echo "Dry run: would run 'mypy $APP_DIR'."
    echo "Dry run: would run 'ruff check $APP_DIR'."
    echo "Dry run: would run 'ruff format $APP_DIR --check'."
    exit 0
fi

require_command mypy
require_command ruff
[[ -d "$APP_DIR" ]] || { echo "Error: app directory '$APP_DIR' not found." >&2; exit 1; }

mypy "$APP_DIR"
ruff check "$APP_DIR"
ruff format "$APP_DIR" --check
