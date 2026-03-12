#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  sudo $0 [--conf-dir DIR] [--dry-run] list
  sudo $0 [--conf-dir DIR] [--suffix .disabled] [--dry-run] enable SITE_NAME
  sudo $0 [--conf-dir DIR] [--suffix .disabled] [--dry-run] disable SITE_NAME

SITE_NAME maps to:
  DIR/SITE_NAME.conf
  DIR/SITE_NAME.conf<suffix>
EOF
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Please run this script as root or with sudo." >&2
        exit 1
    fi
}

CONF_FILE_PATH="/etc/nginx/conf.d"
DISABLED_SUFFIX=".disabled"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --conf-dir)
            [[ $# -ge 2 ]] || {
                echo "Error: --conf-dir requires a value." >&2
                usage
                exit 1
            }
            CONF_FILE_PATH="$2"
            shift 2
            ;;
        --suffix)
            [[ $# -ge 2 ]] || {
                echo "Error: --suffix requires a value." >&2
                usage
                exit 1
            }
            DISABLED_SUFFIX="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [[ "$DRY_RUN" != true ]]; then
    require_root
fi

[[ -d "$CONF_FILE_PATH" ]] || {
    echo "Error: $CONF_FILE_PATH does not exist." >&2
    exit 1
}

COMMAND="${1:-}"
SITE_NAME="${2:-}"

case "$COMMAND" in
    list)
        if [[ $# -ne 1 ]]; then
            usage
            exit 1
        fi
        echo "Available site configuration files in $CONF_FILE_PATH:"
        ls -1 "$CONF_FILE_PATH"
        exit 0
        ;;
    enable|disable)
        if [[ $# -ne 2 ]]; then
            usage
            exit 1
        fi
        ;;
    -h|--help|"")
        usage
        exit 0
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        usage
        exit 1
        ;;
esac

ENABLED_PATH="$CONF_FILE_PATH/$SITE_NAME.conf"
DISABLED_PATH="$CONF_FILE_PATH/$SITE_NAME.conf${DISABLED_SUFFIX}"
SOURCE_PATH=""
TARGET_PATH=""

case "$COMMAND" in
    enable)
        SOURCE_PATH="$DISABLED_PATH"
        TARGET_PATH="$ENABLED_PATH"
        ;;
    disable)
        SOURCE_PATH="$ENABLED_PATH"
        TARGET_PATH="$DISABLED_PATH"
        ;;
esac

[[ -f "$SOURCE_PATH" ]] || {
    echo "Error: expected site config not found: $SOURCE_PATH" >&2
    exit 1
}

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would ${COMMAND} site '$SITE_NAME' in '$CONF_FILE_PATH'."
    echo "Dry run: would rename '$SOURCE_PATH' to '$TARGET_PATH'."
    echo "Dry run: would test nginx configuration and reload nginx if valid."
    exit 0
fi

mv "$SOURCE_PATH" "$TARGET_PATH"

if nginx -t; then
    systemctl reload nginx
    echo "Nginx site '$SITE_NAME' ${COMMAND}d successfully."
else
    echo "Nginx configuration test failed. Rolling back..." >&2
    mv "$TARGET_PATH" "$SOURCE_PATH"
    exit 1
fi
