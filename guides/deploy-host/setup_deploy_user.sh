#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 [--user deploy] [--docker-command /usr/bin/docker] [--sudo-command CMD ...] [--dry-run]"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Please run this script as root or with sudo." >&2
        exit 1
    fi
}

resolve_user_home() {
    local username="$1"
    getent passwd "$username" | cut -d: -f6
}

restart_ssh_service() {
    local unit=""
    if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx 'ssh.service'; then
        unit="ssh.service"
    elif systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx 'sshd.service'; then
        unit="sshd.service"
    else
        echo "Error: could not determine SSH service unit (expected ssh.service or sshd.service)." >&2
        return 1
    fi

    systemctl restart "$unit"
    echo "SSH configuration updated and $unit restarted."
}

# Variables
DEPLOY_USER="deploy"
DOCKER_COMMAND="/usr/bin/docker"
EXTRA_SUDO_COMMANDS=()
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            [[ $# -ge 2 ]] || {
                echo "Error: --user requires a value." >&2
                usage
                exit 1
            }
            DEPLOY_USER="$2"
            shift 2
            ;;
        --docker-command)
            [[ $# -ge 2 ]] || {
                echo "Error: --docker-command requires a value." >&2
                usage
                exit 1
            }
            DOCKER_COMMAND="$2"
            shift 2
            ;;
        --sudo-command)
            [[ $# -ge 2 ]] || {
                echo "Error: --sudo-command requires a value." >&2
                usage
                exit 1
            }
            EXTRA_SUDO_COMMANDS+=("$2")
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

SUDOERS_DROPIN="/etc/sudoers.d/$DEPLOY_USER"
SSH_CONFIG="/etc/ssh/sshd_config"
SSH_BLOCK_START="# BEGIN managed deploy-host user ${DEPLOY_USER}"
SSH_BLOCK_END="# END managed deploy-host user ${DEPLOY_USER}"
DEFAULT_SUDO_COMMANDS=(/bin/mv /bin/mkdir /bin/chown /bin/chmod "$DOCKER_COMMAND")
SUDO_COMMANDS=("${DEFAULT_SUDO_COMMANDS[@]}" "${EXTRA_SUDO_COMMANDS[@]}")

echo "Creating a dedicated deployment user: $DEPLOY_USER"

DEPLOY_HOME=""
if getent passwd "$DEPLOY_USER" >/dev/null 2>&1; then
    DEPLOY_HOME="$(resolve_user_home "$DEPLOY_USER")"
fi
if [[ -z "$DEPLOY_HOME" ]]; then
    DEPLOY_HOME="/home/$DEPLOY_USER"
fi
SSH_DIR="$DEPLOY_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would ensure deploy user '$DEPLOY_USER' exists."
    echo "Dry run: would ensure '$DEPLOY_USER' is in the docker group."
    echo "Dry run: would ensure SSH directory '$SSH_DIR' and authorized_keys exist."
    echo "Dry run: would manage SSH block for '$DEPLOY_USER' in '$SSH_CONFIG'."
    echo "Dry run: would write sudoers drop-in '$SUDOERS_DROPIN' with commands:"
    printf '  %s\n' "${SUDO_COMMANDS[@]}"
    exit 0
fi

require_root

# 1. Create the deploy user if it doesn't exist
if id "$DEPLOY_USER" >/dev/null 2>&1; then
    echo "User $DEPLOY_USER already exists."
else
    adduser --disabled-password --gecos "" "$DEPLOY_USER"
    echo "User $DEPLOY_USER created."
fi

DEPLOY_HOME="$(resolve_user_home "$DEPLOY_USER")"
[[ -n "$DEPLOY_HOME" ]] || {
    echo "Error: could not determine home directory for user '$DEPLOY_USER'." >&2
    exit 1
}
SSH_DIR="$DEPLOY_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# 2. Add the deploy user to the docker group
usermod -aG docker "$DEPLOY_USER"
echo "User $DEPLOY_USER added to the docker group."

# 3. Set up SSH directory and authorized_keys
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$SSH_DIR"
echo "SSH directory and authorized_keys file set up for $DEPLOY_USER."

# 4. Restrict the deploy user to key-based authentication only
echo "Restricting $DEPLOY_USER to key-based SSH authentication."
SSH_TMP="$(mktemp)"
awk -v start="$SSH_BLOCK_START" -v end="$SSH_BLOCK_END" '
    $0 == start {skip=1; next}
    $0 == end {skip=0; next}
    !skip {print}
' "$SSH_CONFIG" > "$SSH_TMP"
{
    printf '\n%s\n' "$SSH_BLOCK_START"
    printf 'Match User %s\n' "$DEPLOY_USER"
    printf '    PasswordAuthentication no\n'
    printf '%s\n' "$SSH_BLOCK_END"
} >> "$SSH_TMP"
SSH_BACKUP="${SSH_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
cp "$SSH_CONFIG" "$SSH_BACKUP"
cp "$SSH_TMP" "$SSH_CONFIG"
rm -f "$SSH_TMP"
if ! sshd -t -f "$SSH_CONFIG"; then
    cp "$SSH_BACKUP" "$SSH_CONFIG"
    echo "Error: SSH configuration validation failed. Restored previous config." >&2
    exit 1
else
    restart_ssh_service
fi

# 5. Optionally, lock the deploy user's shell (uncomment if desired)
# echo "Locking $DEPLOY_USER's shell to prevent interactive login."
# sudo chsh -s /usr/sbin/nologin $DEPLOY_USER

# 6. Configure sudo access for deploy user **without** password prompt
echo "Granting $DEPLOY_USER passwordless sudo access."
SUDOERS_TMP="$(mktemp)"
{
    printf '%s ALL=(ALL) NOPASSWD: ' "$DEPLOY_USER"
    (IFS=', '; printf '%s' "${SUDO_COMMANDS[*]}")
    printf '\n'
} > "$SUDOERS_TMP"
chmod 440 "$SUDOERS_TMP"
visudo -cf "$SUDOERS_TMP" >/dev/null
install -m 440 "$SUDOERS_TMP" "$SUDOERS_DROPIN"
rm -f "$SUDOERS_TMP"
echo "Sudo privileges configured for $DEPLOY_USER."

# 7. Instructions for key setup
echo -e "\nTo complete the setup:"
echo "1. Add your public SSH key to $AUTHORIZED_KEYS:"
echo "   cat id_rsa.pub | ssh root@<server> 'cat >> $AUTHORIZED_KEYS'"
echo "2. Verify you can log in as $DEPLOY_USER without a password:"
echo "   ssh $DEPLOY_USER@<server>"
echo -e "\nSetup complete."
