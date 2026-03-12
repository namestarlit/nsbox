#!/usr/bin/env bash

# Purpose: install the vagrant-scp plugin used by the local VM workflow.
# Problem Solved: enable simple host-to-VM file copying in Vagrant environments that use this plugin.

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $0

Description:
  Installs the vagrant-scp plugin.

After installation:
  vagrant scp <local_file_or_dir> :<vm_destination_path>
  Example: vagrant scp myfile.txt :/home/vagrant/myfile.txt
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
esac

vagrant plugin install vagrant-scp
echo "Plugin installed. Alternatively use: vagrant upload"
