#!/usr/bin/env bash
# Canonical packaging script for the owner's macOS apps. Copy it unchanged to
# scripts/package-app.sh in each app; project-setup alignment reports a drifted copy.
#
# Builds the release binary, assembles <Name>.app with Sparkle.framework embedded, checks that the
# packaged bundle identifier is the one in Support/Info.plist, signs nested code, then the
# framework, then the app, and archives the bundle with the only Sparkle-safe ZIP tool, ditto.
# Every app value comes from Support/Info.plist; nothing here names a product. A String Catalog at
# Support/Localizable.xcstrings is compiled into the bundle; a compiled Localizable table committed
# under Support/*.lproj is refused. The app icon is the Icon Composer file Support/AppIcon.icon,
# compiled with actool into Assets.car and an AppIcon.icns fallback; its two Info.plist keys come
# from actool, so a Support/Info.plist that already sets them is refused.
#
# Leve's copy differs from the canonical script in two places (AGENTS.md, divergence
# `canonical-scripts`; martonpaulo/skill-deck#518): Support/<Executable>.entitlements, when it
# exists, signs the app (never the nested Sparkle code), and Support/PrivacyInfo.xcprivacy, when it
# exists, is copied into Contents/Resources.
#
# Signing: the identity is --identity, else LOCAL_SIGNING_IDENTITY (an Apple Development
# certificate, for local builds), else DEVELOPER_ID_IDENTITY, else "-" (ad-hoc). A stable identity
# keeps the designated requirement, and with it Keychain access and privacy grants, across builds;
# an ad-hoc signature changes with every build. An identity named "Developer ID Application" always
# adds --timestamp --options runtime, which notarization requires; --hardened adds them to any
# other identity too.
#
# Stamps AppReleaseDate, the release date skd-macos-app-shell's version-and-release-date.md
# requires: the packaged commit's date, or --release-date.
#
# Prints the app path and the archive path on stdout, one per line, and everything else on stderr.
set -euo pipefail
cd "$(dirname "$0")/.."

PLIST_BUDDY=${PLIST_BUDDY:-/usr/libexec/PlistBuddy}
PLIST=Support/Info.plist

usage() {
  cat <<USAGE
usage: scripts/package-app.sh [options]
  --output <App.app>      bundle to create (default build/<Name>.app)
  --archive <path.zip>    archive to create (default artifacts/<Name>-<version>.zip)
  --identity <id>         codesign identity (default \$LOCAL_SIGNING_IDENTITY, else
                          \$DEVELOPER_ID_IDENTITY, else "-" ad-hoc)
  --version <X.Y.Z>       short version to stamp (requires --build-number)
  --build-number <N>      build number to stamp (requires --version)
  --release-date <date>   release date to stamp, YYYY-MM-DD (default: the commit date)
  --arch <arch>           build architecture (default arm64)
  --hardened              hardened runtime and timestamp for an identity that is not a
                          "Developer ID Application" one, which always gets them
  --force                 replace an existing bundle or archive
  --help                  show this help
USAGE
}

fail_usage() { echo "error: $1" >&2; usage >&2; exit 2; }
need_value() { [[ $# -ge 2 && -n $2 && $2 != --* ]] || fail_usage "$1 needs a value"; }

app=''
archive=''
identity=${LOCAL_SIGNING_IDENTITY:-${DEVELOPER_ID_IDENTITY:--}}
version=''
build_number=''
release_date=''
arch=arm64
hardened=0
force=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --output) need_value "$@"; app=$2; shift 2 ;;
    --archive) need_value "$@"; archive=$2; shift 2 ;;
    --identity) need_value "$@"; identity=$2; shift 2 ;;
    --version) need_value "$@"; version=$2; shift 2 ;;
    --build-number) need_value "$@"; build_number=$2; shift 2 ;;
    --release-date)
      need_value "$@"
      [[ $2 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail_usage "--release-date needs YYYY-MM-DD, not $2"
      release_date=$2
      shift 2
      ;;
    --arch) need_value "$@"; arch=$2; shift 2 ;;
    --hardened) hardened=1; shift ;;
    --force) force=1; shift ;;
    --help) usage; exit 0 ;;
    *) fail_usage "unknown option $1" ;;
  esac
done
if [[ -n $version && -z $build_number || -z $version && -n $build_number ]]; then
  fail_usage '--version and --build-number must be given together'
fi

[[ -f $PLIST ]] || { echo "error: $PLIST not found; run this from an app repository" >&2; exit 1; }
read_key() { # $1 key, $2 plist
  "$PLIST_BUDDY" -c "Print :$1" "$2" 2>/dev/null || { echo "error: $2 has no $1" >&2; exit 1; }
}
name=$(read_key CFBundleName "$PLIST")
executable=$(read_key CFBundleExecutable "$PLIST")
bundle_id=$(read_key CFBundleIdentifier "$PLIST")
[[ -n $version ]] || version=$(read_key CFBundleShortVersionString "$PLIST")
[[ -n $build_number ]] || build_number=$(read_key CFBundleVersion "$PLIST")
app=${app:-build/$name.app}
archive=${archive:-artifacts/$name-$version.zip}

# The catalog is the one source of the Localizable table; a committed compiled copy would go stale.
catalog=Support/Localizable.xcstrings
if [[ -f $catalog ]]; then
  for compiled in Support/*.lproj/Localizable.strings Support/*.lproj/Localizable.stringsdict; do
    if [[ -e $compiled ]]; then
      echo "error: $compiled and $catalog both define the Localizable table; delete $compiled, this script compiles the catalog" >&2
      exit 1
    fi
  done
fi

# The icon's Info.plist keys come from actool. PlistBuddy Merge keeps a key that already exists, so a
# stale CFBundleIconFile or CFBundleIconName in the source plist would win silently.
icon=Support/AppIcon.icon
[[ -d $icon ]] || { echo "error: $icon not found; author the app icon in Icon Composer and commit it there" >&2; exit 1; }
for key in CFBundleIconFile CFBundleIconName; do
  if "$PLIST_BUDDY" -c "Print :$key" "$PLIST" >/dev/null 2>&1; then
    echo "error: $PLIST sets $key; delete it, actool writes the icon keys from $icon" >&2
    exit 1
  fi
done
minimum=$(read_key LSMinimumSystemVersion "$PLIST")

for existing in "$app" "$archive"; do
  if [[ -e $existing ]]; then
    (( force )) || { echo "error: $existing already exists; pass --force to replace it" >&2; exit 1; }
    rm -rf "$existing"
  fi
done

echo "Building $executable $version ($build_number) for $arch." >&2
swift build -c release --arch "$arch" --product "$executable" >&2
bin_path=$(swift build -c release --arch "$arch" --product "$executable" --show-bin-path)

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$bin_path/$executable" "$app/Contents/MacOS/$executable"
cp "$PLIST" "$app/Contents/Info.plist"
if [[ -f Support/PrivacyInfo.xcprivacy ]]; then
  cp Support/PrivacyInfo.xcprivacy "$app/Contents/Resources/PrivacyInfo.xcprivacy"
fi
for lproj in Support/*.lproj; do
  if [[ -d $lproj ]]; then
    ditto "$lproj" "$app/Contents/Resources/$(basename "$lproj")"
  fi
done
if [[ -f $catalog ]]; then
  xcrun xcstringstool compile "$catalog" --output-directory "$app/Contents/Resources" >&2
  # An entry without a source-language value compiles to nothing, and the tool still exits 0.
  tables=0
  for table in "$app"/Contents/Resources/*.lproj/Localizable.strings; do
    [[ -f $table ]] && tables=$((tables + 1))
  done
  if (( tables == 0 )); then
    echo "error: xcstringstool compiled no Localizable.strings from $catalog; give every entry a value in the source language" >&2
    exit 1
  fi
fi
# actool hands the work to a long-lived ibtoold, which resolves a relative path against the folder
# of whichever call started it, so every path it gets is absolute. One call compiles the icon and any
# asset catalog, because each call writes a whole Assets.car.
absolute() { if [[ $1 == /* ]]; then printf '%s\n' "$1"; else printf '%s/%s\n' "$PWD" "$1"; fi; }
resources=$(absolute "$app/Contents/Resources")
assets=("$PWD/$icon")
if [[ -d Support/Assets.xcassets ]]; then
  assets+=("$PWD/Support/Assets.xcassets")
fi
icon_plist=$(mktemp "${TMPDIR:-/tmp}/package-app-icon.XXXXXX")
trap 'rm -f "$icon_plist"' EXIT
xcrun actool "${assets[@]}" --compile "$resources" --platform macosx \
  --minimum-deployment-target "$minimum" --app-icon AppIcon \
  --output-partial-info-plist "$icon_plist" --errors --warnings >&2
# On a name mismatch actool exits 0 and writes nothing.
if [[ ! -f $resources/Assets.car ]]; then
  echo "error: actool produced no Assets.car from $icon; the .icon must be named AppIcon" >&2
  exit 1
fi
"$PLIST_BUDDY" -c "Merge $icon_plist" "$app/Contents/Info.plist"
rm -f "$icon_plist"

# ditto keeps the framework's symlinks; cp -R flattens them and breaks Sparkle's signature.
sparkle=$bin_path/Sparkle.framework
[[ -d $sparkle ]] || { echo "error: Sparkle.framework not found at $sparkle" >&2; exit 1; }
framework=$app/Contents/Frameworks/Sparkle.framework
ditto "$sparkle" "$framework"

"$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
"$PLIST_BUDDY" -c "Set :CFBundleVersion $build_number" "$app/Contents/Info.plist"
if [[ -z $release_date ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  release_date=$(git log -1 --format=%cs 2>/dev/null || true)
fi
if [[ -n $release_date ]]; then
  if "$PLIST_BUDDY" -c "Print :AppReleaseDate" "$app/Contents/Info.plist" >/dev/null 2>&1; then
    "$PLIST_BUDDY" -c "Set :AppReleaseDate $release_date" "$app/Contents/Info.plist"
  else
    "$PLIST_BUDDY" -c "Add :AppReleaseDate string $release_date" "$app/Contents/Info.plist"
  fi
else
  echo "No Git commit and no --release-date: the bundle carries no AppReleaseDate." >&2
fi

# Keychain items and UserDefaults are keyed by the bundle identifier, so a second one silently
# orphans the user's data. Check it before anything is signed or archived.
packaged_id=$(read_key CFBundleIdentifier "$app/Contents/Info.plist")
if [[ $packaged_id != "$bundle_id" ]]; then
  echo "error: the packaged bundle identifier is $packaged_id, but $PLIST says $bundle_id" >&2
  exit 1
fi

sign=(codesign --force --sign "$identity")
if (( hardened )) || [[ $identity == 'Developer ID Application:'* ]]; then
  sign+=(--timestamp --options runtime)
fi
# Nested code first, then the framework, then the app. The version directories are discovered,
# because the letter is Sparkle's to choose.
for version_dir in "$framework"/Versions/*; do
  if [[ -L $version_dir || ! -d $version_dir ]]; then
    continue
  fi
  for nested in "$version_dir"/XPCServices/*.xpc "$version_dir/Autoupdate" "$version_dir/Updater.app"; do
    if [[ -e $nested ]]; then
      "${sign[@]}" "$nested" >&2
    fi
  done
done
"${sign[@]}" "$framework" >&2
app_entitlements=()
if [[ -f Support/$executable.entitlements ]]; then
  app_entitlements=(--entitlements "Support/$executable.entitlements")
fi
# The +-form keeps an empty array legal under set -u in Bash 3.2.
"${sign[@]}" ${app_entitlements[@]+"${app_entitlements[@]}"} "$app" >&2
codesign --verify --deep --strict "$app" >&2

mkdir -p "$(dirname "$archive")"
ditto -c -k --keepParent "$app" "$archive" >&2
echo "Packaged $name $version ($build_number), released ${release_date:-undated}, identity $identity." >&2
printf '%s\n%s\n' "$app" "$archive"
