#!/usr/bin/env bash
# Prove the kit: good posts stay clean, bad posts warn, errors fail only on request.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

bash scripts/install-vale.sh .tools
export PATH="$root/.tools:$PATH"

version=$(tr -d '[:space:]' < VALE_VERSION)
case "$(vale --version)" in
  *" ${version}") ;;
  *) fail "vale --version is '$(vale --version)', expected ${version}" ;;
esac

python3 -m py_compile scripts/vale-lint.py
bash -n scripts/install-vale.sh
bash -n scripts/install-base-styles.sh
bash -n scripts/changed-markdown.sh
bash -n scripts/test-fixtures.sh

# Refreshing Base onto this repo must keep the rules in place.
bash scripts/install-base-styles.sh .
test -f styles/Base/AIPhrases.yml
test -f styles/Base/AIPhrases.test.yml
test -f styles/Example/Banned.yml

vale --no-global test --coverage styles
vale --no-global test fixtures

diff -u \
  <(grep -E '^(BlockIgnores|TokenIgnores) ' .vale.ini) \
  <(grep -E '^(BlockIgnores|TokenIgnores) ' fixtures/.vale.ini) \
  || fail "template and fixture ignore patterns differ"

python3 - <<'PY'
import json, subprocess, sys

def alerts(config, *paths):
    result = subprocess.run(
        ["vale", "--no-global", "--config", config, "--output=JSON", "--no-exit", *paths],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        sys.stderr.write(result.stdout)
        raise SystemExit(f"vale failed on {paths} ({result.returncode})")
    payload = json.loads(result.stdout.strip() or "{}")
    found = []
    for path, items in payload.items():
        for item in items or []:
            found.append((path, item.get("Check"), item.get("Severity"), item.get("Match")))
    return found

def require_clean(config, *paths):
    found = alerts(config, *paths)
    if found:
        for row in found:
            print(row, file=sys.stderr)
        raise SystemExit(f"expected no alerts for {paths} under {config}")

require_clean("fixtures/.vale.ini", "fixtures/good.md", "fixtures/good.mdx")
require_clean(".vale.ini", "fixtures/good.md", "fixtures/good.mdx", "README.md", "templates/STYLE.md")

required = {
    "Base.AIPhrases",
    "Base.Hedging",
    "Base.PassiveOverload",
    "Example.Banned",
    "Example.Preferred",
    "Example.Tone",
    "Vale.Example.Avoid",
}
for path in ("fixtures/bad.md", "fixtures/bad.mdx"):
    found = alerts("fixtures/.vale.ini", path)
    checks = {check for _, check, _, _ in found}
    missing = required - checks
    if missing:
        print(found, file=sys.stderr)
        raise SystemExit(f"{path} missing {sorted(missing)}")
    if not any(severity == "error" for _, _, severity, _ in found):
        raise SystemExit(f"{path} did not report an error")

base_only = alerts(".vale.ini", "fixtures/bad.md")
base_checks = {check for _, check, _, _ in base_only}
if "Base.AIPhrases" not in base_checks:
    raise SystemExit("template config did not run Base rules")
if any(check.startswith("Example.") or check == "Vale.Example.Avoid" for check in base_checks):
    raise SystemExit(f"template config enabled Example rules: {sorted(base_checks)}")
if any(severity == "error" for _, _, severity, _ in base_only):
    raise SystemExit("template config reported an error; Base rules must stay below error")
print("fixture alerts ok")
PY

for word in delve tapestry leverage perhaps cheap synergy website; do
  grep -q "$word" fixtures/good.mdx || fail "good.mdx no longer plants '$word'"
done
grep -q "Act now" fixtures/good.mdx || fail "good.mdx no longer plants 'Act now'"

lint_out() {
  # shellcheck disable=SC2068
  python3 scripts/vale-lint.py "$@" >"$tmp_out"
}

tmp_out=$(mktemp)
trap 'rm -f "$tmp_out"' EXIT

lint_out --config fixtures/.vale.ini fixtures/good.md fixtures/good.mdx
grep -q '::' "$tmp_out" && fail "good posts produced annotations: $(cat "$tmp_out")" || true

lint_out --config fixtures/.vale.ini fixtures/bad.md fixtures/bad.mdx
grep -q '::warning' "$tmp_out" || fail "bad posts did not warn"
grep -q '::error' "$tmp_out" && fail "warning-only mode posted an error annotation" || true

if python3 scripts/vale-lint.py --fail-on-error --config fixtures/.vale.ini fixtures/bad.md >"$tmp_out"; then
  fail "--fail-on-error exited 0 for fixtures/bad.md"
fi
grep -q '::error' "$tmp_out" || fail "--fail-on-error did not post an error annotation"

lint_out --fail-on-error --config .vale.ini fixtures/bad.md
grep -q '::error' "$tmp_out" && fail "suggestions failed the check under the template config" || true

lint_out --fail-on-error --config fixtures/.vale.ini fixtures/good.md
grep -q '::' "$tmp_out" && fail "good post failed with --fail-on-error" || true

printf '' >"$tmp_out.list"
lint_out --file-list "$tmp_out.list"
grep -q "No Markdown or MDX files to lint." "$tmp_out" || fail "empty list should skip Vale"

missing=$(mktemp -d)
if python3 scripts/vale-lint.py --config "$missing/.vale.ini" fixtures/bad.md >"$tmp_out"; then
  fail "missing config exited 0"
fi
rmdir "$missing"

adopt=$(mktemp -d)
cp .vale.ini "$adopt/.vale.ini"
cp fixtures/good.md "$adopt/post.md"
bash scripts/install-base-styles.sh "$adopt"
test -f "$adopt/styles/Base/AIPhrases.yml"
test ! -d "$adopt/styles/Example"
test -f "$adopt/styles/config/vocabularies/Base/accept.txt"
test ! -e "$adopt/styles/config/vocabularies/Example"
(
  cd "$adopt"
  python3 "$root/scripts/vale-lint.py" --config .vale.ini post.md >"$tmp_out"
)
grep -q '::' "$tmp_out" && fail "adopted good post produced alerts: $(cat "$tmp_out")" || true
rm -rf "$adopt"

uses_line='uses: EricGrill/blog-vale-kit/.github/workflows/vale.yml@main'
grep -q "$uses_line" examples/caller.yml || fail "caller workflow missing the uses line"
test "$(wc -l < examples/caller.yml | tr -d ' ')" -eq 10 || fail "caller workflow should be 10 lines"
grep -q 'workflow_call:' .github/workflows/vale.yml || fail "reusable workflow missing workflow_call"
grep -q 'fail_on_error:' .github/workflows/vale.yml || fail "reusable workflow missing fail_on_error"
grep -q 'fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09' .github/workflows/vale.yml || fail "checkout SHA is not pinned"
grep -q 'templates/STYLE.md' README.md || fail "README does not point at the STYLE.md template"

got=$(VALE_FILE_INPUT="$(printf 'fixtures/good.md\nstyles/Base/AIPhrases.yml\nmissing.md\n')" bash scripts/changed-markdown.sh)
test "$got" = "fixtures/good.md" || fail "changed-markdown filter returned: $got"

grep -q 'job.workflow_sha' .github/workflows/vale.yml || fail "kit checkout does not use the called workflow SHA"
grep -q 'job.workflow_repository' .github/workflows/vale.yml || fail "kit checkout does not use the called workflow repository"
if grep -q 'GITHUB_WORKFLOW_REF' .github/workflows/vale.yml; then
  fail "GITHUB_WORKFLOW_REF is the caller ref, not the kit ref"
fi

repo=$(mktemp -d)
git -C "$repo" init -b main
printf 'Wash the dog with warm water.\n' >"$repo/good.md"
printf 'notes\n' >"$repo/notes.txt"
git -C "$repo" add good.md notes.txt
git -C "$repo" -c user.email=vale-kit-test@example.com -c user.name=vale-kit-test -c commit.gpgsign=false commit -m "base"
git -C "$repo" checkout -b change
printf 'It is important to note this.\n' >"$repo/bad.md"
printf 'more notes\n' >>"$repo/notes.txt"
git -C "$repo" add bad.md notes.txt
git -C "$repo" -c user.email=vale-kit-test@example.com -c user.name=vale-kit-test -c commit.gpgsign=false commit -m "change"
changed=$(cd "$repo" && VALE_BASE_REF=main bash "$root/scripts/changed-markdown.sh")
test "$changed" = "bad.md" || fail "git diff listing returned: $changed"
rm -rf "$repo"

echo "All fixture checks passed."
