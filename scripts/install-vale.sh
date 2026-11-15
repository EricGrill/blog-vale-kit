#!/usr/bin/env bash
# Install the pinned Vale CLI into DEST (default: <kit>/.tools).
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(tr -d '[:space:]' < "$root/VALE_VERSION")
dest=${1:-"$root/.tools"}
mkdir -p "$dest"

if [ -x "$dest/vale" ]; then
  got=$("$dest/vale" --version 2>/dev/null || true)
  case "$got" in
    *" ${version}")
      exit 0
      ;;
  esac
fi

os=$(uname -s)
arch=$(uname -m)
case "${os}-${arch}" in
  Linux-x86_64) platform="Linux_64-bit" ;;
  Linux-aarch64 | Linux-arm64) platform="Linux_arm64" ;;
  Darwin-arm64) platform="macOS_arm64" ;;
  Darwin-x86_64) platform="macOS_64-bit" ;;
  *)
    echo "Unsupported platform: ${os} ${arch}" >&2
    exit 1
    ;;
esac

asset="vale_${version}_${platform}.tar.gz"
url="https://github.com/vale-cli/vale/releases/download/v${version}/${asset}"
checksum_file="$root/scripts/checksums/vale_${version}.txt"
expected=$(awk -v asset="$asset" '$2 == asset { print $1 }' "$checksum_file")
if [ -z "$expected" ]; then
  echo "No checksum for ${asset} in ${checksum_file}" >&2
  exit 1
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
curl -fsSL -o "$workdir/$asset" "$url"

if command -v sha256sum >/dev/null 2>&1; then
  echo "${expected}  ${workdir}/${asset}" | sha256sum -c -
else
  echo "${expected}  ${workdir}/${asset}" | shasum -a 256 -c -
fi

tar -xzf "$workdir/$asset" -C "$workdir"
install -m 755 "$workdir/vale" "$dest/vale"
"$dest/vale" --version
