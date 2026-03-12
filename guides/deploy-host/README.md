# Deploy Host

Purpose: prepare a server to run application deployments with a dedicated deploy user and optional Docker Swarm resources.

Problem solved: repeatable setup of a host used for deployments so the same user, permissions, and swarm prerequisites do not need to be rebuilt manually each time.

Use this guide for:

- a deploy account used by CI, CD, Git hooks, or scripted release workflows
- a user that should have specific operational privileges rather than full general admin behavior
- preparing Docker or Swarm-related host resources for application delivery

Do not use this guide for:

- your main human admin account
- the first general-purpose login you expect to use for server administration

For that case, use `guides/server-bootstrap/` instead.

Scripts in this guide:

- `update_server.sh`: update package metadata and run a distribution upgrade
- `setup_deploy_user.sh`: create the `deploy` user, add Docker access, and apply SSH/sudo setup
- `setup_deploy_key.sh`: append a deploy public key to the deploy user's `authorized_keys`
- `setup_swarm_node.sh`: initialize Docker Swarm and create the shared network and volume

Recommended flow:

1. Update the server.
2. Create the deploy user.
3. Install the deploy public key.
4. If this host participates in Swarm, create the swarm resources.

Account model:

- `setup_deploy_user.sh` creates a deploy-style account, not a normal admin account.
- It manages a user-specific SSH block and a constrained sudoers drop-in.
- This is the right choice when the account exists to move code, run Docker, and execute a known set of operational commands.
- If you want a normal admin login in the `sudo` group, use `guides/server-bootstrap/create_sudo_user.sh` instead.

Typical commands:

```bash
sudo bash guides/deploy-host/update_server.sh
sudo bash guides/deploy-host/setup_deploy_user.sh
sudo bash guides/deploy-host/setup_deploy_key.sh "$(cat ~/.ssh/deploy_key.pub)"
sudo bash guides/deploy-host/setup_swarm_node.sh --network zanlis-network --volume letsencrypt --advertise-addr 192.0.2.10

# Preview deploy-user setup without touching users, sshd_config, or sudoers
sudo bash guides/deploy-host/setup_deploy_user.sh --dry-run

# Preview deploy key installation without touching authorized_keys
sudo bash guides/deploy-host/setup_deploy_key.sh "$(cat ~/.ssh/deploy_key.pub)" --dry-run

# Preview swarm setup without touching Docker state
sudo bash guides/deploy-host/setup_swarm_node.sh --network zanlis-network --volume letsencrypt --advertise-addr 192.0.2.10 --dry-run
```

Per-script usage:

- `update_server.sh`
  Usage: `sudo bash guides/deploy-host/update_server.sh`

- `setup_deploy_user.sh`
  Usage: `sudo bash guides/deploy-host/setup_deploy_user.sh [--user deploy] [--docker-command /usr/bin/docker] [--sudo-command CMD] [--dry-run]`
  Note: writes a validated sudoers drop-in under `/etc/sudoers.d/` and reconciles it on each run.

- `setup_deploy_key.sh`
  Usage: `sudo bash guides/deploy-host/setup_deploy_key.sh "PUBLIC_KEY_CONTENTS" [--user deploy] [--dry-run]`
  Example: `sudo bash guides/deploy-host/setup_deploy_key.sh "$(cat ~/.ssh/deploy_key.pub)"`

- `setup_swarm_node.sh`
  Usage: `sudo bash guides/deploy-host/setup_swarm_node.sh [--network NAME] [--volume NAME] [--advertise-addr IP] [--dry-run]`
  Note: defaults to `zanlis-network` and `letsencrypt`, and can print join tokens when it initializes Swarm.

Assumptions:

- Docker is already installed
- the host should have a dedicated `deploy` user
- passwordless sudo for selected commands is acceptable in this environment
- swarm resources use the baked-in names in the script

Side effects:

- creates and modifies system users
- writes a drop-in under `/etc/sudoers.d`
- manages a user-specific SSH block in `/etc/ssh/sshd_config`
- may restart SSH
- initializes Docker Swarm and creates network/volume resources

Risks:

- the sudo policy is still opinionated
- the swarm setup still defaults to project-specific names unless you override them
- SSH login behavior changes for the deploy user

Suggested verification:

```bash
id deploy
sudo -l -U deploy
ssh deploy@server.example.com
sudo docker info | grep Swarm
sudo docker network ls | grep zanlis-network
```

Last Reviewed: 2026-03-11
