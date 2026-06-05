#!/usr/bin/env bash
# Add .deb packages from a GitHub release into the reprepro-managed apt repo.
# Usage: update-apt.sh <package> <version>
# Example: update-apt.sh mgit 1.0.1

set -euo pipefail

PACKAGE="${1:?package name required}"
VERSION="${2:?version required (without v prefix)}"
TAG="v${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
METADATA="${SCRIPT_DIR}/package-metadata.json"
APT_DIR="${ROOT_DIR}/apt"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

need() { command -v "$1" >/dev/null 2>&1 || { echo "required: $1" >&2; exit 1; }; }
need curl
need jq
need reprepro

REPO="$(jq -r --arg p "${PACKAGE}" '.[$p].repo' "${METADATA}")"

if [ "${REPO}" = "null" ]; then
  echo "unknown package: ${PACKAGE}" >&2
  exit 1
fi

download_deb() {
  local arch="$1"
  local deb="${PACKAGE}_${VERSION}_linux_${arch}.deb"
  local url="https://github.com/${REPO}/releases/download/${TAG}/${deb}"
  curl -fsSL "${url}" -o "${WORK_DIR}/${deb}"
  echo "${WORK_DIR}/${deb}"
}

ensure_apt_db() {
  local need_rebuild=false

  if [ ! -f db/version ]; then
    need_rebuild=true
  elif ! reprepro --export=never list stable >/dev/null 2>&1; then
    need_rebuild=true
  fi

  if [ "${need_rebuild}" = true ]; then
    echo "Rebuilding apt db from pool (reprepro version mismatch or missing db)..."
    rm -rf db/*
    while IFS= read -r -d '' deb; do
      reprepro --export=never includedeb stable "${deb}"
    done < <(find pool -name '*.deb' -print0 2>/dev/null | sort -z)
  fi
}

DEB_AMD64=$(download_deb "amd64")
DEB_ARM64=$(download_deb "arm64")

cd "${APT_DIR}"
ensure_apt_db
# Index only; export (and signing) happens in reexport-apt.sh or the workflow export step.
reprepro --export=never includedeb stable "${DEB_AMD64}"
reprepro --export=never includedeb stable "${DEB_ARM64}"

echo "Added ${PACKAGE} ${VERSION} to apt/stable"
