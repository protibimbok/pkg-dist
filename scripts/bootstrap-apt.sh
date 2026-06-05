#!/usr/bin/env bash
# Seed the apt repo with existing release .deb files.
# Run locally after installing reprepro: sudo apt install reprepro
# Usage: bootstrap-apt.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APT_DIR="$(cd "${SCRIPT_DIR}/../apt" && pwd)"

cd "${APT_DIR}"

./../scripts/update-apt.sh mgit 1.0.1
./../scripts/update-apt.sh phnx 1.0.2

echo "Bootstrap complete. Review apt/dists/ and apt/pool/ before committing."
