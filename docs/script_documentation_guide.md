# Script Documentation Guide

Use this when adding or curating a script so the intent survives even if the commands change later.

Recommended fields:

- Script name
- Purpose
- Problem solved
- Preconditions or environment assumptions
- Usage
- Arguments and flags
- Example commands
- Side effects
- Risks or destructive behavior
- Related guides or companion scripts
- Last reviewed date

Suggested template:

```text
Script Name: my_script.sh
Purpose: Briefly describe what this script does.
Problem Solved: Explain the recurring task or issue this script addresses.
Prerequisites: Note required tools, permissions, services, or files.
Usage: ./my_script.sh [options]
Arguments:
  --flag    What it changes
Examples:
  ./my_script.sh --flag value
Side Effects:
  - Files changed
  - Services restarted
  - Data written or deleted
Risks:
  - Any destructive or security-sensitive behavior
Related:
  - Link to a guide or sibling script
Last Reviewed: YYYY-MM-DD
```
