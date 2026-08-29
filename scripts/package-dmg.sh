#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${VERSION:-0.1.0}
case "$VERSION" in
  ''|.|..|*[!0-9A-Za-z._-]*)
    printf 'Invalid VERSION: use only letters, numbers, dots, underscores, and hyphens.\n' >&2
    exit 2
    ;;
esac
DERIVED="$ROOT/.build/release"
PRODUCT="$DERIVED/Build/Products/Release/DualTyper.inputmethod"
STAGE="$ROOT/.build/dmg-root"
DIST="$ROOT/dist"
DMG="$DIST/DualTyper-$VERSION.dmg"
if [ -n "${SIGN_IDENTITY:-}" ] || [ -n "${NOTARY_PROFILE:-}" ]; then
  printf 'package-dmg.sh creates local-test DMGs only; use a signed installer app/package for commercial distribution.\n' >&2
  exit 2
fi

cd "$ROOT"
mkdir -p "$DIST"
rm -rf -- "$DERIVED" "$STAGE"
mkdir -p "$STAGE"

xcodegen generate
swift test
xcodebuild \
  -project DualTyper.xcodeproj \
  -scheme DualTyperInputMethod \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  build

codesign --force --deep --sign - "$PRODUCT"
codesign --verify --deep --strict --verbose=2 "$PRODUCT"

/usr/bin/ditto "$PRODUCT" "$STAGE/DualTyper.inputmethod"
/usr/bin/ditto "$ROOT/Packaging/README.txt" "$STAGE/README.txt"

rm -f -- "$DMG"
hdiutil create \
  -volname "DualTyper $VERSION" \
  -srcfolder "$STAGE" \
  -format UDZO \
  -ov \
  "$DMG"

printf '%s\n' "$DMG"
