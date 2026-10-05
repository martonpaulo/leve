#!/usr/bin/env bash
# Canonical version bump for the owner's macOS apps (#484). Copy it unchanged to
# scripts/bump-version.sh in each app, beside release-notes.sh; project-setup alignment reports a
# drifted copy.
#
# `scripts/bump-version.sh X.Y.Z` moves the app to version X.Y.Z in one step:
#   - CFBundleShortVersionString becomes X.Y.Z and CFBundleVersion the derived build
#     MAJOR*10000 + MINOR*100 + PATCH, both through `PlistBuddy -c "Set …"`, never a text
#     substitution: as a pattern, 2.3.0 also matches the build 20300 (#362);
#   - `## [Unreleased]` becomes an empty `## [Unreleased]` above `## [X.Y.Z] - YYYY-MM-DD`, which
#     takes the notes that were under it;
#   - an `[Unreleased]: <base>/compare/<old tag>...HEAD` link moves to the new tag, and a
#     `[X.Y.Z]: <base>/compare/<old tag>...<new tag>` link is added below it;
#   - release-notes.sh --check then confirms the changelog and the plist agree.
#
# Everything is checked before the first write: the version shape, a version strictly above the
# current one, exactly one `## [Unreleased]` above every version and with notes under it, and no
# existing `## [X.Y.Z]` heading. A refused bump changes no file. Other files that carry the version
# stay with the release workflow.
#
# Exit 0 = bumped and checked; 1 = refused or the final check failed; 2 = usage error.
set -euo pipefail
cd "$(dirname "$0")/.."

PLIST_BUDDY=${PLIST_BUDDY:-/usr/libexec/PlistBuddy}
PLIST=Support/Info.plist

usage() {
  cat <<'USAGE'
usage: scripts/bump-version.sh <X.Y.Z> [--date <YYYY-MM-DD>] [--changelog <path>]
  <X.Y.Z>              the new version; must be above CFBundleShortVersionString
  --date <YYYY-MM-DD>  the release date in the changelog heading (default today)
  --changelog <path>   the changelog to update (default CHANGELOG.md)
  --help               show this help
USAGE
}

fail_usage() { echo "error: $1" >&2; usage >&2; exit 2; }
need_value() { [[ $# -ge 2 && -n $2 && $2 != --* ]] || fail_usage "$1 needs a value"; }
die() { echo "error: $1" >&2; exit 1; }

version=''
date=''
changelog=CHANGELOG.md
while [[ $# -gt 0 ]]; do
  case $1 in
    --date) need_value "$@"; date=$2; shift 2 ;;
    --changelog) need_value "$@"; changelog=$2; shift 2 ;;
    --help) usage; exit 0 ;;
    -*) fail_usage "unknown option $1" ;;
    *) [[ -z $version ]] || fail_usage "give exactly one version, not also $1"; version=$1; shift ;;
  esac
done
[[ -n $version ]] || fail_usage 'give the new version X.Y.Z'
[[ $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]?)\.(0|[1-9][0-9]?)$ ]] \
  || fail_usage "the version must be X.Y.Z with MINOR and PATCH below 100, not $version"
build=$((10#${BASH_REMATCH[1]} * 10000 + 10#${BASH_REMATCH[2]} * 100 + 10#${BASH_REMATCH[3]}))
date=${date:-$(date +%Y-%m-%d)}
[[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail_usage "--date must be YYYY-MM-DD, not $date"

[[ -f $PLIST ]] || die "$PLIST not found; run this from an app repository"
[[ -f $changelog ]] || die "$changelog not found"
[[ -x scripts/release-notes.sh ]] \
  || die "scripts/release-notes.sh not found; copy it from project-release/assets beside this script"
current=$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null) \
  || die "$PLIST has no CFBundleShortVersionString"
"$PLIST_BUDDY" -c 'Print :CFBundleVersion' "$PLIST" >/dev/null 2>&1 || die "$PLIST has no CFBundleVersion"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# Checks the version order and the changelog, and writes the new changelog to the scratch copy.
python3 - "$version" "$current" "$date" "$changelog" "$scratch/changelog" <<'PY'
import re
import sys

version, current, date, changelog, output = sys.argv[1:6]


def refuse(message):
    sys.stderr.write("error: %s\n" % message)
    sys.exit(1)


def key(text):
    return tuple(int(part) for part in text.split("."))


if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", current):
    refuse("the current version %r in Support/Info.plist is not X.Y.Z" % current)
if key(version) <= key(current):
    refuse("%s is not above the current version %s; a version never goes backwards or repeats"
           % (version, current))

with open(changelog, encoding="utf-8") as handle:
    text = handle.read()
lines = text.split("\n")
VERSION_HEADING = re.compile(r"## \[([0-9]+\.[0-9]+\.[0-9]+)\]")
LINK_DEFINITION = re.compile(r"\[[^\]]+\]: ")
unreleased = [index for index, line in enumerate(lines) if line.rstrip("\r") == "## [Unreleased]"]
versions = [index for index, line in enumerate(lines) if VERSION_HEADING.match(line)]
if len(unreleased) != 1:
    refuse("%s has %d `## [Unreleased]` headings; keep exactly one" % (changelog, len(unreleased)))
start = unreleased[0]
if versions and versions[0] < start:
    refuse("%s: `## [Unreleased]` is below a version heading; it goes above every version" % changelog)
if any(VERSION_HEADING.match(lines[index]).group(1) == version for index in versions):
    refuse("%s already has a `## [%s]` heading" % (changelog, version))
notes = []
for line in lines[start + 1:]:
    if line.startswith("## ") or LINK_DEFINITION.match(line):
        break
    notes.append(line)
if not any(line.strip() for line in notes):
    refuse("%s has nothing under `## [Unreleased]`; write the notes first" % changelog)

eol = "\r" if lines[start].endswith("\r") else ""
lines[start:start + 1] = ["## [Unreleased]" + eol, eol, "## [%s] - %s%s" % (version, date, eol)]

UNRELEASED_LINK = re.compile(r"\[Unreleased\]: (?P<base>.+)/compare/(?P<prefix>v?)(?P<old>[0-9]+\.[0-9]+\.[0-9]+)\.\.\.HEAD(?P<eol>\r?)")
for index, line in enumerate(lines):
    link = UNRELEASED_LINK.fullmatch(line)
    if link:
        base, prefix, old, end = link.group("base", "prefix", "old", "eol")
        lines[index:index + 1] = [
            "[Unreleased]: %s/compare/%s%s...HEAD%s" % (base, prefix, version, end),
            "[%s]: %s/compare/%s%s...%s%s%s" % (version, base, prefix, old, prefix, version, end),
        ]
        break

with open(output, "w", encoding="utf-8", newline="") as handle:
    handle.write("\n".join(lines))
PY

cat "$scratch/changelog" >"$changelog"
"$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $version" "$PLIST"
"$PLIST_BUDDY" -c "Set :CFBundleVersion $build" "$PLIST"
scripts/release-notes.sh --check --changelog "$changelog"
echo "bumped $current -> $version (build $build), $changelog dated $date" >&2
