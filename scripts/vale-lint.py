#!/usr/bin/env python3
"""Run Vale and print GitHub Actions annotations.

Suggestions and warnings never fail the process. Error-level alerts fail the
process only when --fail-on-error is set. Without that flag, errors are
annotated as warnings so a rollout can stay warning-only.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def escape(value: str) -> str:
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def relativize(path: str) -> str:
    candidate = Path(path)
    if not candidate.is_absolute():
        return path
    try:
        return str(candidate.resolve().relative_to(Path.cwd().resolve()))
    except ValueError:
        return path


def flatten(payload: object) -> list[tuple[str, dict]]:
    if not isinstance(payload, dict):
        return []
    items: list[tuple[str, dict]] = []
    for path, alerts in payload.items():
        if not isinstance(alerts, list):
            continue
        for alert in alerts:
            if isinstance(alert, dict):
                items.append((str(path), alert))
    return items


def annotation(path: str, alert: dict, fail_on_error: bool) -> str:
    severity = str(alert.get("Severity") or "suggestion").lower()
    level = "error" if severity == "error" and fail_on_error else "warning"
    line = int(alert.get("Line") or 1)
    span = alert.get("Span") or [1]
    col = int(span[0]) if span else 1
    check = str(alert.get("Check") or "Vale")
    message = str(alert.get("Message") or "Vale alert")
    if severity == "error" and not fail_on_error:
        message = f"(error) {message}"
    props = f"file={escape(relativize(path))},line={line},col={col},title={escape(check)}"
    return f"::{level} {props}::{escape(message)}"


def read_paths(file_list: str) -> list[str]:
    text = Path(file_list).read_text(encoding="utf-8")
    paths: list[str] = []
    seen: set[str] = set()
    for line in text.splitlines():
        path = line.strip()
        if not path or path in seen:
            continue
        seen.add(path)
        if not Path(path).is_file():
            print(f"Skipping missing file: {path}", file=sys.stderr)
            continue
        paths.append(path)
    return paths


def write_summary(suggestions: int, warnings: int, errors: int, fail_on_error: bool) -> None:
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary:
        return
    lines = [
        "### Vale",
        "",
        f"{suggestions} suggestions, {warnings} warnings, {errors} errors.",
    ]
    if errors and not fail_on_error:
        lines.append("")
        lines.append(
            "Error-level alerts were reported as warnings. "
            "Set `fail_on_error: true` to fail the check on errors."
        )
    with open(summary, "a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Lint prose with Vale and emit annotations.")
    parser.add_argument("--fail-on-error", action="store_true")
    parser.add_argument("--config", default="")
    parser.add_argument("--file-list", default="")
    parser.add_argument("files", nargs="*")
    args = parser.parse_args()

    files = list(args.files)
    if args.file_list:
        files.extend(read_paths(args.file_list))
    if not files:
        print("No Markdown or MDX files to lint.")
        return 0

    if args.config and not Path(args.config).is_file():
        print(
            f"Missing {args.config}. Copy .vale.ini from https://github.com/EricGrill/blog-vale-kit",
            file=sys.stderr,
        )
        return 1

    cmd = ["vale", "--no-global", "--output=JSON", "--no-exit"]
    if args.config:
        cmd.extend(["--config", args.config])
    cmd.extend(files)

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stderr:
        sys.stderr.write(result.stderr)
    if result.returncode != 0:
        if result.stdout:
            sys.stderr.write(result.stdout)
        return result.returncode

    raw = result.stdout.strip()
    payload: object = {}
    if raw:
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            sys.stderr.write(result.stdout)
            print("Vale did not return JSON.", file=sys.stderr)
            return 2

    items = flatten(payload)
    suggestions = warnings = errors = 0
    for path, alert in items:
        severity = str(alert.get("Severity") or "suggestion").lower()
        if severity == "error":
            errors += 1
        elif severity == "warning":
            warnings += 1
        else:
            suggestions += 1
        print(annotation(path, alert, args.fail_on_error))

    print(
        f"Vale: {suggestions} suggestion(s), {warnings} warning(s), {errors} error(s).",
        file=sys.stderr,
    )
    write_summary(suggestions, warnings, errors, args.fail_on_error)
    if args.fail_on_error and errors:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
