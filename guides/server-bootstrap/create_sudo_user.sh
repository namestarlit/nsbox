#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 <username> [--shell /bin/bash] [--lock-password] [--dry-run]"
}

[[ $# -ge 1 ]] || {
    usage
    exit 1
}

USERNAME="$1"
shift
USER_SHELL="/bin/bash"
LOCK_PASSWORD=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --shell)
            [[ $# -ge 2 ]] || { echo "Error: --shell requires a value." >&2; usage; exit 1; }
            USER_SHELL="$2"
            shift 2
            ;;
        --lock-password)
            LOCK_PASSWORD=true
            shift
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

if id "$USERNAME" >/dev/null 2>&1; then
    echo "User '$USERNAME' already exists." >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would create user '$USERNAME' with shell '$USER_SHELL'."
    echo "Dry run: would add '$USERNAME' to the sudo group."
    if [[ "$LOCK_PASSWORD" == true ]]; then
        echo "Dry run: would lock the password for '$USERNAME'."
    else
        echo "Dry run: would prompt to set a password for '$USERNAME'."
    fi
    exit 0
fi

useradd -m -s "$USER_SHELL" "$USERNAME"
usermod -aG sudo "$USERNAME"

if [[ "$LOCK_PASSWORD" == true ]]; then
    passwd -l "$USERNAME"
    echo "User '$USERNAME' created with sudo privileges and locked password."
else
    echo "Set a password for '$USERNAME':"
    passwd "$USERNAME"
    echo "User '$USERNAME' created with sudo privileges."
fi
