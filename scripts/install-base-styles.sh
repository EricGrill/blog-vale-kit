#!/usr/bin/env bash
# Copy this kit's Base style and Base vocabulary into a blog checkout.
# Usage: install-base-styles.sh [dest]
# dest defaults to the current directory. Example styles are not copied.
set -euo pipefail

kit_root=$(cd "$(dirname "$0")/.." && pwd)
dest=$(cd "${1:-.}" && pwd)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$kit_root/styles/Base" "$tmp/Base"
cp -R "$kit_root/styles/config/vocabularies/Base" "$tmp/BaseVocab"

mkdir -p "$dest/styles/config/vocabularies"
rm -rf "$dest/styles/Base"
cp -R "$tmp/Base" "$dest/styles/Base"
rm -rf "$dest/styles/config/vocabularies/Base"
cp -R "$tmp/BaseVocab" "$dest/styles/config/vocabularies/Base"
