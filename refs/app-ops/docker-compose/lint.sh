#!/usr/bin/env bash

# Purpose: lint and format a Docker-based Python app with uv and Ruff.
# Problem Solved: provide one command for the app's common linting sequence.

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $0

Description:
  Runs Ruff checks, import sorting, and formatting via uv for the current app repository.
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
esac

echo "Running Ruff Linter..."
uv run ruff check --fix

echo "Running Ruff Import Sorting..."
uv run ruff check --select I --fix

echo "Running Ruff Formatter..."
uv run ruff format

echo "Linting and formatting completed successfully."
