#!/usr/bin/env bash

# Purpose: run the reference Python test suite under coverage.
# Problem Solved: capture the expected coverage-based test command for the original app.

set -euo pipefail

APP_DIR="app"
COVERAGE_TITLE="coverage"
DRY_RUN=false

usage() {
    cat <<EOF
Usage:
  $0 [coverage-html-title] [--app-dir DIR] [--dry-run]

Description:
  Runs pytest under coverage, prints a missing-lines report, and generates HTML coverage output.

Options:
  coverage-html-title  Title to use for coverage HTML output (default: coverage)
  --app-dir DIR        App directory passed to coverage --source (default: app)
  --dry-run            Print the coverage commands without running them
  -h, --help           Show this help message
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
        --*)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
        *)
            COVERAGE_TITLE="$1"
            shift
            ;;
    esac
done

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would run 'coverage run --source=$APP_DIR -m pytest'."
    echo "Dry run: would run 'coverage report --show-missing'."
    echo "Dry run: would run 'coverage html --title $COVERAGE_TITLE'."
    exit 0
fi

require_command coverage
require_command pytest
[[ -d "$APP_DIR" ]] || { echo "Error: app directory '$APP_DIR' not found." >&2; exit 1; }

coverage run --source="$APP_DIR" -m pytest
coverage report --show-missing
coverage html --title "$COVERAGE_TITLE"
