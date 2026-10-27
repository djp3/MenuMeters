#!/bin/sh
# Builds the app in this fork's releases: the "MenuMeters No Sparkle" scheme's
# Release archive, universal and ad-hoc signed, built without debug
# information. With it, the binary's debug map carries the build machine's
# folder paths, and Xcode 27's archive does not strip them. Needs Xcode 27.
# The app lands in build/MenuMeters.xcarchive/Products/Applications/.
set -eu
cd "$(dirname "$0")"
rm -rf build/MenuMeters.xcarchive
xcodebuild -project MenuMeters.xcodeproj -scheme "MenuMeters No Sparkle" \
	-archivePath build/MenuMeters.xcarchive -derivedDataPath build/DerivedData \
	GCC_GENERATE_DEBUGGING_SYMBOLS=NO DEBUG_INFORMATION_FORMAT=dwarf archive
echo "Built build/MenuMeters.xcarchive/Products/Applications/MenuMeters.app"
