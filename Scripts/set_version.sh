cash/Scripts/set_version.sh
#!/bin/bash

# Script to set CFBundleShortVersionString in the Info.plist
# Usage: ./set_version.sh <version>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION=$1

# Path to the Info.plist in the build directory
PLIST_PATH="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "$PLIST_PATH" ]; then
    echo "Info.plist not found at $PLIST_PATH"
    exit 1
fi

# Set the CFBundleShortVersionString
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST_PATH"

echo "Set CFBundleShortVersionString to $VERSION"
