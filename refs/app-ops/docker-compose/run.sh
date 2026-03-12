#!/usr/bin/env bash

# Purpose: run the reference app in docker compose watch mode after linting.
# Problem Solved: encode the expected local development startup sequence for this app pattern.

set -euo pipefail

DRY_RUN=false
PROJECT_ROOT="$PWD"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage:
  $0 [--project-dir DIR] [--dry-run]

Description:
  Runs the sibling lint script and then starts 'docker compose watch' from the target project directory.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-dir)
            [[ $# -ge 2 ]] || { echo "Error: --project-dir requires a value." >&2; exit 1; }
            PROJECT_ROOT="$2"
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

echo "🔍 Running lint checks..."
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would run '$SCRIPT_DIR/lint.sh' from '$PROJECT_ROOT'."
    echo "Dry run: would run 'sudo docker compose watch' from '$PROJECT_ROOT'."
    exit 0
fi
cd "$PROJECT_ROOT"
"$SCRIPT_DIR/lint.sh"

echo "🚀 Starting Docker Compose in watch mode for live development... ⏳"
sudo docker compose watch
