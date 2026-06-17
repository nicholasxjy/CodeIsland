#!/usr/bin/env bash
set -euo pipefail

# Build the newest CodeIsland DMG using the version recorded in Info.plist.
# Pass a version explicitly to override it:
#   ./scripts/package-latest-dmg.sh 1.0.28

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$REPO_ROOT/Info.plist"
VERSION="${1:-}"

if [ -z "$VERSION" ]; then
    VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
fi

if [ -z "$VERSION" ]; then
    echo "ERROR: Could not determine CodeIsland version" >&2
    exit 1
fi

echo "==> Packaging CodeIsland ${VERSION}"
exec "$REPO_ROOT/scripts/build-dmg.sh" "$VERSION"
