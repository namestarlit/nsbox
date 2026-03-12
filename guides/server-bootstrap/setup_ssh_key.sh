#!/usr/bin/env bash

set -euo pipefail

# Help message
usage() {
    echo "Usage: $0 <SERVER_IP> <SSH_USER> [SSH_PORT] [KEY_NAME] [--key-type ed25519|rsa] [--install-sshpass] [--trust-host-key] [--dry-run]"
    echo "  SERVER_IP         - The IP address or hostname of the server."
    echo "  SSH_USER          - The user to log in as."
    echo "  SSH_PORT          - (Optional) SSH port, defaults to 22."
    echo "  KEY_NAME          - (Optional) Name for the SSH key, defaults to 'server_key'."
    echo "  --key-type        - SSH key type for generated keys, defaults to 'ed25519'."
    echo "  --install-sshpass - Install sshpass if missing."
    echo "  --trust-host-key  - Skip interactive fingerprint confirmation."
    echo "  --dry-run         - Show the planned actions without touching SSH keys or the remote host."
    echo ""
    echo "  Example:"
    echo "  $0 example.com johndoe 2222 ssh_key --install-sshpass"
}

# Ensure at least SERVER_IP and SSH_USER are provided
if [[ $# -lt 2 ]]; then
    usage
    exit 1
fi

SERVER_HOST="$1"
SSH_USER="$2"
shift 2

SSH_PORT="22"
KEY_NAME="server_key"
if [[ $# -gt 0 && "$1" != --* ]]; then
    SSH_PORT="$1"
    shift
fi
if [[ $# -gt 0 && "$1" != --* ]]; then
    KEY_NAME="$1"
    shift
fi

INSTALL_SSHPASS=false
TRUST_HOST_KEY=false
DRY_RUN=false
KEY_TYPE="ed25519"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --key-type)
            [[ $# -ge 2 ]] || { echo "Error: --key-type requires a value." >&2; usage; exit 1; }
            KEY_TYPE="$2"
            shift 2
            ;;
        --install-sshpass)
            INSTALL_SSHPASS=true
            shift
            ;;
        --trust-host-key)
            TRUST_HOST_KEY=true
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

# Define key paths
SSH_DIR="$HOME/.ssh"
PRIVATE_KEY="$SSH_DIR/$KEY_NAME"
PUBLIC_KEY="$PRIVATE_KEY.pub"

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would ensure local SSH directory exists at '$SSH_DIR'."
    if [[ -f "$PRIVATE_KEY" ]]; then
        echo "Dry run: existing private key would be reused: $PRIVATE_KEY"
    else
        echo "Dry run: would generate a new $KEY_TYPE key at '$PRIVATE_KEY'."
    fi
    if [[ "$INSTALL_SSHPASS" == true ]]; then
        echo "Dry run: would install sshpass if missing."
    else
        echo "Dry run: would require sshpass to already be installed."
    fi
    echo "Dry run: would retrieve and show host key fingerprints for '$SERVER_HOST:$SSH_PORT'."
    if [[ "$TRUST_HOST_KEY" == true ]]; then
        echo "Dry run: host key would be trusted automatically."
    else
        echo "Dry run: host key confirmation would be requested before writing known_hosts."
    fi
    echo "Dry run: would copy '$PUBLIC_KEY' to '$SSH_USER@$SERVER_HOST' using ssh-copy-id."
    echo "Dry run: would test SSH login with '$PRIVATE_KEY'."
    exit 0
fi

# Get the password from environment variable or prompt user if not set
if [[ -z "${SERVER_PASSWORD:-}" ]]; then
    # If SERVER_PASSWORD is not set, ask for it securely
    read -rsp "Enter the password for $SSH_USER@$SERVER_HOST: " SERVER_PASSWORD
    echo
fi

# Ensure SSH directory exists
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Generate SSH key if it doesn't exist
if [[ ! -f "$PRIVATE_KEY" ]]; then
    echo "Generating SSH key: $PRIVATE_KEY"
    case "$KEY_TYPE" in
        ed25519)
            ssh-keygen -t ed25519 -f "$PRIVATE_KEY" -N ""
            ;;
        rsa)
            ssh-keygen -t rsa -b 4096 -m PEM -f "$PRIVATE_KEY" -N ""
            ;;
        *)
            echo "Error: unsupported key type '$KEY_TYPE'. Use ed25519 or rsa." >&2
            exit 1
            ;;
    esac
else
    echo "SSH key already exists: $PRIVATE_KEY"
fi

# Install sshpass if not available
if ! command -v sshpass >/dev/null 2>&1; then
    if [[ "$INSTALL_SSHPASS" == true ]]; then
        echo "Installing sshpass..."
        sudo apt-get install -y sshpass
    else
        echo "Error: sshpass is required. Re-run with --install-sshpass or install it manually." >&2
        exit 1
    fi
fi

# Add server to known_hosts to avoid manual prompt
echo "Adding $SERVER_HOST to known_hosts..."
touch "$SSH_DIR/known_hosts"
chmod 600 "$SSH_DIR/known_hosts"
HOST_KEY_SCAN="$(ssh-keyscan -p "$SSH_PORT" "$SERVER_HOST" 2>/dev/null || true)"
if [[ -z "$HOST_KEY_SCAN" ]]; then
    echo "Error: unable to retrieve host key from $SERVER_HOST:$SSH_PORT" >&2
    exit 1
fi

HOST_FINGERPRINTS="$(printf '%s\n' "$HOST_KEY_SCAN" | ssh-keygen -lf - 2>/dev/null || true)"
echo "Retrieved host key fingerprint(s):"
printf '%s\n' "$HOST_FINGERPRINTS"

if [[ "$TRUST_HOST_KEY" != true ]]; then
    read -r -p "Trust and add this host key to known_hosts? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Aborted by user."
        exit 1
    fi
fi

ssh-keygen -R "[$SERVER_HOST]:$SSH_PORT" -f "$SSH_DIR/known_hosts" >/dev/null 2>&1 || true
ssh-keygen -R "$SERVER_HOST" -f "$SSH_DIR/known_hosts" >/dev/null 2>&1 || true
printf '%s\n' "$HOST_KEY_SCAN" >> "$SSH_DIR/known_hosts"

# Copy the SSH key to the server using sshpass and the password from stdin
echo "Copying SSH key to $SERVER_HOST..."
SSHPASS="$SERVER_PASSWORD" sshpass -e ssh-copy-id -i "$PUBLIC_KEY" -p "$SSH_PORT" "$SSH_USER@$SERVER_HOST"

# Test SSH connection
echo "Testing SSH connection..."
ssh -i "$PRIVATE_KEY" -p "$SSH_PORT" "$SSH_USER@$SERVER_HOST" "echo 'SSH setup successful on \$(hostname)'"

echo "✅ SSH setup complete. You can now connect using:"
echo "  ssh -i $PRIVATE_KEY -p $SSH_PORT $SSH_USER@$SERVER_HOST"
