#!/usr/bin/env bash
# Re-export apt metadata and sign Release files (requires signing key in gpg agent).
# Usage: reexport-apt.sh [key-id]
# Example: reexport-apt.sh A65A5762C418D457

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APT_DIR="$(cd "${SCRIPT_DIR}/../apt" && pwd)"
DIST_FILE="${APT_DIR}/conf/distributions"
KEY_ID="${1:-}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "required: $1" >&2; exit 1; }; }
need reprepro
need gpg

if [ -z "${KEY_ID}" ]; then
  KEY_ID="$(gpg --list-secret-keys --keyid-format long --with-colons \
    | awk -F: '/^sec:/ && $12 ~ /s/ { print $5; exit }')"
fi

if [ -z "${KEY_ID}" ]; then
  echo "no signing key found; pass key-id as argument or import ci-subkey.asc" >&2
  exit 1
fi

if ! echo test | gpg --batch --yes --local-user "${KEY_ID}" --clearsign >/dev/null 2>&1; then
  echo "cannot sign with key ${KEY_ID}" >&2
  echo "Secret keys in agent:" >&2
  gpg --list-secret-keys --keyid-format long >&2 || true
  echo >&2
  echo "Common causes:" >&2
  echo "  - GPG_PRIVATE_KEY was exported with --export-secret-subkeys but does not include" >&2
  echo "    the signing key (check: gpg --list-keys --keyid-format long)" >&2
  echo "  - GPG_PASSPHRASE is missing or wrong in GitHub repo secrets" >&2
  echo >&2
  echo "If signing lives on the primary key, export with:" >&2
  echo "  gpg --armor --export-secret-keys ${KEY_ID} > ci-signing-key.asc" >&2
  exit 1
fi

# Ensure SignWith is set exactly once
if grep -q '^SignWith:' "${DIST_FILE}"; then
  sed -i "s/^SignWith:.*/SignWith: ${KEY_ID}/" "${DIST_FILE}"
else
  sed -i "s/^# SignWith:.*/SignWith: ${KEY_ID}/" "${DIST_FILE}"
  if ! grep -q '^SignWith:' "${DIST_FILE}"; then
    echo "SignWith: ${KEY_ID}" >> "${DIST_FILE}"
  fi
fi

cd "${APT_DIR}"
reprepro export stable

if [ ! -f dists/stable/InRelease ] && [ ! -f dists/stable/Release.gpg ]; then
  echo "export finished but InRelease/Release.gpg missing — check gpg key" >&2
  exit 1
fi

echo "Signed apt metadata exported for stable (key ${KEY_ID})"
