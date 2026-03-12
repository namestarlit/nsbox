#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 PUBLIC_KEY [--user deploy] [--dry-run]"
}

resolve_user_home() {
    local username="$1"
    getent passwd "$username" | cut -d: -f6
}

# Variables
DEPLOY_USER="deploy"
DEPLOY_KEY="${1:-}"
DRY_RUN=false

[[ -n "$DEPLOY_KEY" ]] || {
    echo "Error: You must provide the deploy public SSH key as an argument." >&2
    usage
    exit 1
}
shift || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            [[ $# -ge 2 ]] || {
                echo "Error: --user requires a value." >&2
                usage
                exit 1
            }
            DEPLOY_USER="$2"
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

if [[ $EUID -ne 0 ]]; then
    if [[ "$DRY_RUN" != true ]]; then
        echo "Please run this script as root or with sudo." >&2
        exit 1
    fi
fi

echo "Setting up deploy key for user $DEPLOY_USER."

DEPLOY_HOME=""
if getent passwd "$DEPLOY_USER" >/dev/null 2>&1; then
    DEPLOY_HOME="$(resolve_user_home "$DEPLOY_USER")"
fi

if [[ -z "$DEPLOY_HOME" ]]; then
    DEPLOY_HOME="/home/$DEPLOY_USER"
fi

SSH_DIR="$DEPLOY_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would ensure user '$DEPLOY_USER' exists."
    echo "Dry run: would ensure SSH directory '$SSH_DIR' exists with correct permissions."
    echo "Dry run: would add the provided public key to '$AUTHORIZED_KEYS' if missing."
    exit 0
fi

id "$DEPLOY_USER" >/dev/null 2>&1 || {
    echo "Error: user '$DEPLOY_USER' does not exist." >&2
    exit 1
}

DEPLOY_HOME="$(resolve_user_home "$DEPLOY_USER")"
[[ -n "$DEPLOY_HOME" ]] || {
    echo "Error: could not determine home directory for user '$DEPLOY_USER'." >&2
    exit 1
}
SSH_DIR="$DEPLOY_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# 1. Ensure the deploy user's SSH directory exists
if [[ ! -d "$SSH_DIR" ]]; then
    echo "Creating SSH directory for $DEPLOY_USER."
    mkdir -p "$SSH_DIR"
fi
chmod 700 "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$SSH_DIR"

# 2. Ensure the key is not already in authorized_keys
if ! grep -qF "$DEPLOY_KEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
    echo "Adding deploy key to authorized_keys."
    printf '%s\n' "$DEPLOY_KEY" >> "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
    chown "$DEPLOY_USER:$DEPLOY_USER" "$AUTHORIZED_KEYS"
else
    echo "Deploy key is already present in authorized_keys. Skipping addition."
fi

echo "Deploy key setup complete for user $DEPLOY_USER."

echo "Setup complete. You can now use the deploy key to log in as $DEPLOY_USER."
