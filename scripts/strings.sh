#!/usr/bin/env bash
# Refreshes Support/Localizable.xcstrings from the app's String(localized:) calls.
#
# The compiler lists every key (-emit-localized-strings) and xcstringstool syncs the catalog with
# them. Every entry then gets an explicit English value equal to its key, marked translated,
# because xcstringstool compiles no table for an entry without one, and the canonical
# scripts/package-app.sh refuses a catalog that compiles nothing.
#
# Never edit the catalog by hand; change Copy.swift and run `make strings`.
set -euo pipefail
cd "$(dirname "$0")/.."

catalog=Support/Localizable.xcstrings
scratch=.build/strings
data=.build/strings-data

# A fresh scratch build, because an up-to-date build emits no strings.
rm -rf "$scratch" "$data"
mkdir -p "$data"
swift build --product Leve --scratch-path "$scratch" -Xswiftc -emit-localized-strings \
  -Xswiftc -emit-localized-strings-path -Xswiftc "$PWD/$data" >&2
shopt -s nullglob
stringsdata=("$data"/*.stringsdata)
(( ${#stringsdata[@]} > 0 )) || { echo "error: the compiler wrote no stringsdata" >&2; exit 1; }
xcrun xcstringstool sync "$catalog" --stringsdata "${stringsdata[@]}"

python3 - "$catalog" <<'PY'
import json
import os
import sys
import tempfile

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    catalog = json.load(handle)
language = catalog["sourceLanguage"]
filled = 0
for key, entry in catalog["strings"].items():
    if entry.get("shouldTranslate") is False:
        continue
    unit = entry.setdefault("localizations", {}).setdefault(language, {}).setdefault("stringUnit", {})
    if unit.get("state") != "translated" or "value" not in unit:
        unit["state"] = "translated"
        unit.setdefault("value", key)
        filled += 1
# Xcode's own layout, so a later sync or an Xcode edit leaves no formatting diff.
handle = tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=os.path.dirname(path), delete=False)
with handle:
    json.dump(catalog, handle, indent=2, separators=(",", " : "), ensure_ascii=False, sort_keys=True)
os.replace(handle.name, path)
sys.stderr.write("%s: %d entries, %d given their English value\n" % (path, len(catalog["strings"]), filled))
PY
