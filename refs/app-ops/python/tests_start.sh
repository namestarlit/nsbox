#!/usr/bin/env bash

# Purpose: run test prestart logic and then execute the reference test command.
# Problem Solved: preserve the startup sequence required before running tests in the original app.

set -euo pipefail

PRESTART_SCRIPT="app/tests_pre_start.py"
DRY_RUN=false

usage() {
    cat <<EOF
Usage:
  $0 [--prestart-script PATH] [--dry-run] [test-args...]

Description:
  Runs the test prestart script and then delegates to the sibling test.sh reference.

Options:
  --prestart-script PATH   Path to the pre-test startup script
                          (default: app/tests_pre_start.py)
  --dry-run                Print the planned commands without running them
  -h, --help               Show this help message
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prestart-script)
            [[ $# -ge 2 ]] || { echo "Error: --prestart-script requires a value." >&2; exit 1; }
            PRESTART_SCRIPT="$2"
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
        --)
            shift
            break
            ;;
        -*)
            break
            ;;
        *)
            break
            ;;
    esac
done

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would run 'python $PRESTART_SCRIPT'."
    echo "Dry run: would run '$SCRIPT_DIR/test.sh $*'."
    exit 0
fi

command -v python >/dev/null 2>&1 || { echo "Error: required command 'python' was not found." >&2; exit 1; }
[[ -f "$PRESTART_SCRIPT" ]] || { echo "Error: prestart script '$PRESTART_SCRIPT' not found." >&2; exit 1; }
[[ -x "$SCRIPT_DIR/test.sh" || -f "$SCRIPT_DIR/test.sh" ]] || { echo "Error: sibling test.sh not found." >&2; exit 1; }

python "$PRESTART_SCRIPT"
bash "$SCRIPT_DIR/test.sh" "$@"
