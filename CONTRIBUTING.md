# Contributing to Leve

## Quick Start

Xcode 27 or later, SwiftLint, and the swift-format bundled with Xcode.

```bash
git clone https://github.com/martonpaulo/leve.git && cd leve && make install
```

Leve opens in the menu bar and asks for calendar and notification access once.

## Commands

| Command | What it does |
| :--- | :--- |
| `make check` | Runs build, lint, tests and the repository checks; the gate before every commit. |
| `make build` | Builds the package and fails on any warning. |
| `make test` | Runs the Swift Testing suites. |
| `make lint` | Runs SwiftLint and swift-format lint without changing files. |
| `make format` | Rewrites the sources with swift-format. |
| `make validate` | Checks the version, build number, agent rules, the logic target's imports and the changelog. |
| `make app` | Builds and signs `build/Leve.app` and its update archive; `FORCE=1` replaces them. |
| `make dmg` | Builds the branded disk image `artifacts/Leve-<version>.dmg` from `build/Leve.app`, for a local rehearsal (Node 24 or older). |
| `make keys` | Checks once per Mac that the Sparkle key in the login Keychain matches `SUPublicEDKey`. |
| `make appcast` | Adds one entry to `appcast.xml`, for a rehearsal or a recovery; the release workflow does it itself. |
| `make install` | Builds Leve, replaces `/Applications/Leve.app` and opens it. |
| `make uninstall` | Quits Leve and removes it from `/Applications`. |
| `make icon` | Renders the four appearances of `Support/AppIcon.icon` into `artifacts/icon/`, and regenerates the disk image's icon and background in `Support/`. |
| `make strings` | Refreshes `Support/Localizable.xcstrings` from the `String(localized:)` calls. |

## Secrets and variables

| Name | Where | What for |
| :--- | :--- | :--- |
| `LOCAL_SIGNING_IDENTITY` | untracked `.env` | An Apple Development identity: a stable code signature, so macOS keeps Leve's permissions across rebuilds. |
| `DEVELOPER_ID_IDENTITY` | untracked `.env`; the release workflow sets its own | The Developer ID Application identity, used when `LOCAL_SIGNING_IDENTITY` is empty; with neither, the build is ad-hoc. |
| `NOTARY_PROFILE` | the shell | The `notarytool` Keychain profile for a local notarization rehearsal; `skd-notary` by default. |
| `DEVELOPER_ID_CERT_P12`, `DEVELOPER_ID_CERT_PASSWORD` | GitHub secrets | The Developer ID Application certificate, as base64 `.p12`, and its password, for `release.yml`. |
| `NOTARY_API_KEY`, `NOTARY_API_KEY_ID`, `NOTARY_API_ISSUER_ID` | GitHub secrets | The team App Store Connect API key, for notarization in `release.yml` and `notary-check.yml`. |
| `SPARKLE_PRIVATE_KEY` | GitHub secret | The EdDSA key that signs each update archive. |
| `HOMEBREW_TAP_TOKEN` | GitHub secret, optional | A fine-grained token with Contents read and write on `martonpaulo/homebrew-tap`, so `release.yml` bumps the cask. |
