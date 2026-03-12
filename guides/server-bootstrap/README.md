# Server Bootstrap

Purpose: bootstrap access and baseline SSH hardening for a new server.

Problem solved: when a fresh server needs an admin user, SSH key access, and a small hardened SSH configuration without re-deriving the steps from memory.

Use this guide for:

- a human administrator account you expect to log in as directly
- first access setup on a new server
- baseline SSH hardening after key access is in place

Do not use this guide for:

- a deployment-only service account
- a user that should only have tightly scoped operational sudo access

For that case, use `guides/deploy-host/` instead.

Scripts in this guide:

- `ssh_keygen.sh`: generate a local SSH key pair
- `setup_ssh_key.sh`: copy a local SSH key to a remote server over password-based SSH
- `create_sudo_user.sh`: create a new sudo-capable user on the server
- `append_sshd_config.sh`: append config lines from a file into `/etc/ssh/sshd_config`
- `assets/sshd_config`: minimal SSH config fragment
- `server_config_notes.md`: general hardening checklist

Recommended flow:

1. Create or prepare the SSH key locally.
2. Create the new admin user on the server.
3. Install the SSH key for the user you will log in with.
4. Append the SSH hardening fragment.
5. Verify SSH access before closing the current session.

Account model:

- `create_sudo_user.sh` creates an admin-style user in the `sudo` group.
- This is the right choice for a person who will SSH into the host and administer it.
- If you want a narrower deploy account with a managed sudoers drop-in and user-specific SSH restrictions, use `guides/deploy-host/setup_deploy_user.sh` instead.

Typical commands:

```bash
# Option A: generate a key locally in the current directory
bash guides/server-bootstrap/ssh_keygen.sh my_server_key you@example.com

# Option B: generate and copy a key directly to a remote host
bash guides/server-bootstrap/setup_ssh_key.sh 203.0.113.10 root 22 admin_key

# Preview SSH bootstrap without touching local keys or the remote host
bash guides/server-bootstrap/setup_ssh_key.sh 203.0.113.10 root 22 admin_key --dry-run

# On the server, create a sudo user and set a password
sudo bash guides/server-bootstrap/create_sudo_user.sh adminuser

# Or create a sudo user intended for key-only access
sudo bash guides/server-bootstrap/create_sudo_user.sh adminuser --lock-password

# Preview user creation without modifying the system
sudo bash guides/server-bootstrap/create_sudo_user.sh adminuser --lock-password --dry-run

# On the server, append the included SSH settings
sudo bash guides/server-bootstrap/append_sshd_config.sh guides/server-bootstrap/assets/sshd_config

# Preview the SSH config change without applying it
sudo bash guides/server-bootstrap/append_sshd_config.sh guides/server-bootstrap/assets/sshd_config --dry-run
```

Per-script usage:

- `ssh_keygen.sh`
  Usage: `bash guides/server-bootstrap/ssh_keygen.sh KEY_NAME COMMENT`
  Example: `bash guides/server-bootstrap/ssh_keygen.sh my_server_key you@example.com`
  Note: this script only creates the key pair; it does not write to `authorized_keys`.

- `setup_ssh_key.sh`
  Usage: `bash guides/server-bootstrap/setup_ssh_key.sh SERVER_IP SSH_USER [SSH_PORT] [KEY_NAME] [--install-sshpass] [--trust-host-key] [--dry-run]`
  Example: `bash guides/server-bootstrap/setup_ssh_key.sh 203.0.113.10 root 22 admin_key --install-sshpass`
  Note: prompts for the remote password unless `SERVER_PASSWORD` is set and now asks for host-key confirmation unless `--trust-host-key` is used.

- `create_sudo_user.sh`
  Usage: `sudo bash guides/server-bootstrap/create_sudo_user.sh USERNAME [--shell /bin/bash] [--lock-password] [--dry-run]`
  Example: `sudo bash guides/server-bootstrap/create_sudo_user.sh adminuser`

- `append_sshd_config.sh`
  Usage: `sudo bash guides/server-bootstrap/append_sshd_config.sh CONFIG_FILE [--block-name NAME] [--dry-run]`
  Example: `sudo bash guides/server-bootstrap/append_sshd_config.sh guides/server-bootstrap/assets/sshd_config`
  Note: manages a named block in `sshd_config`, creates a timestamped backup, and validates the final SSH config before keeping the change.

Assumptions:

- target server uses OpenSSH and a conventional `/etc/ssh/sshd_config`
- you have password access or root access before switching to key-only login
- `sshpass` may be installed locally by `setup_ssh_key.sh`

Side effects:

- creates users
- modifies `/etc/ssh/sshd_config`
- installs SSH keys
- may change how you log in to the server

Risks:

- lockout risk if SSH config is changed before key access is verified
- `append_sshd_config.sh` now manages a named block, but it still edits the main SSH config file
- `setup_ssh_key.sh` uses password-based bootstrap and writes to `known_hosts`
- you should still verify the new login path before ending the current root session

Suggested verification:

```bash
ssh -i ~/.ssh/admin_key adminuser@203.0.113.10
sudo sshd -t -f /etc/ssh/sshd_config
```

Last Reviewed: 2026-03-11
