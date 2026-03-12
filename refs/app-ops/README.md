# App Ops References

This directory contains application-operation scripts that came from real projects.

Use this directory when:

- you want an example of how a project handled start/stop, DB import/export, linting, or test setup
- you are moving an operational pattern into another repository
- you need a remembered app-specific flow such as batch resetting Superset passwords

Subdirectories:

- `docker-compose/`
  Start, stop, import/export, and support scripts for a Docker-based app stack.
  Use these when the target project has a running Compose-managed database or service stack and you want a concrete example flow.

- `python/`
  Formatting, linting, test, and prestart patterns for a Python app.
  Use these when the target project follows a similar `app/`-style layout or when you want a remembered command sequence to adapt.

- `superset/`
  Superset-specific account operation helper.
  Use this when you need to batch reset passwords for users inside a running Superset container.

How to use these safely:

- read the script before running it
- prefer `--dry-run` first when available
- expect path, environment, container, and naming changes before reuse
- for `python/`, pass explicit paths when the target repo does not use `app/` and `scripts/`
- for `superset/`, use `--dry-run` first to confirm the user list and output paths before touching accounts
- for `docker-compose/`, the lightweight `.env` parsing only supports `KEY=value` lines with optional surrounding single or double quotes; inline comments, escapes, and shell expansions are not interpreted safely

Do not treat this directory as plug-and-play generic tooling. Treat it as a set of concrete examples and reusable ideas.

Last Reviewed: 2026-03-11
