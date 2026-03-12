# Backup References

This directory contains backup-related scripts for databases and filesystem trees.

Use this directory when:

- you need a remembered backup flow to adapt for a server or project
- you want an example of how to archive a directory tree
- you want to preview a backup plan before building a production version

Scripts in this directory:

- `serverbackup.sh`: archive a server filesystem while excluding selected system paths

Typical usage:

```bash
# Create a filesystem backup archive of a specific directory tree
sudo bash refs/backups/serverbackup.sh --source /srv/app --backup-dir /var/backups/app --keep 7 --name-prefix app

# Preview the backup plan without creating an archive
sudo bash refs/backups/serverbackup.sh --source /srv/app --backup-dir /var/backups/app --keep 7 --name-prefix app --dry-run
```

Notes:

- `serverbackup.sh` is for filesystem archives.
  Use it when you want a compressed backup of a specific directory tree with retention and excludes.

- verify restore procedures separately; a backup script alone does not prove recoverability
- review storage, retention, and credential handling before use in production

Last Reviewed: 2026-03-11
