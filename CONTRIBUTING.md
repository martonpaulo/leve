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
| `make validate` | Checks the version, build number, agent rules and the logic target's imports. |
| `make app` | Builds and signs `build/Leve.app`. |
| `make install` | Builds Leve, replaces `/Applications/Leve.app` and opens it. |
| `make uninstall` | Quits Leve and removes it from `/Applications`. |
| `make icon` | Redraws `Support/AppIcon.icns` from `scripts/make-icon.swift`. |

## Secrets and variables

| Name | Where | What for |
| :--- | :--- | :--- |
| `DEVELOPER_ID_IDENTITY` | untracked `.env` or the shell | A stable code signature, so macOS keeps Leve's permissions across rebuilds; without it the build is ad-hoc. |
