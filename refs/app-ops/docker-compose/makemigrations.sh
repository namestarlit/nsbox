#!/usr/bin/env bash

# Purpose: generate Django migrations in the referenced app project.
# Problem Solved: remember the expected uv-based command for makemigrations.

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $0 [--project-dir DIR]

Description:
  Runs 'uv run python manage.py makemigrations' from the target project directory.
EOF
}

PROJECT_ROOT="$PWD"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-dir)
            [[ $# -ge 2 ]] || { echo "Error: --project-dir requires a value." >&2; exit 1; }
            PROJECT_ROOT="$2"
            shift 2
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

cd "$PROJECT_ROOT"

echo "🔨 Generating migrations..."

# Using uv as strictly required
uv run python manage.py makemigrations

echo "✅ Migrations generated successfully."
