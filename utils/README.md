# Utils

This directory contains small standalone tools.

Use `utils/` when:

- you need one command for one job
- the script does not rely on a larger workflow for context
- `--help` is enough to explain how to run it

Current utilities:

- `docker/clean_dangling_images.sh`
  Remove dangling Docker images.
  Use it when disk space is being wasted by old image layers.

- `system/system_info.sh`
  Print a broad host summary with `inxi`.
  Use it when you want a quick machine overview for troubleshooting.

- `system/system_specs.sh`
  Generate a text report with CPU, memory, disk, and process information.
  Use it when you need a saved system summary for review or handoff.

If a script only makes sense as part of a larger operational flow, look under `guides/` or `refs/` instead.
