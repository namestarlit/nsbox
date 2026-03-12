# nsbox

Operations script library for common server, deployment, TLS, backup, and app-ops tasks.

Use this repository when you need one of these:

- a small standalone utility you can run directly
- a multi-step guide for a known server or deployment workflow
- a reference implementation from another project that you want to adapt, not trust blindly

Directory overview:

- `utils/`
  Small direct-use scripts.
  Use this when you want a single command for a narrow task such as system inspection or Docker cleanup.

- `guides/`
  Workflow-oriented scripts grouped by problem area.
  Use this when you are bootstrapping a server, preparing a deploy host, toggling Nginx sites, or bringing up a local VM and you want the related scripts and instructions together.
  The two user-management guides are intentionally different:
  `guides/server-bootstrap/` is for creating an admin user you will log in as directly.
  `guides/deploy-host/` is for creating a deploy user intended for deployment workflows, not general administration.

- `refs/`
  Reference implementations and remembered patterns.
  Use this when you want an example to copy from or adapt for another repo or host, especially for app-specific operations, TLS flows, or backup patterns.

- `docs/`
  Supporting documentation.
  Use this when you want the script documentation standard or other repo-level notes.

Current layout:

- `utils/docker/clean_dangling_images.sh`
- `utils/system/system_info.sh`
- `utils/system/system_specs.sh`
- `guides/server-bootstrap/`
- `guides/deploy-host/`
- `guides/local-vm/`
- `guides/nginx-site-management/`
- `refs/tls/`
- `refs/backups/`
- `refs/app-ops/`
- `docs/script_documentation_guide.md`

Start with the README inside the directory you plan to use. Those READMEs should tell you what the scripts do, when to use them, and how to run them.
