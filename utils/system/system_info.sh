#!/usr/bin/env bash

# Purpose: display a compact system and hardware summary.
# Problem Solved: quick host inspection without remembering the full inxi command.

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $0

Description:
  Runs 'inxi -Fz' to display system and hardware information with sensitive fields redacted.
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

command -v inxi >/dev/null 2>&1 || {
    echo "Error: inxi is required." >&2
    exit 1
}

if inxi -Fz; then
    exit 0
fi

echo "Retrying with sudo for extended system details..." >&2
sudo inxi -Fz
