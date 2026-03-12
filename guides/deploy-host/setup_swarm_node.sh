#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 [--network NAME] [--volume NAME] [--advertise-addr IP] [--dry-run]"
}

# Variables
NETWORK_NAME="zanlis-network"
VOLUME_NAME="letsencrypt"
ADVERTISE_ADDR=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --network)
            [[ $# -ge 2 ]] || { echo "Error: --network requires a value." >&2; usage; exit 1; }
            NETWORK_NAME="$2"
            shift 2
            ;;
        --volume)
            [[ $# -ge 2 ]] || { echo "Error: --volume requires a value." >&2; usage; exit 1; }
            VOLUME_NAME="$2"
            shift 2
            ;;
        --advertise-addr)
            [[ $# -ge 2 ]] || { echo "Error: --advertise-addr requires a value." >&2; usage; exit 1; }
            ADVERTISE_ADDR="$2"
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

echo "Setting up Docker Swarm node."

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would initialize Docker Swarm if inactive."
    if [[ -n "$ADVERTISE_ADDR" ]]; then
        echo "Dry run: would use advertise address '$ADVERTISE_ADDR'."
    fi
    echo "Dry run: would ensure overlay network '$NETWORK_NAME' exists."
    echo "Dry run: would ensure volume '$VOLUME_NAME' exists."
    exit 0
fi

command -v docker >/dev/null 2>&1 || {
    echo "Error: docker is required." >&2
    exit 1
}

# Step 1: Initialize Docker Swarm (if it's not already a Swarm node)
if ! sudo docker info | grep -q 'Swarm: active'; then
    echo "Initializing Docker Swarm..."
    if [[ -n "$ADVERTISE_ADDR" ]]; then
        sudo docker swarm init --advertise-addr "$ADVERTISE_ADDR"
    else
        sudo docker swarm init
    fi
    echo "Worker join token:"
    sudo docker swarm join-token -q worker
    echo "Manager join token:"
    sudo docker swarm join-token -q manager
else
    echo "Docker Swarm is already initialized."
fi

# Step 2: Create the overlay network (attachable)
if ! sudo docker network ls --format '{{.Name}}' | grep -Fxq "$NETWORK_NAME"; then
    sudo docker network create --driver=overlay --attachable "$NETWORK_NAME"
    echo "Docker overlay network '$NETWORK_NAME' created and attachable."
else
    echo "Docker overlay network '$NETWORK_NAME' already exists."
fi

# Step 3: Create the external volume
if ! sudo docker volume ls --format '{{.Name}}' | grep -Fxq "$VOLUME_NAME"; then
    sudo docker volume create "$VOLUME_NAME"
    echo "Docker volume '$VOLUME_NAME' created."
else
    echo "Docker volume '$VOLUME_NAME' already exists."
fi

echo "Swarm node setup, network and volume creation complete."
