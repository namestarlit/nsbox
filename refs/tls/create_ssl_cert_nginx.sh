#!/usr/bin/env bash

# Purpose: issue a certificate for one domain using certbot's nginx plugin.
# Problem Solved: bootstrap a single-domain certificate when nginx is already serving the site.

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  sudo $0 DOMAIN EMAIL

Description:
  Ensures certbot and python3-certbot-nginx are installed, requests a certificate for DOMAIN,
  writes a combined PEM file under /etc/ssl/DOMAIN/, and restarts nginx.
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

# Check command-line arguments
if [ $# -ne 2 ]; then
    usage
    exit 1
fi

MISSING_PACKAGES=()
dpkg -s certbot >/dev/null 2>&1 || MISSING_PACKAGES+=(certbot)
dpkg -s python3-certbot-nginx >/dev/null 2>&1 || MISSING_PACKAGES+=(python3-certbot-nginx)
if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
    echo "Installing missing packages: ${MISSING_PACKAGES[*]}"
    apt-get update
    apt-get install -y "${MISSING_PACKAGES[@]}"
fi

DOMAIN="$1"
EMAIL="$2"

# Obtain the SSL certificate
echo "Obtaining SSL certificate for $DOMAIN..."
certbot certonly --nginx --agree-tos --no-eff-email --email "$EMAIL" -d "$DOMAIN"

echo "SSL certificate for $DOMAIN obtained successfully."
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
PEM_PATH="/etc/ssl/$DOMAIN/$DOMAIN.pem"

if [ -f "$CERT_PATH/fullchain.pem" ] && [ -f "$CERT_PATH/privkey.pem" ]; then
    mkdir -p "/etc/ssl/$DOMAIN"
    cat "$CERT_PATH/fullchain.pem" "$CERT_PATH/privkey.pem" > "$PEM_PATH"
    chmod 600 "$PEM_PATH"
    echo "SSL certificate created and configured for $DOMAIN."
else
    echo "Error: Fullchain or privkey not found. Certificate might not have been generated successfully." >&2
    exit 1
fi

nginx -t
systemctl reload nginx
