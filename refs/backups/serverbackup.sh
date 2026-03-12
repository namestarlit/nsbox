#!/usr/bin/env bash

# Purpose: create a compressed filesystem backup under /opt/backup.
# Problem Solved: capture a simple whole-server archive with a small retention window.

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  sudo $0 [--source PATH] [--backup-dir DIR] [--keep COUNT] [--name-prefix NAME] [--exclude PATTERN ...] [--dry-run]

Description:
  Creates a tar.gz backup of a source path and prunes older archives.

Examples:
  sudo $0
  sudo $0 --source /srv/app --backup-dir /var/backups/app --keep 7 --name-prefix app
  sudo $0 --source /srv/app --exclude '*.log' --exclude 'tmp/*'
EOF
}

SOURCE_PATH="/"
BACKUP_DIR="/opt/backup"
BACKUP_HISTORY=2
NAME_PREFIX=""
EXCLUDES=()
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            [[ $# -ge 2 ]] || {
                echo "Error: --source requires a value." >&2
                usage
                exit 1
            }
            SOURCE_PATH="$2"
            shift 2
            ;;
        --backup-dir)
            [[ $# -ge 2 ]] || {
                echo "Error: --backup-dir requires a value." >&2
                usage
                exit 1
            }
            BACKUP_DIR="$2"
            shift 2
            ;;
        --keep)
            [[ $# -ge 2 ]] || {
                echo "Error: --keep requires a value." >&2
                usage
                exit 1
            }
            BACKUP_HISTORY="$2"
            shift 2
            ;;
        --name-prefix)
            [[ $# -ge 2 ]] || {
                echo "Error: --name-prefix requires a value." >&2
                usage
                exit 1
            }
            NAME_PREFIX="$2"
            shift 2
            ;;
        --exclude)
            [[ $# -ge 2 ]] || {
                echo "Error: --exclude requires a value." >&2
                usage
                exit 1
            }
            EXCLUDES+=("$2")
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

if [[ "$DRY_RUN" != true && $EUID -ne 0 ]]; then
    echo "Please run this script as root or using sudo." >&2
    exit 1
fi

if ! [[ "$BACKUP_HISTORY" =~ ^[0-9]+$ ]]; then
    echo "Error: --keep must be a non-negative integer." >&2
    exit 1
fi

SOURCE_PATH="$(readlink -f "$SOURCE_PATH")"
if [[ ! -e "$SOURCE_PATH" ]]; then
    echo "Error: source path '$SOURCE_PATH' does not exist." >&2
    exit 1
fi

if [[ -z "$NAME_PREFIX" ]]; then
    if [[ "$SOURCE_PATH" == "/" ]]; then
        NAME_PREFIX="rootfs"
    else
        NAME_PREFIX="$(basename "$SOURCE_PATH")"
    fi
fi

BACKUP_DATE="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_FILE="$BACKUP_DIR/${NAME_PREFIX}_${BACKUP_DATE}.tar.gz"

mkdir -p "$BACKUP_DIR"

TAR_ARGS=(--create --gzip --file "$BACKUP_FILE")

if [[ "$SOURCE_PATH" == "/" ]]; then
    TAR_ARGS+=(--directory=/)
    TAR_ARGS+=(--exclude=lost+found --exclude=dev/* --exclude=proc/* --exclude=run/*)
    TAR_ARGS+=(--exclude=sys/* --exclude=tmp/* --exclude=mnt/* --exclude=media/*)
    TAR_ARGS+=(--exclude="${BACKUP_DIR#/}/*" .)
else
    TAR_PARENT="$(dirname "$SOURCE_PATH")"
    TAR_ENTRY="$(basename "$SOURCE_PATH")"
    TAR_ARGS+=(--directory="$TAR_PARENT")
    if [[ "$BACKUP_DIR" == "$SOURCE_PATH/"* ]]; then
        TAR_ARGS+=(--exclude="${BACKUP_DIR#$TAR_PARENT/}/*")
    elif [[ "$BACKUP_DIR" == "$SOURCE_PATH" ]]; then
        TAR_ARGS+=(--exclude="$(basename "$BACKUP_FILE")")
    fi
    TAR_ARGS+=("$TAR_ENTRY")
fi

for pattern in "${EXCLUDES[@]}"; do
    TAR_ARGS+=(--exclude="$pattern")
done

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would create backup archive:"
    echo "  Source:      $SOURCE_PATH"
    echo "  Backup dir:  $BACKUP_DIR"
    echo "  Output file: $BACKUP_FILE"
    echo "  Keep count:  $BACKUP_HISTORY"
    if [[ ${#EXCLUDES[@]} -gt 0 ]]; then
        echo "  Excludes:"
        printf '    %s\n' "${EXCLUDES[@]}"
    fi
    echo "Dry run: tar arguments would be:"
    printf '  %q' tar "${TAR_ARGS[@]}"
    printf '\n'
    exit 0
fi

tar "${TAR_ARGS[@]}"

# Ensure the backup file is not empty before proceeding with upload
if [ ! -s "$BACKUP_FILE" ]; then
    echo "Backup file is empty. Exiting."
    exit 1
fi

echo "Backup created at $BACKUP_FILE"

if [[ "$BACKUP_HISTORY" -gt 0 ]]; then
    mapfile -t OLD_BACKUPS < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${NAME_PREFIX}_*.tar.gz" -printf '%T@ %p\n' | sort -nr | awk 'NR>'"$BACKUP_HISTORY"' {print $2}')
    if [ "${#OLD_BACKUPS[@]}" -gt 0 ]; then
        rm -f "${OLD_BACKUPS[@]}"
        echo "Removed ${#OLD_BACKUPS[@]} old backup(s)."
    fi
fi
