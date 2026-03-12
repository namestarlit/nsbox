#!/usr/bin/env bash

# Purpose: issue a wildcard certificate through manual DNS validation.
# Problem Solved: obtain a wildcard certificate when DNS-based manual challenge handling is acceptable.

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  sudo $0 ROOT_DOMAIN EMAIL

Description:
  Stops nginx, runs certbot with a manual DNS challenge for ROOT_DOMAIN and *.ROOT_DOMAIN,
  then writes a combined PEM file under /etc/ssl/ROOT_DOMAIN/.
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
esac

# Check if running as root user
if [[ $EUID -ne 0 ]]; then
    echo 'Please run this script as root or sudo'
    exit 1
fi

# Check if Certbot is not installed
if ! command -v certbot &> /dev/null; then
    # Install Certbot
    echo "Installing Certbot..."
    apt-get update
    apt-get install -y certbot
else
    echo "Certbot is already installed."
fi

# Check command-line arguments
if [ $# -ne 2 ]; then
    usage
    exit 1
fi

ROOT_DOMAIN="$1"
EMAIL="$2"
NGINX_WAS_ACTIVE=false

if systemctl is-active --quiet nginx; then
    NGINX_WAS_ACTIVE=true
fi

cleanup() {
    if [[ "$NGINX_WAS_ACTIVE" == true ]]; then
        service nginx start >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

# shutdown nginx
if [[ "$NGINX_WAS_ACTIVE" == true ]]; then
    service nginx stop
fi

# Generate the certificate
echo "Generating SSL certificate for $ROOT_DOMAIN..."
certbot certonly --manual --preferred-challenges dns -d "$ROOT_DOMAIN" -d "*.$ROOT_DOMAIN" --email "$EMAIL"

echo "Creating PEM file..."
CERT_PATH="/etc/letsencrypt/live/$ROOT_DOMAIN"
PEM_PATH="/etc/ssl/$ROOT_DOMAIN/$ROOT_DOMAIN.pem"

if [ -f "$CERT_PATH/fullchain.pem" ] && [ -f "$CERT_PATH/privkey.pem" ]; then
    mkdir -p "/etc/ssl/$ROOT_DOMAIN"
    cat "$CERT_PATH/fullchain.pem" "$CERT_PATH/privkey.pem" > "$PEM_PATH"
    chmod 600 "$PEM_PATH"
    echo "SSL certificate created and configured for $ROOT_DOMAIN."
else
    echo "Error: Fullchain or privkey not found. Certificate might not have been generated successfully." >&2
    exit 1
fi

if [[ "$NGINX_WAS_ACTIVE" == true ]]; then
    service nginx start
fi
trap - EXIT
