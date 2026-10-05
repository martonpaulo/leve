# Task entry points: skill-deck's shared targets, plus Leve's own install targets. `make check` is
# the gate before every commit and the Validate workflow's job (AGENTS.md, "Build and validate").

.DEFAULT_GOAL := help

.PHONY: help build test lint format validate check app dmg icon keys appcast strings install uninstall run clean

# Any compiler warning fails `build` and `test`: Package.swift turns warnings into errors, and
# scripts/fail-on-warnings.sh fails on any `warning:` line that still points into a project file.
CONFIGURATION ?= debug
SWIFT_SOURCES ?= Sources Tests
# Icon Composer's renderer, run from its real path: it finds icrtool beside itself.
ICTOOL ?= $(shell xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool

# A stable signature keeps the calendar, notification and login-item permissions across rebuilds:
# scripts/package-app.sh signs with LOCAL_SIGNING_IDENTITY, else DEVELOPER_ID_IDENTITY, from the
# untracked .env (project-setup swift-apps.md, Local signing). Make keeps the quotes of a quoted
# .env value, which codesign would read as part of the name, so they are removed.
-include .env
export
LOCAL_SIGNING_IDENTITY := $(subst ",,$(LOCAL_SIGNING_IDENTITY))
DEVELOPER_ID_IDENTITY := $(subst ",,$(DEVELOPER_ID_IDENTITY))

# FORCE=1 lets `app` and `dmg` replace their output; `install` always replaces the bundle.
FORCE ?=
FORCE_FLAG = $(if $(filter 1,$(FORCE)),--force,)

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

app: ## build/Leve.app and its update zip, signed with the identity in .env, else ad-hoc (FORCE=1 replaces)
	@scripts/package-app.sh $(FORCE_FLAG)

# The app icon is authored as Support/AppIcon.icon; this renders its four appearances to check it,
# then regenerates the disk image's art from it.
icon: ## Render the app icon's appearances to artifacts/icon; regenerate the installer icon and DMG background
	@mkdir -p artifacts/icon
	@for r in Default Dark ClearLight TintedDark; do \
		"$(ICTOOL)" Support/AppIcon.icon --export-image --output-file "artifacts/icon/$$r.png" \
			--platform macOS --rendition $$r --width 512 --height 512 --scale 1 >/dev/null; done
	@echo "Wrote artifacts/icon/{Default,Dark,ClearLight,TintedDark}.png"
	@# The disk image's art, committed: the installer icon from the Default appearance, and the
	@# background at 1x and 2x (project-setup swift-apps.md, Make targets).
	@"$(ICTOOL)" Support/AppIcon.icon --export-image --output-file artifacts/icon/AppIcon-1024.png \
		--platform macOS --rendition Default --width 1024 --height 1024 --scale 1 >/dev/null
	@scripts/render-installer-icon.swift
	@scripts/render-dmg-background.swift
	@tiffutil -cathidpicheck artifacts/dmg-bg.png artifacts/dmg-bg@2x.png \
		-out Support/LeveInstallerBackground.tiff

dmg: app ## The branded disk image artifacts/Leve-<version>.dmg from build/Leve.app (FORCE=1 replaces)
	@scripts/make-dmg.sh $(FORCE_FLAG)

keys: ## Once per machine: check the Sparkle key in the login Keychain matches SUPublicEDKey
	@scripts/make-keys.sh

# For a rehearsal or a recovery; the release workflow calls make-appcast.sh itself.
VERSION ?=
BUILD_NUMBER ?=
ARCHIVE ?=
SIGNATURE ?=
appcast: ## Add one entry to appcast.xml (VERSION, BUILD_NUMBER, ARCHIVE, SIGNATURE)
	@scripts/make-appcast.sh --version "$(VERSION)" --build-number "$(BUILD_NUMBER)" \
		--archive "$(ARCHIVE)" --signature '$(SIGNATURE)'

# The compiler lists every String(localized:) key; the catalog keeps the English source strings.
strings: ## Refresh Support/Localizable.xcstrings from the app's String(localized:) calls
	@scripts/strings.sh

clean: ## Remove the SwiftPM build and build/
	swift package clean
	rm -rf .build build artifacts

# -- Leve targets --------------------------------------------------------------

# Notifications, calendar access and launch at login reach only a real bundle.
# `quit` returns before Leve exits; opening the new copy while the old one is still closing fails
# with LaunchServices error -600, so wait for the process to end (at most 5 seconds).
install: FORCE = 1
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
