#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 <domain> [--dry-run]

Description:
  Renew an existing certificate for the given domain using certbot's nginx plugin.

Dry-run behavior:
  - With --dry-run, certbot uses its dry-run mode.
  - If the local certificate path does not exist, the script prints the planned renewal command
    and exits successfully instead of failing.
EOF
}

DOMAIN=""
DRY_RUN=false
LOGFILE="/var/log/renew_cert.log"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$DOMAIN" ]]; then
                DOMAIN="$1"
                shift
            else
                echo "Unknown argument: $1" >&2
                usage
                exit 1
            fi
            ;;
    esac
done

CERT_PATH="/etc/letsencrypt/live/${DOMAIN}/cert.pem"

if [[ -z "$DOMAIN" ]]; then
    usage
    exit 1
fi

log() {
    printf '%s\n' "$1"
    if [[ -n "${LOGFILE:-}" ]]; then
        if ! printf '%s\n' "$1" >>"$LOGFILE" 2>/dev/null; then
            LOGFILE=""
        fi
    fi
}

if [[ "$DRY_RUN" == true ]]; then
    if ! touch "$LOGFILE" >/dev/null 2>&1; then
        LOGFILE="/dev/null"
    fi
elif ! touch "$LOGFILE" >/dev/null 2>&1; then
    LOGFILE=""
fi

if [[ "$DRY_RUN" != true ]]; then
    command -v certbot >/dev/null 2>&1 || {
        echo "❌ certbot is required." >&2
        exit 1
    }
    command -v openssl >/dev/null 2>&1 || {
        echo "❌ openssl is required." >&2
        exit 1
    }
fi

log "===== Renewing cert for ${DOMAIN} ====="

# Check if cert exists
if [[ ! -f "$CERT_PATH" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        log "ℹ️ Dry run: certificate path '$CERT_PATH' does not exist locally."
        log "ℹ️ Dry run: would run: certbot certonly --nginx --cert-name '$DOMAIN' --key-type rsa --dry-run"
        exit 0
    fi
    echo "❌ Certificate not found at $CERT_PATH"
    exit 2
fi

command -v certbot >/dev/null 2>&1 || {
    echo "❌ certbot is required." >&2
    exit 1
}
command -v openssl >/dev/null 2>&1 || {
    echo "❌ openssl is required." >&2
    exit 1
}

# Show current expiry
log "📆 Current cert expiry:"
openssl x509 -enddate -noout -in "$CERT_PATH" | tee -a "${LOGFILE:-/dev/null}"

# Check if nginx config is valid before renewal
log "🧪 Validating nginx configuration..."
sudo nginx -t >>"${LOGFILE:-/dev/null}" 2>&1

CERTBOT_ARGS=(certonly --nginx --cert-name "$DOMAIN" --key-type rsa)
if [[ "$DRY_RUN" == true ]]; then
    CERTBOT_ARGS+=(--dry-run)
fi

log "🔐 Running certbot..."
if sudo certbot "${CERTBOT_ARGS[@]}" >>"${LOGFILE:-/dev/null}" 2>&1; then
    log "✅ Renewal succeeded."
    
    log "📆 New cert expiry:"
    openssl x509 -enddate -noout -in "$CERT_PATH" | tee -a "${LOGFILE:-/dev/null}"

    if [[ "$DRY_RUN" == false ]]; then
        log "🔄 Reloading nginx..."
        sudo nginx -t >>"${LOGFILE:-/dev/null}" 2>&1
        sudo systemctl reload nginx
    else
        log "ℹ️ Dry run mode enabled. Skipping nginx reload."
    fi

    log "✅ All done."
else
    echo "❌ Certbot renewal failed. Check $LOGFILE for details."
    exit 4
fi
