#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export TYPEFLUX_RELEASE_ARCH="${TYPEFLUX_RELEASE_ARCH:-x86_64}"

if [[ "$TYPEFLUX_RELEASE_ARCH" != "x86_64" ]]; then
  echo "Error: scripts/release_intel.sh only supports TYPEFLUX_RELEASE_ARCH=x86_64" >&2
  exit 1
fi

"${ROOT_DIR}/scripts/release_notarize.sh" "$@"
