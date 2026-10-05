# Task entry points: skill-deck's shared targets, plus Leve's own install targets. `make check` is
# the gate before every commit and the Validate workflow's job (AGENTS.md, "Build and validate").

.DEFAULT_GOAL := help

.PHONY: help build test lint format validate check app icon strings install uninstall run clean

# Any compiler warning fails `build` and `test`: Package.swift turns warnings into errors, and
# scripts/fail-on-warnings.sh fails on any `warning:` line that still points into a project file.
CONFIGURATION ?= debug
SWIFT_SOURCES ?= Sources Tests
# Icon Composer's renderer, run from its real path: it finds icrtool beside itself.
ICTOOL ?= $(shell xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool

# A stable signature keeps the calendar, notification and login-item permissions across rebuilds.
# Only this one variable is read from the untracked .env; the shell wins when it sets it.
DEVELOPER_ID_IDENTITY ?= $(shell sed -n 's/^DEVELOPER_ID_IDENTITY=//p' .env 2>/dev/null | tr -d '"')
export DEVELOPER_ID_IDENTITY

APP_BUNDLE := /Applications/Leve.app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# -- Shared targets ------------------------------------------------------------

help: ## List the targets
	@awk 'BEGIN {FS = ":.*## "} \
		/^# -- / {n = $$0; gsub(/(^# -- | -+$$)/, "", n); printf "\n%s\n", n} \
		/^[a-z-]+:.*## / {printf "  make %-12s %s\n", $$1, $$2} \
		END {printf "\n"}' $(MAKEFILE_LIST)

build: ## Build (CONFIGURATION=debug|release); fails on any warning in a project file
	@scripts/fail-on-warnings.sh -- swift build -c $(CONFIGURATION)

test: ## Swift Testing suites; fail on any warning
	@scripts/fail-on-warnings.sh -- swift test

lint: ## SwiftLint, then swift-format lint; read-only, fails on any finding
	@swiftlint lint --strict --quiet
	@swift format lint --strict --recursive $(SWIFT_SOURCES)

format: ## Rewrite the sources with swift-format (the only target that edits sources)
	@swift format format --in-place --recursive $(SWIFT_SOURCES)

validate: ## Repository invariants (scripts/validate.sh); no compiler, seconds
	@scripts/validate.sh

check: build lint test validate ## Everything a commit needs, stopping at the first failure

app: ## build/Leve.app, signed with DEVELOPER_ID_IDENTITY from the shell or .env, else ad-hoc
	@scripts/build-app.sh --force

# The app icon is authored as Support/AppIcon.icon; this renders its four appearances to check it.
icon: ## Render Support/AppIcon.icon's Default, Dark, Clear and Tinted appearances into artifacts/icon
	@mkdir -p artifacts/icon
	@for r in Default Dark ClearLight TintedDark; do \
		"$(ICTOOL)" Support/AppIcon.icon --export-image --output-file "artifacts/icon/$$r.png" \
			--platform macOS --rendition $$r --width 512 --height 512 --scale 1 >/dev/null; done
	@echo "Wrote artifacts/icon/{Default,Dark,ClearLight,TintedDark}.png"

# The compiler lists every String(localized:) key; the catalog keeps the English source strings.
strings: ## Refresh Support/Localizable.xcstrings from the app's String(localized:) calls
	@# A fresh scratch build, because an up-to-date build emits no strings.
	@rm -rf .build/strings .build/strings-data && mkdir -p .build/strings-data
	@swift build --product Leve --scratch-path .build/strings -Xswiftc -emit-localized-strings \
		-Xswiftc -emit-localized-strings-path -Xswiftc "$(CURDIR)/.build/strings-data"
	@xcrun xcstringstool sync Support/Localizable.xcstrings --stringsdata .build/strings-data/*.stringsdata

clean: ## Remove the SwiftPM build and build/
	swift package clean
	rm -rf .build build artifacts

# -- Leve targets --------------------------------------------------------------

# Notifications, calendar access and launch at login reach only a real bundle.
# `quit` returns before Leve exits; opening the new copy while the old one is still closing fails
# with LaunchServices error -600, so wait for the process to end (at most 5 seconds).
install: app ## Quit a running Leve, copy build/Leve.app into /Applications and open it
	@-osascript -e 'quit app "Leve"' >/dev/null 2>&1
	@for i in $$(seq 1 25); do pgrep -x Leve >/dev/null || break; sleep 0.2; done
	@rm -rf $(APP_BUNDLE)
	@ditto build/Leve.app $(APP_BUNDLE)
	@-$(LSREGISTER) -f $(APP_BUNDLE) >/dev/null 2>&1
	@open $(APP_BUNDLE)
	@printf 'Installed and opened %s\n' "$(APP_BUNDLE)"

uninstall: ## Quit Leve and remove /Applications/Leve.app
	@-osascript -e 'quit app "Leve"' >/dev/null 2>&1
	@rm -rf $(APP_BUNDLE)
	@printf 'Removed %s\n' "$(APP_BUNDLE)"

run: build ## Run the debug executable, unbundled; calendar and notifications need `make install`
	@.build/debug/Leve
