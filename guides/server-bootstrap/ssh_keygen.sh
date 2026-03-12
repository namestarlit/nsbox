#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 KEY_NAME COMMENT [--type ed25519|rsa] [--bits N]"
    echo "Example: $0 my_key you@example.com --type ed25519"
}

if [[ $# -lt 2 ]]; then
    usage
    exit 1
fi

KEY_NAME="$1"
COMMENT="$2"
KEY_TYPE="ed25519"
KEY_BITS=""
shift 2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)
            [[ $# -ge 2 ]] || {
                echo "Error: --type requires a value." >&2
                usage
                exit 1
            }
            KEY_TYPE="$2"
            shift 2
            ;;
        --bits)
            [[ $# -ge 2 ]] || {
                echo "Error: --bits requires a value." >&2
                usage
                exit 1
            }
            KEY_BITS="$2"
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

SSH_KEYGEN_ARGS=(-t "$KEY_TYPE" -f "$KEY_NAME" -C "$COMMENT" -N "")
if [[ "$KEY_TYPE" == "rsa" ]]; then
    SSH_KEYGEN_ARGS+=(-m PEM)
    if [[ -n "$KEY_BITS" ]]; then
        SSH_KEYGEN_ARGS+=(-b "$KEY_BITS")
    else
        SSH_KEYGEN_ARGS+=(-b 4096)
    fi
fi

ssh-keygen "${SSH_KEYGEN_ARGS[@]}"

echo "SSH key generated successfully:"
echo "  Private key: $KEY_NAME"
echo "  Public key:  ${KEY_NAME}.pub"
echo
echo "To authorize this key on a server, append the public key contents to the target user's ~/.ssh/authorized_keys."
