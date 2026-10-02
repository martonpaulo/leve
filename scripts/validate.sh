#!/usr/bin/env bash
# Repository invariants that need no compiler: the version and build number agree, the agent
# rules fit what every client loads, and the logic target imports only Foundation.
set -euo pipefail
cd "$(dirname "$0")/.."

PLIST_BUDDY=${PLIST_BUDDY:-/usr/libexec/PlistBuddy}
failures=0
fail() { echo "error: $1" >&2; failures=$((failures + 1)); }

version=$("$PLIST_BUDDY" -c "Print :CFBundleShortVersionString" Support/Info.plist)
build=$("$PLIST_BUDDY" -c "Print :CFBundleVersion" Support/Info.plist)
IFS=. read -r v_major v_minor v_patch <<<"$version"
derived=$((10#$v_major * 10000 + 10#$v_minor * 100 + 10#$v_patch))
[[ $build == "$derived" ]] || fail "CFBundleVersion ($build) is not $derived for version $version"

agents_bytes=$(wc -c <AGENTS.md | tr -d ' ')
(( agents_bytes <= 24000 )) || fail "AGENTS.md is $agents_bytes bytes; Antigravity CLI loads at most 24000"
[[ -L CLAUDE.md && $(readlink CLAUDE.md) == AGENTS.md ]] || fail "CLAUDE.md must be a symlink to AGENTS.md"

while IFS= read -r line; do
  module=${line#import }
  [[ $module == Foundation ]] || fail "Sources/LeveKit imports $module; it may import only Foundation"
done < <(grep -rhoE '^import [A-Za-z]+' Sources/LeveKit | sort -u)

plutil -lint -s Support/Info.plist Support/Leve.entitlements || fail "a property list in Support/ is invalid"

if (( failures > 0 )); then
  echo "validate: $failures failure(s)" >&2
  exit 1
fi
echo "validate: ok" >&2
