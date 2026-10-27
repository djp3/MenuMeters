#!/bin/sh
# Builds the app this fork releases and, on request, publishes it.
#
#   ./build-release.sh                archives the "MenuMeters" scheme, signs the app with
#                                     the Developer ID, notarizes and staples it, zips it
#                                     with THIRD-PARTY-NOTICES.md, and writes the Sparkle
#                                     appcast for every release so far, all into build/release
#   ./build-release.sh --publish      all of the above, then tags v<version>, pushes the
#                                     branch and the tag to the djp3 remote, and creates the
#                                     GitHub release with the zip and the appcast attached
#   ./build-release.sh --no-notarize  a local test build, signed but not notarized
#
# Needs Xcode 27; the Developer ID Application certificate of team 9B6T3L36ML in the login
# keychain; a notarytool keychain profile (NOTARY_PROFILE, default AC_PASSWORD, stored with
# xcrun notarytool store-credentials); Sparkle's sign_update with the fork's EdDSA key in the
# keychain (SIGN_UPDATE, default ~/local/scripts/sparkle-2.9.5/sign_update); python3; and gh
# logged in to GitHub as djp3.
#
# The version is MM_VERSION in InfoPlistPreprocessor.h. The release notes are
# release-notes/<version>.md, shown on the GitHub release and in Sparkle's update window.
# Debug information is turned off because the binary's debug map would carry the build
# machine's folder paths.
set -eu
cd "$(dirname "$0")"

REPO=djp3/MenuMeters
REMOTE=djp3
NOTARY_PROFILE=${NOTARY_PROFILE:-AC_PASSWORD}
SIGN_UPDATE=${SIGN_UPDATE:-$HOME/local/scripts/sparkle-2.9.5/sign_update}
FEED=https://github.com/$REPO/releases/latest/download/appcast.xml

fail() { echo "build-release: $*" >&2; exit 1; }

NOTARIZE=yes
PUBLISH=no
for arg in "$@"; do
	case $arg in
		--publish) PUBLISH=yes ;;
		--no-notarize) NOTARIZE=no ;;
		*) echo "usage: $0 [--publish] [--no-notarize]" >&2; exit 2 ;;
	esac
done
[ $PUBLISH = no ] || [ $NOTARIZE = yes ] || fail "a published release must be notarized"

VERSION=$(sed -n 's/^#define MM_VERSION[[:space:]]*\([^[:space:]]*\).*/\1/p' InfoPlistPreprocessor.h)
[ -n "$VERSION" ] || fail "MM_VERSION not found in InfoPlistPreprocessor.h"
TAG=v$VERSION
NOTES=release-notes/$VERSION.md
ARCHIVE=build/MenuMeters.xcarchive
EXPORT=build/export
APP=$EXPORT/MenuMeters.app
RELEASE_DIR=build/release
ZIP=$RELEASE_DIR/MenuMeters-$VERSION.zip
APPCAST=$RELEASE_DIR/appcast.xml

# Everything the later steps need, checked before the long build starts.
[ -f "$NOTES" ] || fail "release notes missing: $NOTES"
[ -x "$SIGN_UPDATE" ] || fail "sign_update not found at $SIGN_UPDATE"
if [ $NOTARIZE = yes ]; then
	xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
		|| fail "notarytool profile '$NOTARY_PROFILE' not found; store one with: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <Apple ID> --team-id 9B6T3L36ML"
fi
if [ $PUBLISH = yes ]; then
	[ -z "$(git status --porcelain)" ] || fail "commit or stash your changes first; the release tag must point at a committed tree"
	BRANCH=$(git rev-parse --abbrev-ref HEAD)
	[ "$BRANCH" != HEAD ] || fail "check out a branch first; the release is pushed with its branch"
	git remote get-url $REMOTE >/dev/null 2>&1 || fail "no git remote named $REMOTE"
	! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || fail "tag $TAG already exists"
	gh auth status >/dev/null 2>&1 || fail "gh is not logged in to GitHub"
	! gh release view "$TAG" -R $REPO >/dev/null 2>&1 || fail "release $TAG already exists on GitHub"
fi

echo "==> Building MenuMeters $VERSION"
rm -rf "$ARCHIVE" "$EXPORT" build/stage
xcodebuild -project MenuMeters.xcodeproj -scheme MenuMeters -configuration Release \
	-archivePath "$ARCHIVE" -derivedDataPath build/DerivedData \
	CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
	GCC_GENERATE_DEBUGGING_SYMBOLS=NO DEBUG_INFORMATION_FORMAT=dwarf archive

echo "==> Signing with the Developer ID"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist exportOptions.plist \
	-exportPath "$EXPORT" -allowProvisioningUpdates
codesign --verify --deep --strict --verbose=2 "$APP"
BUILT=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
[ "$BUILT" = "$VERSION" ] || fail "the app reports version $BUILT but InfoPlistPreprocessor.h says $VERSION"

if [ $NOTARIZE = yes ]; then
	echo "==> Notarizing"
	rm -f build/MenuMeters-submit.zip
	ditto -c -k --keepParent "$APP" build/MenuMeters-submit.zip
	xcrun notarytool submit build/MenuMeters-submit.zip --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 | tee build/notarization.log
	if ! grep -q 'status: Accepted' build/notarization.log; then
		ID=$(sed -n 's/^ *id: //p' build/notarization.log | head -1)
		[ -z "$ID" ] || xcrun notarytool log "$ID" --keychain-profile "$NOTARY_PROFILE"
		fail "Apple did not accept the app; the log above says why"
	fi
	xcrun stapler staple "$APP"
	spctl -a -vv -t execute "$APP" 2>&1 | grep -q 'Notarized Developer ID' || fail "Gatekeeper does not see the app as notarized"
fi

echo "==> Packaging $ZIP"
mkdir -p build/stage "$RELEASE_DIR"
cp -R "$APP" build/stage/
cp THIRD-PARTY-NOTICES.md build/stage/
rm -f "$ZIP"
ditto -c -k build/stage "$ZIP"

echo "==> Writing the appcast"
# Every published release is an item too, so the feed lists the whole history.
gh release list -R $REPO --json tagName -q '.[].tagName' | while read -r tag; do
	gh release download "$tag" -R $REPO -p 'MenuMeters-*.zip' -D "$RELEASE_DIR" --skip-existing \
		|| echo "no MenuMeters-*.zip on release $tag; skipped"
done
python3 scripts/appcast.py "$RELEASE_DIR" --notes-dir release-notes --sign-update "$SIGN_UPDATE" --output "$APPCAST"

if [ $PUBLISH = yes ]; then
	echo "==> Publishing $TAG to $REPO"
	git tag -a "$TAG" -m "MenuMeters $VERSION"
	git push $REMOTE "$BRANCH" "$TAG"
	{
		cat "$NOTES"
		printf '\nSHA-256 of %s: `%s`\n' "$(basename "$ZIP")" "$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
	} > build/release-body.md
	gh release create "$TAG" -R $REPO --verify-tag --latest --title "MenuMeters $VERSION" \
		--notes-file build/release-body.md "$ZIP" "$APPCAST"
	echo "==> Checking the feed"
	sleep 10
	if curl -sSL "$FEED" | diff -q - "$APPCAST" >/dev/null; then
		echo "The feed at $FEED serves the new appcast."
	else
		echo "The feed at $FEED does not match $APPCAST yet; check it again in a minute." >&2
	fi
fi

echo "Built $ZIP"
echo "Appcast $APPCAST"
[ $PUBLISH = yes ] || echo "Run ./build-release.sh --publish to release it."
