#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DERIVED="$ROOT/.build/release-menubar"
PRODUCTS="$DERIVED/Build/Products/Release"
APP="$PRODUCTS/DualTyper.app"
STAGE="$ROOT/.build/dmg-root-menubar"
DIST="$ROOT/dist"
CREATE_DMG=/opt/homebrew/bin/create-dmg

fail() {
  printf '%s\n' "$1" >&2
  exit 2
}

plist_version() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1"
}

verify_universal() {
  executable=$1
  label=$2
  archs=$(lipo -archs "$executable")
  /usr/bin/python3 - "$archs" "$label" <<'PY'
import sys
architectures = sys.argv[1].split()
label = sys.argv[2]
if sorted(architectures) != ["arm64", "x86_64"]:
    raise SystemExit(f"{label} must contain exactly arm64 and x86_64; found: {' '.join(architectures)}")
PY
}

cd "$ROOT"
mkdir -p "$DIST"
rm -rf -- "$DERIVED" "$STAGE"
mkdir -p "$STAGE"

xcodegen generate
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
./scripts/test-core.sh
xcodebuild -project DualTyper.xcodeproj -scheme DualTyperMenuBar \
  -configuration Release -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build

test -d "$APP" || fail 'DualTyper.app was not built.'
VERSION=$(plist_version "$APP/Contents/Info.plist") || fail 'Could not read the built app version.'
case "$VERSION" in
  ''|.|..|*[!0-9A-Za-z._-]*) fail 'Built app has an invalid version.' ;;
esac

APP_EXEC="$APP/Contents/MacOS/DualTyper"
verify_universal "$APP_EXEC" 'DualTyper executable'

# Ad-hoc signing gives the bundle internal code-integrity metadata but does not
# identify the developer to Gatekeeper. Users must explicitly approve this build.
codesign --force --sign - "$APP_EXEC"
codesign --force --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

DMG="$DIST/DualTyper-$VERSION-FREE-UNNOTARIZED.dmg"
VOLNAME="DualTyper $VERSION FREE"
rm -f -- "$DMG" "$DMG.sha256"
/usr/bin/ditto "$APP" "$STAGE/DualTyper.app"

if [ -x "$CREATE_DMG" ] && "$CREATE_DMG" \
  --volname "$VOLNAME" \
  --background "$ROOT/Packaging/dmg-background.png" \
  --window-pos 200 120 --window-size 660 420 \
  --text-size 14 --icon-size 128 \
  --icon 'DualTyper.app' 160 210 \
  --hide-extension 'DualTyper.app' \
  --app-drop-link 500 210 \
  --format UDZO --filesystem HFS+ --overwrite \
  "$DMG" "$STAGE"; then
  :
else
  printf 'create-dmg layout failed; creating a plain verified DMG.\n' >&2
  rm -f -- "$DMG"
  rm -rf -- "$STAGE/Applications"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
fi

hdiutil verify "$DMG"
ATTACH_PLIST=$(mktemp "${TMPDIR:-/tmp}/dualtyper-menubar-attach.XXXXXX")
MOUNT_POINT=''
cleanup_mount() {
  if [ -n "$MOUNT_POINT" ]; then
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  rm -f -- "$ATTACH_PLIST"
}
trap cleanup_mount EXIT HUP INT TERM
hdiutil attach -readonly -nobrowse -plist "$DMG" > "$ATTACH_PLIST"
MOUNT_POINT=$(/usr/bin/python3 -c 'import plistlib,sys; p=plistlib.load(open(sys.argv[1], "rb")); print(next(e["mount-point"] for e in p["system-entities"] if "mount-point" in e))' "$ATTACH_PLIST")
[ -n "$MOUNT_POINT" ] || fail 'DMG did not mount.'

payload_count=0
for item in "$MOUNT_POINT"/* "$MOUNT_POINT"/.[!.]* "$MOUNT_POINT"/..?*; do
  [ -e "$item" ] || [ -L "$item" ] || continue
  name=${item##*/}
  case "$name" in
    .DS_Store|.background) continue ;;
    DualTyper.app) [ -d "$item" ] || fail 'DualTyper.app is not an app directory.' ;;
    Applications)
      [ -L "$item" ] || fail 'Applications is not a symlink.'
      [ "$(readlink "$item")" = '/Applications' ] || fail 'Applications symlink has the wrong target.'
      ;;
    *) fail "Unexpected visible DMG payload: $name" ;;
  esac
  payload_count=$((payload_count + 1))
done
[ "$payload_count" -eq 2 ] || fail 'DMG must contain only DualTyper.app and Applications.'

MOUNTED_APP="$MOUNT_POINT/DualTyper.app"
verify_universal "$MOUNTED_APP/Contents/MacOS/DualTyper" 'Packaged DualTyper executable'
codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP"

hdiutil detach "$MOUNT_POINT" >/dev/null
MOUNT_POINT=''
trap - EXIT HUP INT TERM
rm -f -- "$ATTACH_PLIST"

(
  cd "$DIST"
  basename=$(basename "$DMG")
  shasum -a 256 "$basename" > "$basename.sha256"
  shasum -a 256 -c "$basename.sha256"
)

# Rejection is expected and proves we are not presenting this as notarized.
if spctl --assess --type execute --verbose=2 "$APP" >/dev/null 2>&1; then
  fail 'Gatekeeper unexpectedly accepted the free unnotarized app; inspect signing state.'
fi

printf '%s\n' "$DMG"
