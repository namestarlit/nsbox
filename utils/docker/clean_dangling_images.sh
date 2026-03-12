#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 [--dry-run]"
}

DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
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
    shift
done

command -v docker >/dev/null 2>&1 || {
    echo "Error: docker is required." >&2
    exit 1
}

docker info >/dev/null 2>&1 || {
    echo "Error: cannot access the Docker daemon." >&2
    exit 1
}

mapfile -t DANGLING_IMAGES < <(docker images --filter "dangling=true" --quiet | awk '!seen[$0]++')

if [[ ${#DANGLING_IMAGES[@]} -eq 0 ]]; then
    echo "No dangling Docker images found."
    exit 0
fi

echo "Dangling Docker images:"
printf '%s\n' "${DANGLING_IMAGES[@]}"

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run complete. No images were removed."
    exit 0
fi

docker rmi "${DANGLING_IMAGES[@]}"
echo "Removed ${#DANGLING_IMAGES[@]} dangling image(s)."
