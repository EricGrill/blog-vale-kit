#!/usr/bin/env bash
# Print the git ref of the running blog-vale-kit workflow.
# job.workflow_sha is the called workflow's commit. github.workflow_ref is the
# caller, so a pull_request run must not check the kit out at that ref.
set -euo pipefail

if [ -n "${JOB_WORKFLOW_SHA:-}" ]; then
  printf '%s\n' "$JOB_WORKFLOW_SHA"
  exit 0
fi

raw="${JOB_WORKFLOW_REF:-${GITHUB_WORKFLOW_REF:-}}"
ref="${raw##*@}"
if [ -n "$ref" ] && [ "$ref" != "$raw" ]; then
  printf '%s\n' "$ref"
  exit 0
fi

echo "Could not resolve the blog-vale-kit ref from JOB_WORKFLOW_REF='${JOB_WORKFLOW_REF:-}' GITHUB_WORKFLOW_REF='${GITHUB_WORKFLOW_REF:-}'." >&2
exit 1
