#!/usr/bin/env bash

# Purpose: auto-fix Ruff issues and format the referenced Python app.
# Problem Solved: provide a one-shot formatting command for the original app layout.

set -euo pipefail

APP_DIR="app"
SCRIPTS_DIR="scripts"
DRY_RUN=false

usage() {
    cat <<EOF
Usage:
  $0 [--app-dir DIR] [--scripts-dir DIR] [--dry-run]

Description:
  Runs 'ruff check --fix' and 'ruff format' against the referenced app layout.

Options:
  --app-dir DIR       App directory to format (default: app)
  --scripts-dir DIR   Scripts directory to format (default: scripts)
  --dry-run           Print the Ruff commands without running them
  -h, --help          Show this help message
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
        --scripts-dir)
            [[ $# -ge 2 ]] || { echo "Error: --scripts-dir requires a value." >&2; exit 1; }
            SCRIPTS_DIR="$2"
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
    echo "Dry run: would run 'ruff check --fix $APP_DIR $SCRIPTS_DIR'."
    echo "Dry run: would run 'ruff format $APP_DIR $SCRIPTS_DIR'."
    exit 0
fi

require_command ruff
[[ -d "$APP_DIR" ]] || { echo "Error: app directory '$APP_DIR' not found." >&2; exit 1; }
[[ -d "$SCRIPTS_DIR" ]] || { echo "Error: scripts directory '$SCRIPTS_DIR' not found." >&2; exit 1; }

ruff check --fix "$APP_DIR" "$SCRIPTS_DIR"
ruff format "$APP_DIR" "$SCRIPTS_DIR"
