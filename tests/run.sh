#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

pass() {
    printf 'PASS %s\n' "$1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    printf 'FAIL %s\n' "$1" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local label="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$label"
    else
        printf 'Expected to find: %s\nOutput was:\n%s\n' "$needle" "$haystack" >&2
        fail "$label"
    fi
}

assert_success() {
    local status="$1"
    local label="$2"
    if [[ "$status" -eq 0 ]]; then
        pass "$label"
    else
        fail "$label"
    fi
}

run_capture() {
    local __resultvar="$1"
    shift
    local output
    set +e
    output="$("$@" 2>&1)"
    local status=$?
    set -e
    printf -v "$__resultvar" '%s' "$output"
    return "$status"
}

test_bash_syntax() {
    set +e
    find "$ROOT_DIR/utils" "$ROOT_DIR/guides" "$ROOT_DIR/refs" -type f -name '*.sh' -print0 | xargs -0 bash -n >/tmp/nsbox-test-syntax.out 2>&1
    local status=$?
    set -e
    assert_success "$status" "shell syntax validation"
}

test_serverbackup_dry_run() {
    local tmpdir output status
    tmpdir="$(mktemp -d /tmp/nsbox-test-backup.XXXXXX)"
    mkdir -p "$tmpdir/source/subdir"
    touch "$tmpdir/source/file1" "$tmpdir/source/subdir/file2"
    set +e
    output="$(bash "$ROOT_DIR/refs/backups/serverbackup.sh" --source "$tmpdir/source" --backup-dir "$tmpdir/backups" --keep 2 --name-prefix sample --exclude '*.tmp' --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "serverbackup dry-run exits successfully"
    assert_contains "$output" "Dry run: would create backup archive:" "serverbackup dry-run reports archive plan"
    assert_contains "$output" "sample_" "serverbackup dry-run includes generated name prefix"
}

test_append_sshd_config_dry_run() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/server-bootstrap/append_sshd_config.sh" "$ROOT_DIR/guides/server-bootstrap/assets/sshd_config" --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "append_sshd_config dry-run exits successfully"
    assert_contains "$output" "Preview of managed block:" "append_sshd_config dry-run shows preview"
    assert_contains "$output" "PermitRootLogin no" "append_sshd_config dry-run contains managed content"
}

test_setup_deploy_user_dry_run() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/deploy-host/setup_deploy_user.sh" --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "setup_deploy_user dry-run exits successfully"
    assert_contains "$output" "would write sudoers drop-in" "setup_deploy_user dry-run reports sudoers action"
}

test_setup_deploy_user_resolves_home_from_passwd() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/deploy-host/setup_deploy_user.sh" --user root --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "setup_deploy_user dry-run for existing custom-home user exits successfully"
    assert_contains "$output" "/root/.ssh" "setup_deploy_user dry-run resolves home directory from passwd"
}

test_setup_deploy_user_missing_user_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/deploy-host/setup_deploy_user.sh" --user 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "setup_deploy_user missing user value exits non-zero"
    else
        fail "setup_deploy_user missing user value exits non-zero"
    fi
    assert_contains "$output" "--user requires a value" "setup_deploy_user missing user value reports error"
}

test_setup_deploy_user_missing_docker_command_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/deploy-host/setup_deploy_user.sh" --docker-command 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "setup_deploy_user missing docker-command value exits non-zero"
    else
        fail "setup_deploy_user missing docker-command value exits non-zero"
    fi
    assert_contains "$output" "--docker-command requires a value" "setup_deploy_user missing docker-command value reports error"
}

test_setup_deploy_user_missing_sudo_command_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/deploy-host/setup_deploy_user.sh" --sudo-command 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "setup_deploy_user missing sudo-command value exits non-zero"
    else
        fail "setup_deploy_user missing sudo-command value exits non-zero"
    fi
    assert_contains "$output" "--sudo-command requires a value" "setup_deploy_user missing sudo-command value reports error"
}

test_setup_ssh_key_dry_run() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/server-bootstrap/setup_ssh_key.sh" 203.0.113.10 root 22 admin_key --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "setup_ssh_key dry-run exits successfully"
    assert_contains "$output" "would retrieve and show host key fingerprints" "setup_ssh_key dry-run reports host key flow"
}

test_setup_ssh_key_missing_args() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/server-bootstrap/setup_ssh_key.sh" 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "setup_ssh_key missing args exits non-zero"
    else
        fail "setup_ssh_key missing args exits non-zero"
    fi
    assert_contains "$output" "Usage:" "setup_ssh_key missing args shows usage"
}

test_create_sudo_user_missing_shell_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/server-bootstrap/create_sudo_user.sh" alice --shell 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "create_sudo_user missing shell value exits non-zero"
    else
        fail "create_sudo_user missing shell value exits non-zero"
    fi
    assert_contains "$output" "--shell requires a value" "create_sudo_user missing shell value reports error"
}

test_renew_cert_dry_run() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/tls/renew_cert.sh" example.com --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "renew_cert dry-run exits successfully"
    assert_contains "$output" "would run: certbot certonly --nginx --cert-name 'example.com' --key-type rsa --dry-run" "renew_cert dry-run reports certbot command"
}

test_renew_cert_log_fallback_is_present() {
    local output
    output="$(sed -n '1,120p' "$ROOT_DIR/refs/tls/renew_cert.sh")"
    assert_contains "$output" 'LOGFILE=""' "renew_cert clears logfile on write failure"
    assert_contains "$output" 'elif ! touch "$LOGFILE"' "renew_cert falls back when logfile is not writable"
}

test_app_ops_start_dry_run() {
    local output status tmpdir
    tmpdir="$(mktemp -d /tmp/nsbox-test-appops.XXXXXX)"
    set +e
    output="$(cd "$tmpdir" && bash "$ROOT_DIR/refs/app-ops/docker-compose/start.sh" --db demo-db --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "app-ops start dry-run exits successfully"
    assert_contains "$output" "would run 'sudo docker compose up -d --build'" "app-ops start dry-run reports compose up"
    assert_contains "$output" "from '$tmpdir'" "app-ops start dry-run uses caller project directory"
}

test_app_ops_stop_dry_run() {
    local output status tmpdir
    tmpdir="$(mktemp -d /tmp/nsbox-test-appops-stop.XXXXXX)"
    mkdir -p "$tmpdir/data/middleware"
    cat > "$tmpdir/.env" <<'EOF'
DATA_DIRECTORY=/tmp/nsbox-test-appops-stop-data
EOF
    set +e
    output="$(cd "$tmpdir" && bash "$ROOT_DIR/refs/app-ops/docker-compose/stop.sh" --clean --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "app-ops stop dry-run exits successfully"
    assert_contains "$output" "would run 'sudo docker compose down --rmi all --volumes --remove-orphans'" "app-ops stop dry-run reports compose down"
    assert_contains "$output" "from '$tmpdir'" "app-ops stop dry-run uses caller project directory"
}

test_app_ops_start_missing_db_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/docker-compose/start.sh" --db 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "app-ops start missing db value exits non-zero"
    else
        fail "app-ops start missing db value exits non-zero"
    fi
    assert_contains "$output" "--db requires a value" "app-ops start missing db value reports error"
}

test_app_ops_stop_missing_db_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/docker-compose/stop.sh" --db 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "app-ops stop missing db value exits non-zero"
    else
        fail "app-ops stop missing db value exits non-zero"
    fi
    assert_contains "$output" "--db requires a value" "app-ops stop missing db value reports error"
}

test_app_ops_dump_db_missing_file_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/docker-compose/dump_db.sh" demo-db --file 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "app-ops dump_db missing file value exits non-zero"
    else
        fail "app-ops dump_db missing file value exits non-zero"
    fi
    assert_contains "$output" "--file requires a value" "app-ops dump_db missing file value reports error"
}

test_app_ops_import_db_missing_file_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/docker-compose/import_db.sh" demo-db --file 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "app-ops import_db missing file value exits non-zero"
    else
        fail "app-ops import_db missing file value exits non-zero"
    fi
    assert_contains "$output" "--file requires a value" "app-ops import_db missing file value reports error"
}

test_nginx_site_dry_run_does_not_rename() {
    local tmpdir output status
    tmpdir="$(mktemp -d /tmp/nsbox-test-nginx-site.XXXXXX)"
    touch "$tmpdir/example.conf.disabled"
    set +e
    output="$(bash "$ROOT_DIR/guides/nginx-site-management/site.sh" --conf-dir "$tmpdir" --dry-run enable example 2>&1)"
    status=$?
    set -e
    if [[ -f "$tmpdir/example.conf.disabled" && ! -f "$tmpdir/example.conf" ]]; then
        pass "nginx site dry-run leaves files unchanged"
    else
        fail "nginx site dry-run leaves files unchanged"
    fi
    rm -rf "$tmpdir"
    assert_success "$status" "nginx site dry-run exits successfully"
    assert_contains "$output" "would rename" "nginx site dry-run reports rename plan"
}

test_nginx_site_missing_conf_dir_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/nginx-site-management/site.sh" --conf-dir 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "nginx site missing conf-dir value exits non-zero"
    else
        fail "nginx site missing conf-dir value exits non-zero"
    fi
    assert_contains "$output" "--conf-dir requires a value" "nginx site missing conf-dir value reports error"
}

test_app_ops_dump_db_positional_dry_run() {
    local output status tmpdir
    tmpdir="$(mktemp -d /tmp/nsbox-test-appops-dump.XXXXXX)"
    set +e
    output="$(cd "$tmpdir" && bash "$ROOT_DIR/refs/app-ops/docker-compose/dump_db.sh" demo-db --file export.sql --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "app-ops dump_db positional dry-run exits successfully"
    assert_contains "$output" "container 'demo-db'" "app-ops dump_db positional dry-run reports container"
}

test_app_ops_import_db_positional_dry_run() {
    local output status tmpdir
    tmpdir="$(mktemp -d /tmp/nsbox-test-appops-import.XXXXXX)"
    touch "$tmpdir/import.sql"
    set +e
    output="$(cd "$tmpdir" && bash "$ROOT_DIR/refs/app-ops/docker-compose/import_db.sh" demo-db --file import.sql --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "app-ops import_db positional dry-run exits successfully"
    assert_contains "$output" "container 'demo-db'" "app-ops import_db positional dry-run reports container"
}

test_app_ops_import_db_dry_run_without_sql_file() {
    local output status tmpdir
    tmpdir="$(mktemp -d /tmp/nsbox-test-appops-import-missing.XXXXXX)"
    set +e
    output="$(cd "$tmpdir" && bash "$ROOT_DIR/refs/app-ops/docker-compose/import_db.sh" demo-db --file missing.sql --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "app-ops import_db dry-run without SQL file exits successfully"
    assert_contains "$output" "does not currently exist" "app-ops import_db dry-run notes missing SQL file"
}

test_app_ops_makemigrations_uses_python_manage_py() {
    local output
    output="$(sed -n '1,120p' "$ROOT_DIR/refs/app-ops/docker-compose/makemigrations.sh")"
    assert_contains "$output" "uv run python manage.py makemigrations" "app-ops makemigrations runs manage.py through python"
}

test_app_ops_dump_db_nested_output_dry_run() {
    local output status tmpdir
    tmpdir="$(mktemp -d /tmp/nsbox-test-appops-dump-nested.XXXXXX)"
    set +e
    output="$(cd "$tmpdir" && bash "$ROOT_DIR/refs/app-ops/docker-compose/dump_db.sh" demo-db --file nested/export.sql --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "app-ops dump_db nested output dry-run exits successfully"
    assert_contains "$output" "nested/export.sql" "app-ops dump_db dry-run reports nested output path"
}

test_superset_parser_uses_python_csv() {
    local output
    output="$(sed -n '1,280p' "$ROOT_DIR/refs/app-ops/superset/reset_superset_password.sh")"
    assert_contains "$output" "import csv" "superset reset uses Python CSV parser"
}

test_app_ops_superset_rejects_zero_password_bytes() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/superset/reset_superset_password.sh" superset-app --password-bytes 0 --dry-run 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "app-ops superset zero password bytes exits non-zero"
    else
        fail "app-ops superset zero password bytes exits non-zero"
    fi
    assert_contains "$output" "--password-bytes must be greater than zero" "app-ops superset zero password bytes reports error"
}

test_setup_ssh_key_reconciles_known_hosts() {
    local output
    output="$(sed -n '1,240p' "$ROOT_DIR/guides/server-bootstrap/setup_ssh_key.sh")"
    assert_contains "$output" "ssh-keygen -R" "setup_ssh_key removes old known_hosts entries before appending"
}

test_setup_deploy_user_detects_ssh_unit() {
    local output
    output="$(sed -n '1,240p' "$ROOT_DIR/guides/deploy-host/setup_deploy_user.sh")"
    assert_contains "$output" "grep -qx 'ssh.service'" "setup_deploy_user matches ssh.service explicitly"
    assert_contains "$output" "grep -qx 'sshd.service'" "setup_deploy_user matches sshd.service explicitly"
    assert_contains "$output" 'sshd -t -f "$SSH_CONFIG"' "setup_deploy_user validates the target SSH config file explicitly"
}

test_setup_deploy_key_missing_user_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/deploy-host/setup_deploy_key.sh" "ssh-ed25519 AAAATEST user@example" --user 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "setup_deploy_key missing user value exits non-zero"
    else
        fail "setup_deploy_key missing user value exits non-zero"
    fi
    assert_contains "$output" "--user requires a value" "setup_deploy_key missing user value reports error"
}

test_setup_deploy_key_resolves_home_from_passwd() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/deploy-host/setup_deploy_key.sh" "ssh-ed25519 AAAATEST user@example" --user root --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "setup_deploy_key dry-run for existing custom-home user exits successfully"
    assert_contains "$output" "/root/.ssh" "setup_deploy_key dry-run resolves home directory from passwd"
}

test_setup_deploy_key_normalizes_ssh_dir_permissions() {
    local output
    output="$(sed -n '90,110p' "$ROOT_DIR/guides/deploy-host/setup_deploy_key.sh")"
    assert_contains "$output" 'chmod 700 "$SSH_DIR"' "setup_deploy_key normalizes existing ssh directory permissions"
}

test_serverbackup_missing_source_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/backups/serverbackup.sh" --source 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "serverbackup missing source value exits non-zero"
    else
        fail "serverbackup missing source value exits non-zero"
    fi
    assert_contains "$output" "--source requires a value" "serverbackup missing source value reports error"
}

test_serverbackup_keep_zero_skips_pruning() {
    local output
    output="$(sed -n '160,185p' "$ROOT_DIR/refs/backups/serverbackup.sh")"
    assert_contains "$output" 'if [[ "$BACKUP_HISTORY" -gt 0 ]]; then' "serverbackup skips pruning when keep is zero"
}

test_serverbackup_excludes_only_archive_when_backup_dir_equals_source() {
    local output
    output="$(sed -n '124,140p' "$ROOT_DIR/refs/backups/serverbackup.sh")"
    assert_contains "$output" 'elif [[ "$BACKUP_DIR" == "$SOURCE_PATH" ]]; then' "serverbackup handles backup dir equal to source separately"
    assert_contains "$output" '--exclude="$(basename "$BACKUP_FILE")"' "serverbackup excludes only generated archive when backup dir equals source"
}

test_ssh_keygen_missing_type_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/server-bootstrap/ssh_keygen.sh" keyname comment --type 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "ssh_keygen missing type value exits non-zero"
    else
        fail "ssh_keygen missing type value exits non-zero"
    fi
    assert_contains "$output" "--type requires a value" "ssh_keygen missing type value reports error"
}

test_append_sshd_config_missing_block_name_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/server-bootstrap/append_sshd_config.sh" "$ROOT_DIR/guides/server-bootstrap/assets/sshd_config" --block-name 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "append_sshd_config missing block-name value exits non-zero"
    else
        fail "append_sshd_config missing block-name value exits non-zero"
    fi
    assert_contains "$output" "--block-name requires a value" "append_sshd_config missing block-name value reports error"
}

test_setup_logs_help_works() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/docker-compose/setup_logs.sh" --help 2>&1)"
    status=$?
    set -e
    assert_success "$status" "app-ops setup_logs help exits successfully"
    assert_contains "$output" "Reads DATA_DIRECTORY from .env" "app-ops setup_logs help shows description"
}

test_setup_logs_bad_arg_shows_usage() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/docker-compose/setup_logs.sh" --bad-arg 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "app-ops setup_logs bad arg exits non-zero"
    else
        fail "app-ops setup_logs bad arg exits non-zero"
    fi
    assert_contains "$output" "Unknown argument: --bad-arg" "app-ops setup_logs bad arg reports error"
    assert_contains "$output" "Usage:" "app-ops setup_logs bad arg shows usage"
}

test_setup_logs_strips_quoted_env_value() {
    local output status tmpdir
    tmpdir="$(mktemp -d /tmp/nsbox-setup-logs.XXXXXX)"
    cat > "$tmpdir/.env" <<'EOF'
DATA_DIRECTORY="/srv/app data"
EOF
    set +e
    output="$(cd "$tmpdir" && bash "$ROOT_DIR/refs/app-ops/docker-compose/setup_logs.sh" --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "app-ops setup_logs quoted env dry-run exits successfully"
    assert_contains "$output" "/srv/app data" "app-ops setup_logs dry-run reports unquoted env path"
}

test_setup_swarm_node_missing_network_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/deploy-host/setup_swarm_node.sh" --network 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "setup_swarm_node missing network value exits non-zero"
    else
        fail "setup_swarm_node missing network value exits non-zero"
    fi
    assert_contains "$output" "--network requires a value" "setup_swarm_node missing network value reports error"
}

test_setup_swarm_node_dry_run_without_docker_installed() {
    local output status
    set +e
    output="$(PATH=/tmp/empty /bin/bash "$ROOT_DIR/guides/deploy-host/setup_swarm_node.sh" --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "setup_swarm_node dry-run without docker exits successfully"
    assert_contains "$output" "would initialize Docker Swarm if inactive" "setup_swarm_node dry-run works without docker installed"
}

test_setup_swarm_node_uses_exact_name_matching() {
    local output
    output="$(sed -n '78,96p' "$ROOT_DIR/guides/deploy-host/setup_swarm_node.sh")"
    assert_contains "$output" "docker network ls --format '{{.Name}}' | grep -Fxq" "setup_swarm_node matches existing networks by exact name"
    assert_contains "$output" "docker volume ls --format '{{.Name}}' | grep -Fxq" "setup_swarm_node matches existing volumes by exact name"
}

test_setup_ssh_key_dry_run_reports_ed25519_default() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/server-bootstrap/setup_ssh_key.sh" 203.0.113.10 root 22 admin_key --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "setup_ssh_key dry-run default key type exits successfully"
    assert_contains "$output" "new ed25519 key" "setup_ssh_key dry-run reports ed25519 default"
}

test_setup_ssh_key_dry_run_accepts_rsa() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/guides/server-bootstrap/setup_ssh_key.sh" 203.0.113.10 root 22 admin_key --key-type rsa --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "setup_ssh_key dry-run rsa exits successfully"
    assert_contains "$output" "new rsa key" "setup_ssh_key dry-run reports rsa key type"
}

test_system_info_tries_plain_inxi_first() {
    local output
    output="$(sed -n '1,120p' "$ROOT_DIR/utils/system/system_info.sh")"
    assert_contains "$output" "if inxi -Fz;" "system_info tries non-sudo inxi first"
    assert_contains "$output" "Retrying with sudo" "system_info documents sudo fallback"
}

test_system_specs_missing_output_value() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/utils/system/system_specs.sh" --output 2>&1)"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        pass "system_specs missing output value exits non-zero"
    else
        fail "system_specs missing output value exits non-zero"
    fi
    assert_contains "$output" "--output requires a value" "system_specs missing output value reports error"
}

test_system_specs_guards_unset_lvm_map_entries() {
    local output
    output="$(sed -n '138,152p' "$ROOT_DIR/utils/system/system_specs.sh")"
    assert_contains "$output" '${lvm_volumes[$name]:-}' "system_specs guards unset LVM map entries"
}

test_append_sshd_config_validates_target_file() {
    local output
    output="$(sed -n '1,160p' "$ROOT_DIR/guides/server-bootstrap/append_sshd_config.sh")"
    assert_contains "$output" 'sshd -t -f "$SSHD_CONFIG"' "append_sshd_config validates the target config file explicitly"
}

test_app_ops_stop_strips_quoted_data_directory() {
    local output status tmpdir
    tmpdir="$(mktemp -d /tmp/nsbox-stop-env.XXXXXX)"
    cat > "$tmpdir/.env" <<'EOF'
DATA_DIRECTORY="/srv/app data"
EOF
    set +e
    output="$(cd "$tmpdir" && bash "$ROOT_DIR/refs/app-ops/docker-compose/stop.sh" --clean --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "app-ops stop quoted env dry-run exits successfully"
    assert_contains "$output" "/srv/app data/middleware" "app-ops stop dry-run reports unquoted data directory"
}

test_app_ops_python_format_dry_run() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/python/format.sh" --app-dir service --scripts-dir ops --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "app-ops python format dry-run exits successfully"
    assert_contains "$output" "ruff check --fix service ops" "app-ops python format dry-run reports Ruff fix"
}

test_app_ops_python_lint_dry_run() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/python/lint.sh" --app-dir service --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "app-ops python lint dry-run exits successfully"
    assert_contains "$output" "mypy service" "app-ops python lint dry-run reports mypy"
}

test_app_ops_python_prestart_dry_run() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/python/prestart.sh" --prestart-module custom.pre --migrations-module custom.migrations --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "app-ops python prestart dry-run exits successfully"
    assert_contains "$output" "uv run python -m custom.pre" "app-ops python prestart dry-run reports prestart module"
}

test_app_ops_python_test_dry_run() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/python/test.sh" report-title --app-dir service --dry-run 2>&1)"
    status=$?
    set -e
    assert_success "$status" "app-ops python test dry-run exits successfully"
    assert_contains "$output" "coverage html --title report-title" "app-ops python test dry-run reports coverage title"
}

test_app_ops_python_tests_start_dry_run() {
    local output status
    set +e
    output="$(bash "$ROOT_DIR/refs/app-ops/python/tests_start.sh" --prestart-script service/tests_pre_start.py --dry-run -- -k smoke 2>&1)"
    status=$?
    set -e
    assert_success "$status" "app-ops python tests_start dry-run exits successfully"
    assert_contains "$output" "python service/tests_pre_start.py" "app-ops python tests_start dry-run reports prestart script"
    assert_contains "$output" "test.sh -k smoke" "app-ops python tests_start dry-run delegates to sibling test.sh"
}

test_app_ops_superset_reset_dry_run() {
    local tmpdir output status
    tmpdir="$(mktemp -d /tmp/nsbox-test-superset.XXXXXX)"
    cat > "$tmpdir/users.csv" <<'EOF'
username,email,role
alice,alice@example.com,Gamma
bob,bob@example.com,Admin
EOF
    set +e
    output="$(cd "$tmpdir" && bash "$ROOT_DIR/refs/app-ops/superset/reset_superset_password.sh" superset-app --csv users.csv --filter-role Gamma --dry-run 2>&1)"
    status=$?
    set -e
    rm -rf "$tmpdir"
    assert_success "$status" "app-ops superset reset dry-run exits successfully"
    assert_contains "$output" "Users to process: 1" "app-ops superset reset dry-run filters users"
    assert_contains "$output" "Dry run -> would run:" "app-ops superset reset dry-run reports reset command"
}

test_app_ops_readme_documents_env_parser_limit() {
    local output
    output="$(sed -n '1,120p' "$ROOT_DIR/refs/app-ops/README.md")"
    assert_contains "$output" 'only supports `KEY=value` lines' "app-ops README documents .env parser limitation"
}

test_local_vm_vagrantfile_syncs_repo_root() {
    local output
    output="$(sed -n '1,120p' "$ROOT_DIR/guides/local-vm/Vagrantfile")"
    assert_contains "$output" 'config.vm.synced_folder "../../", "/home/vagrant/nsbox"' "local-vm Vagrantfile syncs the repository root"
}

main() {
    test_bash_syntax
    test_serverbackup_dry_run
    test_append_sshd_config_dry_run
    test_append_sshd_config_validates_target_file
    test_create_sudo_user_missing_shell_value
    test_setup_deploy_user_dry_run
    test_setup_deploy_user_resolves_home_from_passwd
    test_setup_deploy_user_missing_user_value
    test_setup_deploy_user_missing_docker_command_value
    test_setup_deploy_user_missing_sudo_command_value
    test_setup_swarm_node_missing_network_value
    test_setup_swarm_node_dry_run_without_docker_installed
    test_setup_swarm_node_uses_exact_name_matching
    test_setup_ssh_key_dry_run
    test_setup_ssh_key_dry_run_reports_ed25519_default
    test_setup_ssh_key_dry_run_accepts_rsa
    test_setup_ssh_key_missing_args
    test_nginx_site_dry_run_does_not_rename
    test_nginx_site_missing_conf_dir_value
    test_serverbackup_missing_source_value
    test_serverbackup_keep_zero_skips_pruning
    test_serverbackup_excludes_only_archive_when_backup_dir_equals_source
    test_system_info_tries_plain_inxi_first
    test_system_specs_missing_output_value
    test_system_specs_guards_unset_lvm_map_entries
    test_renew_cert_dry_run
    test_renew_cert_log_fallback_is_present
    test_app_ops_start_dry_run
    test_app_ops_stop_dry_run
    test_app_ops_start_missing_db_value
    test_app_ops_stop_missing_db_value
    test_app_ops_dump_db_missing_file_value
    test_app_ops_import_db_missing_file_value
    test_app_ops_dump_db_positional_dry_run
    test_app_ops_dump_db_nested_output_dry_run
    test_app_ops_import_db_positional_dry_run
    test_app_ops_import_db_dry_run_without_sql_file
    test_app_ops_makemigrations_uses_python_manage_py
    test_app_ops_python_format_dry_run
    test_app_ops_python_lint_dry_run
    test_app_ops_python_prestart_dry_run
    test_app_ops_python_test_dry_run
    test_app_ops_python_tests_start_dry_run
    test_app_ops_superset_reset_dry_run
    test_app_ops_superset_rejects_zero_password_bytes
    test_superset_parser_uses_python_csv
    test_setup_ssh_key_reconciles_known_hosts
    test_setup_deploy_user_detects_ssh_unit
    test_setup_deploy_key_missing_user_value
    test_setup_deploy_key_resolves_home_from_passwd
    test_setup_deploy_key_normalizes_ssh_dir_permissions
    test_ssh_keygen_missing_type_value
    test_append_sshd_config_missing_block_name_value
    test_setup_logs_help_works
    test_setup_logs_bad_arg_shows_usage
    test_setup_logs_strips_quoted_env_value
    test_app_ops_stop_strips_quoted_data_directory
    test_app_ops_readme_documents_env_parser_limit
    test_local_vm_vagrantfile_syncs_repo_root

    printf '\nSummary: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
    if [[ "$FAIL_COUNT" -ne 0 ]]; then
        exit 1
    fi
}

main "$@"
