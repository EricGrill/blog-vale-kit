#!/usr/bin/env bash
# Print the git ref of the running blog-vale-kit workflow.
# GitHub sets GITHUB_WORKFLOW_REF to owner/repo/.github/workflows/file.yml@ref.
set -euo pipefail

raw="${GITHUB_WORKFLOW_REF:-}"
ref="${raw##*@}"
if [ -n "$ref" ] && [ "$ref" != "$raw" ]; then
  printf '%s\n' "$ref"
  exit 0
fi

echo "Could not resolve the blog-vale-kit ref from GITHUB_WORKFLOW_REF='${raw}'." >&2
exit 1
