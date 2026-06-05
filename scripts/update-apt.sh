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

DEB_AMD64=$(download_deb "amd64")
DEB_ARM64=$(download_deb "arm64")

cd "${APT_DIR}"
reprepro includedeb stable "${DEB_AMD64}"
reprepro includedeb stable "${DEB_ARM64}"

echo "Added ${PACKAGE} ${VERSION} to apt/stable"
