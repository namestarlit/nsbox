#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 CONFIG_FILE [--block-name NAME] [--dry-run]"
}

BLOCK_NAME="server-bootstrap"
DRY_RUN=false

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

CONFIG_FILE="$1"
shift
SSHD_CONFIG="/etc/ssh/sshd_config"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --block-name)
            [[ $# -ge 2 ]] || {
                echo "Error: --block-name requires a value." >&2
                usage
                exit 1
            }
            BLOCK_NAME="$2"
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

if [[ "$DRY_RUN" != true && "$(id -u)" -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

[[ -f "$CONFIG_FILE" ]] || {
    echo "Error: configuration file '$CONFIG_FILE' not found." >&2
    exit 1
}
if [[ "$DRY_RUN" != true && ! -f "$SSHD_CONFIG" ]]; then
    echo "Error: SSH config '$SSHD_CONFIG' not found." >&2
    exit 1
fi

BACKUP_PATH="${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
TMP_FILE="$(mktemp)"
BLOCK_START="# BEGIN managed ssh block ${BLOCK_NAME}"
BLOCK_END="# END managed ssh block ${BLOCK_NAME}"

if [[ -f "$SSHD_CONFIG" ]]; then
    awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
        $0 == start {skip=1; next}
        $0 == end {skip=0; next}
        !skip {print}
    ' "$SSHD_CONFIG" > "$TMP_FILE"
else
    : > "$TMP_FILE"
fi

{
    printf '\n%s\n' "$BLOCK_START"
    cat "$CONFIG_FILE"
    printf '\n%s\n' "$BLOCK_END"
} >> "$TMP_FILE"

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would manage SSH config block '$BLOCK_NAME' in '$SSHD_CONFIG' using '$CONFIG_FILE'."
    echo "Preview of managed block:"
    sed -n "/^${BLOCK_START//\//\\/}$/,/^${BLOCK_END//\//\\/}$/p" "$TMP_FILE" || true
    rm -f "$TMP_FILE"
    exit 0
fi

cp "$SSHD_CONFIG" "$BACKUP_PATH"
cp "$TMP_FILE" "$SSHD_CONFIG"
rm -f "$TMP_FILE"

if ! sshd -t -f "$SSHD_CONFIG"; then
    echo "Error: resulting SSH configuration is invalid. Restoring backup." >&2
    cp "$BACKUP_PATH" "$SSHD_CONFIG"
    exit 1
fi

echo "Managed SSH config block '$BLOCK_NAME' from '$CONFIG_FILE' in '$SSHD_CONFIG'."
echo "Backup saved at $BACKUP_PATH"
