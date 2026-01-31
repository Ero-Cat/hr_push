#!/bin/bash
# sync-version.sh
# Extracts version from pubspec.yaml and updates hardcoded version strings in code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
SETTINGS_PAGE="$PROJECT_ROOT/lib/pages/settings_page.dart"

# Extract version from pubspec.yaml
VERSION=$(grep "^version:" "$PUBSPEC" | sed 's/version: *//' | cut -d'+' -f1)

if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from $PUBSPEC"
    exit 1
fi

echo "Extracted version: $VERSION"

# Update settings_page.dart
if [ -f "$SETTINGS_PAGE" ]; then
    # Replace version string pattern 'v1.x.x' with new version
    if grep -q "'v[0-9]\+\.[0-9]\+\.[0-9]\+'" "$SETTINGS_PAGE"; then
        sed -i.bak "s/'v[0-9]\+\.[0-9]\+\.[0-9]\+'/'v$VERSION'/g" "$SETTINGS_PAGE"
        rm -f "$SETTINGS_PAGE.bak"
        echo "Updated $SETTINGS_PAGE to v$VERSION"
    else
        echo "Warning: Version pattern not found in $SETTINGS_PAGE"
    fi
else
    echo "Warning: $SETTINGS_PAGE not found"
fi

echo "Version sync complete: v$VERSION"
