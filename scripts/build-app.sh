#!/usr/bin/env bash
# Builds build/Leve.app for this Mac: release binary, Info.plist, release date, and a signature
# with the calendar entitlement. Leve has no public distribution, so it does not use the fleet's
# Sparkle-bound package-app.sh (AGENTS.md, "Release, signing, and secret-storage policy").
#
# Signing: DEVELOPER_ID_IDENTITY (from the shell or the untracked .env through make) gives a
# stable signature, so macOS keeps the calendar, notification and login-item permissions across
# rebuilds. Without it the build is ad-hoc and macOS asks again after each rebuild.
#
# Prints the app path on stdout and everything else on stderr.
set -euo pipefail
cd "$(dirname "$0")/.."

PLIST_BUDDY=${PLIST_BUDDY:-/usr/libexec/PlistBuddy}
PLIST=Support/Info.plist
ENTITLEMENTS=Support/Leve.entitlements

usage() {
  cat <<USAGE
usage: scripts/build-app.sh [options]
  --output <App.app>   bundle to create (default build/<Name>.app)
  --identity <id>      codesign identity (default \$DEVELOPER_ID_IDENTITY, else "-" ad-hoc)
  --force              replace an existing bundle
  --help               show this help
USAGE
}

fail_usage() { echo "error: $1" >&2; usage >&2; exit 2; }
need_value() { [[ $# -ge 2 && -n $2 && $2 != --* ]] || fail_usage "$1 needs a value"; }

app=''
identity=${DEVELOPER_ID_IDENTITY:--}
force=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --output) need_value "$@"; app=$2; shift 2 ;;
    --identity) need_value "$@"; identity=$2; shift 2 ;;
    --force) force=1; shift ;;
    --help) usage; exit 0 ;;
    *) fail_usage "unknown option $1" ;;
  esac
done

read_key() { "$PLIST_BUDDY" -c "Print :$1" "$PLIST" 2>/dev/null || { echo "error: $PLIST has no $1" >&2; exit 1; }; }
name=$(read_key CFBundleName)
executable=$(read_key CFBundleExecutable)
version=$(read_key CFBundleShortVersionString)
build=$(read_key CFBundleVersion)
app=${app:-build/$name.app}

if [[ -e $app ]]; then
  (( force )) || { echo "error: $app already exists; pass --force to replace it" >&2; exit 1; }
  rm -rf "$app"
fi

echo "Building $executable $version ($build)." >&2
swift build -c release --arch arm64 --product "$executable" >&2
bin_path=$(swift build -c release --arch arm64 --product "$executable" --show-bin-path)

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_path/$executable" "$app/Contents/MacOS/$executable"
cp "$PLIST" "$app/Contents/Info.plist"
cp Support/PrivacyInfo.xcprivacy "$app/Contents/Resources/PrivacyInfo.xcprivacy"
# Writes one .lproj per translated locale; an English-only catalog produces nothing yet.
xcrun xcstringstool compile Support/Localizable.xcstrings --output-directory "$app/Contents/Resources" >&2
# The app icon is the Icon Composer file, compiled into Assets.car and an AppIcon.icns fallback
# (project-setup swift-apps.md, App icon, #3). actool resolves paths against a long-lived helper's
# folder, so every path is absolute; with no matching icon it exits 0 and writes nothing.
app_abs=$(cd "$app" && pwd)
icon_plist=$(mktemp)
minimum_macos=$("$PLIST_BUDDY" -c "Print :LSMinimumSystemVersion" "$PLIST")
xcrun actool "$PWD/Support/AppIcon.icon" --compile "$app_abs/Contents/Resources" --platform macosx \
  --minimum-deployment-target "$minimum_macos" --app-icon AppIcon \
  --output-partial-info-plist "$icon_plist" --errors --warnings >&2
[[ -f $app_abs/Contents/Resources/Assets.car ]] || { echo "error: actool produced no Assets.car" >&2; exit 1; }
"$PLIST_BUDDY" -c "Merge $icon_plist" "$app/Contents/Info.plist"
rm -f "$icon_plist"

release_date=$(git log -1 --format=%cs 2>/dev/null || true)
if [[ -n $release_date ]]; then
  "$PLIST_BUDDY" -c "Add :AppReleaseDate string $release_date" "$app/Contents/Info.plist"
fi

sign=(codesign --force --sign "$identity" --entitlements "$ENTITLEMENTS" --options runtime)
if [[ $identity != - ]]; then
  sign+=(--timestamp)
fi
"${sign[@]}" "$app" >&2
codesign --verify --strict "$app" >&2

echo "Built $name $version ($build), identity $identity." >&2
printf '%s\n' "$app"
