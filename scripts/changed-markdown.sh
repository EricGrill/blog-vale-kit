#!/usr/bin/env bash
# Print Markdown and MDX paths to lint, one per line.
# VALE_FILE_INPUT: explicit newline-separated list (wins).
# VALE_BASE_REF or GITHUB_BASE_REF: git diff against that ref.
# Otherwise: tracked *.md and *.mdx files.
set -euo pipefail

is_markdown() {
  case "$1" in
    *.md | *.mdx | *.MD | *.MDX) return 0 ;;
    *) return 1 ;;
  esac
}

emit_existing() {
  local f
  while IFS= read -r f || [ -n "${f:-}" ]; do
    [ -z "${f:-}" ] && continue
    case "$f" in
      .blog-vale-kit/*) continue ;;
    esac
    if [ -f "$f" ] && is_markdown "$f"; then
      printf '%s\n' "$f"
    fi
  done
}

if [ -n "${VALE_FILE_INPUT:-}" ]; then
  printf '%s\n' "$VALE_FILE_INPUT" | emit_existing
  exit 0
fi

base="${VALE_BASE_REF:-${GITHUB_BASE_REF:-}}"
if [ -n "$base" ]; then
  if git rev-parse --verify --quiet "origin/${base}" >/dev/null; then
    git diff --name-only --diff-filter=ACMR "origin/${base}...HEAD" | emit_existing
  elif git rev-parse --verify --quiet "$base" >/dev/null; then
    git diff --name-only --diff-filter=ACMR "${base}...HEAD" | emit_existing
  else
    echo "Base ref '${base}' was not found. Fetch it before listing files." >&2
    exit 1
  fi
  exit 0
fi

git ls-files '*.md' '*.mdx' '*.MD' '*.MDX' | emit_existing
