#!/bin/bash
# sync-version.sh
# Extracts version from pubspec.yaml and updates hardcoded version strings in code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
METADATA="$PROJECT_ROOT/lib/app_metadata.dart"

# Extract version from pubspec.yaml
VERSION=$(grep "^version:" "$PUBSPEC" | sed 's/version: *//' | cut -d'+' -f1)

if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from $PUBSPEC"
    exit 1
fi

echo "Extracted version: $VERSION"

# Update app_metadata.dart (single source of the in-app version string)
if [ -f "$METADATA" ]; then
    if grep -q "const String appVersion = '[0-9]\+\.[0-9]\+\.[0-9]\+';" "$METADATA"; then
        sed -i.bak "s/const String appVersion = '[0-9]\+\.[0-9]\+\.[0-9]\+';/const String appVersion = '$VERSION';/g" "$METADATA"
        rm -f "$METADATA.bak"
        echo "Updated $METADATA to $VERSION"
    else
        echo "Warning: Version pattern not found in $METADATA"
    fi
else
    echo "Warning: $METADATA not found"
fi

echo "Version sync complete: v$VERSION"
