#!/usr/bin/env bash
# Canonical release-identity check for the owner's macOS apps. Copy it unchanged to
# scripts/verify-release-identity.sh in each app; project-setup alignment reports a drifted copy.
#
# Rejects a signed app whose effective macOS identity would differ from the released one. macOS
# keys the Accessibility grant, the Keychain and UserDefaults to that identity, so a change here
# silently costs every user their permissions and data on the next update. Run it after signing
# and again on the app inside the DMG.
#
# The expected identity comes from the repository, never from this file. An expectation is a
# directory holding two fixtures (default Support/, the candidate's; --expect names another):
#   - ReleaseCertificate.cer: the leaf0 that
#       codesign -d --extract-certificates=leaf <a signed release build>
#     writes; its CN is the signing authority, its OU the team and its issuer the Apple authority;
#   - ExpectedDesignatedRequirement.txt: the text after `designated => ` in
#       codesign -dr - <a signed release build>
# The identifier and executable are CFBundleIdentifier and CFBundleExecutable in Support/Info.plist.
#
# Checks, in order, for each app: arm64 only; a strict deep verification; the identifier, team,
# authority, hardened runtime and secure timestamp; the stable empty entitlement set; the
# designated requirement; the leaf certificate's issuer; the leaf byte for byte; and every nested
# Mach-O verified and signed by the same team. The candidate's certificate must not have expired,
# and one expiring within --warn-days prints a renewal warning.
#
# Certificate rotation (#462). Apple renews a Developer ID leaf certificate on its own schedule, and
# from 2026-10-01 a replacement comes from the Developer ID G2 Sub-CA, whose display name is the
# original authority's (`Developer ID Certification Authority`) and whose OU is `G2`. What macOS
# keeps an app's grants by is the designated requirement, which names the identifier, the Apple
# anchor, the Developer ID marker fields and the team, never the leaf. The byte comparison of the
# leaf is this repository's extra pin against an unexpected certificate, not an Apple rule that a
# certificate never changes. A renewal therefore records the new leaf in Support/, keeps the
# retired fixtures in a versioned directory such as Support/ReleaseIdentity/<last version>/, and
# runs the continuity check:
#   --previous <Previous.app> --previous-expect Support/ReleaseIdentity/<last version>
# The previous release is checked against the identity it was signed with, the candidate against
# the new one, and then the two are compared: the same team and designated requirement, and the
# candidate satisfies the previous release's requirement under `codesign --verify -R`. The
# previous certificate may have expired: a timestamped, notarized release keeps working.
#
# Leve's copy differs from the canonical script in one place (AGENTS.md, divergence
# `canonical-scripts`; martonpaulo/skill-deck#518): when Support/<Executable>.entitlements exists,
# the app's entitlements must equal that file instead of the empty set.
#
# Prints one `release identity: ok` line on stdout and everything else on stderr.
set -euo pipefail
cd "$(dirname "$0")/.."

PLIST_BUDDY=${PLIST_BUDDY:-/usr/libexec/PlistBuddy}
PLIST=Support/Info.plist
CERTIFICATE_NAME=ReleaseCertificate.cer
REQUIREMENT_NAME=ExpectedDesignatedRequirement.txt

usage() {
  cat <<'USAGE'
usage: scripts/verify-release-identity.sh [--app <App.app>] [--team <TEAMID>] [--expect <dir>]
                                          [--previous <App.app> [--previous-expect <dir>]]
                                          [--warn-days <days>]
  --app <App.app>          the signed candidate to check (default build/<Name>.app)
  --team <TEAMID>          the expected team; must equal the certificate's (default: the certificate's OU)
  --expect <dir>           the candidate's expectation: ReleaseCertificate.cer and
                           ExpectedDesignatedRequirement.txt (default Support)
  --previous <App.app>     the previous release; it is checked too, then compared with the candidate
  --previous-expect <dir>  the expectation the previous release was signed with
                           (default: the candidate's, which holds until a certificate rotation)
  --warn-days <days>       warn when the candidate's certificate expires within this many days (default 60)
  --help                   show this help
To record the fixtures from a signed release build:
  codesign -d --extract-certificates=leaf <App.app>   then commit leaf0 as Support/ReleaseCertificate.cer
  codesign -dr - <App.app>                            then commit the text after `designated => `
                                                      as Support/ExpectedDesignatedRequirement.txt
On a certificate renewal, first move both files to Support/ReleaseIdentity/<last version>/.
USAGE
}

fail_usage() { echo "error: $1" >&2; usage >&2; exit 2; }
need_value() { [[ $# -ge 2 && -n $2 && $2 != --* ]] || fail_usage "$1 needs a value"; }
role=''
fail() { echo "Identity validation failed: ${role:+$role: }$1" >&2; exit 1; }

app=''
team=''
expect=Support
previous=''
previous_expect=''
warn_days=60
while [[ $# -gt 0 ]]; do
  case $1 in
    --app) need_value "$@"; app=$2; shift 2 ;;
    --team) need_value "$@"; team=$2; shift 2 ;;
    --expect) need_value "$@"; expect=${2%/}; shift 2 ;;
    --previous) need_value "$@"; previous=$2; shift 2 ;;
    --previous-expect) need_value "$@"; previous_expect=${2%/}; shift 2 ;;
    --warn-days) need_value "$@"; warn_days=$2; shift 2 ;;
    --help) usage; exit 0 ;;
    *) fail_usage "unknown option $1" ;;
  esac
done
team_shape='^[A-Z0-9]{10}$'
[[ -z $team || $team =~ $team_shape ]] || fail_usage "--team must be ten capital letters or digits, not $team"
[[ $warn_days =~ ^[0-9]+$ ]] || fail_usage "--warn-days must be a whole number of days, not $warn_days"
[[ -z $previous_expect || -n $previous ]] || fail_usage "--previous-expect needs --previous"
previous_expect=${previous_expect:-$expect}

[[ -f $PLIST ]] || fail "$PLIST not found; run this from an app repository"
read_key() { "$PLIST_BUDDY" -c "Print :$1" "$PLIST" 2>/dev/null || fail "$PLIST has no $1"; }
name=$(read_key CFBundleName)
identifier=$(read_key CFBundleIdentifier)
executable=$(read_key CFBundleExecutable)
app=${app:-build/$name.app}
ENTITLEMENTS=Support/$executable.entitlements

# Reads an expectation directory into expected_* variables, before any codesign call.
read_expectation() { # $1 app, $2 expectation directory
  local certificate=$2/$CERTIFICATE_NAME requirement=$2/$REQUIREMENT_NAME subject line
  [[ -d $1 ]] || fail "app not found: $1"
  [[ -f $1/Contents/MacOS/$executable ]] || fail "main executable not found: $1/Contents/MacOS/$executable"
  [[ -f $certificate ]] || fail "$certificate not found; see --help to record it"
  [[ -s $requirement ]] || fail "$requirement is missing or empty; see --help to record it"
  expected_certificate=$certificate
  expected_requirement=$(tr -d '\n' <"$requirement")
  # One CN= and one OU= line, the same under LibreSSL and OpenSSL with this -nameopt.
  subject=$(openssl x509 -inform DER -in "$certificate" -noout -subject -nameopt sep_multiline,utf8,-esc_msb) \
    || fail "$certificate is not a DER certificate"
  expected_issuer=$(openssl x509 -inform DER -in "$certificate" -noout -issuer) \
    || fail "$certificate is not a DER certificate"
  expected_authority=''
  expected_team=''
  while IFS= read -r line; do
    line=${line#"${line%%[![:space:]]*}"}
    case $line in
      CN=*) expected_authority=${line#CN=} ;;
      OU=*) expected_team=${line#OU=} ;;
    esac
  done <<<"$subject"
  [[ $expected_authority == 'Developer ID Application: '* ]] \
    || fail "$certificate is not a Developer ID Application certificate (CN is '$expected_authority')"
  [[ -n $expected_team ]] || fail "$certificate names no team (no OU)"
}

# Checks one signed app against the expected_* values; sets actual_requirement and leaf_issuer.
verify_app() { # $1 app
  local target=$1 archs signature runtime=0 line entitlements requirement_output description \
    nested nested_signature certificates
  # Apple silicon only: the main executable carries exactly one arm64 slice.
  archs=$(lipo -archs "$target/Contents/MacOS/$executable") || fail "lipo could not read the main executable"
  [[ $archs == arm64 ]] || fail "the main executable must be arm64 only, found: $archs"

  codesign --verify --deep --strict --verbose=2 "$target" >&2 || fail "the deep strict verification failed"

  signature=$(codesign -dvvv "$target" 2>&1) || fail "codesign could not display the signature"
  grep -Fqx "Identifier=$identifier" <<<"$signature" || fail "the signing identifier is not $identifier"
  grep -Fqx "TeamIdentifier=$expected_team" <<<"$signature" || fail "the TeamIdentifier is not $expected_team"
  grep -Fqx "Authority=$expected_authority" <<<"$signature" || fail "the authority $expected_authority is absent"
  while IFS= read -r line; do
    [[ $line == *flags=*runtime* ]] && runtime=1
  done <<<"$signature"
  (( runtime )) || fail "the hardened runtime is absent"
  # `Signed Time` instead of `Timestamp` is a signature without a secure timestamp.
  grep -q '^Timestamp=' <<<"$signature" || fail "the signature has no secure timestamp"

  if [[ -f $ENTITLEMENTS ]]; then
    # Both sides through plutil, so the comparison ignores the XML layout.
    entitlements=$(codesign -d --entitlements - --xml "$target" 2>/dev/null) || fail "codesign could not read the entitlements"
    actual_entitlements=$(plutil -convert json -o - - <<<"$entitlements" 2>/dev/null) \
      || fail "the entitlements are not a property list"
    wanted_entitlements=$(plutil -convert json -o - "$ENTITLEMENTS") || fail "$ENTITLEMENTS is not a property list"
    [[ $actual_entitlements == "$wanted_entitlements" ]] || fail "the entitlements differ from $ENTITLEMENTS"
  else
    entitlements=$(codesign -d --entitlements - "$target" 2>/dev/null) || fail "codesign could not read the entitlements"
    [[ -z ${entitlements//[[:space:]]/} ]] || fail "the entitlements changed from the stable empty set"
  fi

  requirement_output=$(codesign -dr - "$target" 2>/dev/null) || fail "codesign could not read the designated requirement"
  actual_requirement=''
  while IFS= read -r line; do
    case $line in 'designated => '*) actual_requirement=${line#'designated => '} ;; esac
  done <<<"$requirement_output"
  if [[ $actual_requirement != "$expected_requirement" ]]; then
    echo "expected: $expected_requirement" >&2
    echo "actual:   $actual_requirement" >&2
    fail "the designated requirement changed"
  fi

  certificates=$scratch/$((++extractions))
  mkdir "$certificates"
  codesign -d --extract-certificates="$certificates/leaf" "$target" 2>/dev/null \
    || fail "codesign could not extract the certificates"
  # The display name cannot tell the original authority from G2; the issuer's OU can.
  leaf_issuer=$(openssl x509 -inform DER -in "$certificates/leaf0" -noout -issuer 2>/dev/null) \
    || fail "the extracted leaf certificate is not readable"
  [[ $leaf_issuer == "$expected_issuer" ]] \
    || fail "the leaf certificate was issued by '${leaf_issuer#issuer=}', not '${expected_issuer#issuer=}' as $expected_certificate records"
  cmp -s "$expected_certificate" "$certificates/leaf0" || fail "the leaf certificate differs from $expected_certificate"

  while IFS= read -r nested; do
    description=$(file "$nested") || fail "file could not read $nested"
    [[ $description == *Mach-O* ]] || continue
    codesign --verify --strict "$nested" >&2 || fail "nested code fails verification: $nested"
    nested_signature=$(codesign -dvvv "$nested" 2>&1) || fail "codesign could not display $nested"
    grep -Fqx "TeamIdentifier=$expected_team" <<<"$nested_signature" || fail "nested code uses another team: $nested"
  done < <(find "$target/Contents" -type f -perm -111 -print)
}

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
extractions=0

# Every precondition of both apps is checked before the first codesign call.
if [[ -n $previous ]]; then
  role='previous release'
  read_expectation "$previous" "$previous_expect"
  previous_team=$expected_team
  previous_expected_requirement=$expected_requirement
  role=''
fi
read_expectation "$app" "$expect"
if [[ -n $team && $team != "$expected_team" ]]; then
  fail "--team is $team, but $expected_certificate belongs to team $expected_team"
fi
team=$expected_team
openssl x509 -inform DER -in "$expected_certificate" -noout -checkend 0 >/dev/null \
  || fail "$expected_certificate has expired; renew the Developer ID certificate"
if ! openssl x509 -inform DER -in "$expected_certificate" -noout -checkend $((10#$warn_days * 86400)) >/dev/null; then
  echo "warning: $expected_certificate expires within $warn_days days" \
    "($(openssl x509 -inform DER -in "$expected_certificate" -noout -enddate)); plan the renewal" >&2
fi
if [[ -n $previous && $previous_team != "$team" ]]; then
  fail "the team changed across the transition: previous $previous_team, candidate $team"
fi

verify_app "$app"
candidate_issuer=$leaf_issuer
candidate_requirement=$actual_requirement

if [[ -z $previous ]]; then
  echo "release identity: ok ($identifier, team $team, stable certificate and requirement)"
  exit 0
fi

role='previous release'
read_expectation "$previous" "$previous_expect"
verify_app "$previous"
role=''
echo "previous leaf ${leaf_issuer}" >&2
echo "candidate leaf ${candidate_issuer}" >&2
if [[ $previous_expected_requirement != "$candidate_requirement" ]]; then
  echo "previous:  $previous_expected_requirement" >&2
  echo "candidate: $candidate_requirement" >&2
  fail "the designated requirement changed across the transition"
fi
codesign --verify -R "=$actual_requirement" "$app" >&2 \
  || fail "the candidate does not satisfy the previous release's designated requirement"

echo "release identity: ok ($identifier, team $team, continuity from $previous kept)"
