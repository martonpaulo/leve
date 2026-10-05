# Leve Working Agreements

## Project identity and policy

- Display name: `Leve`
- Code name: `Leve`
- Slug: `leve`
- Identifier name: `leve`
- Benefit-first description: Today's time and today's events at the edge of your attention, in the macOS menu bar, so deep focus never costs you a meeting.
- Repository: `martonpaulo/leve` (public since 2026-10-05, Decided on #6)
- Public identifiers: bundle identifier `com.martonpaulo.leve`; executable `Leve`; app `Leve.app`.
- Landing page: None. The repository README is the only project surface.
- License: `MIT`
- Copyright: 2026 Marton Paulo
- Development language: English.
- Product copy: English only (owner, 2026-10-02). Every visible word lives in `Sources/Leve/App/Copy.swift` and goes through `String(localized:)`; the String Catalog `Support/Localizable.xcstrings` holds the English source strings, refreshed with `make strings` after a copy change (owner, 2026-10-05).
- Branch policy: work on `main`; a branch only when the owner asks for one.
- Commit policy: commit each coherent task automatically once it is complete and `make check` passes; commit only task files.
- Push policy: push completed, validated commits straight to `origin/main`. Never force-push. One exception happened: on 2026-10-05 the owner had the history rewritten and force-pushed once, to drop the author e-mail and a personal detail before the repository went public (#6).
- Product versioning: SemVer `X.Y.Z` in `CFBundleShortVersionString` (`Support/Info.plist`), starting at `0.1.0`; `CFBundleVersion` is `MAJOR*10000 + MINOR*100 + PATCH`, checked by `make validate`. Versions change only when the owner asks.
- Merge policy: merge commits only, every commit of the branch preserved. Never squash.
- Commit subject: a commit made for an issue ends with `(#<issue number>)`, never the pull request's.
- Delete branches after merge: enabled.
- Default-branch approving review: not required under the direct-to-`main` policy. Do not add a pull-request-only protection rule without reopening that policy.
- Default-branch required status check: none. `main` has no branch protection and no ruleset, because its one author commits to it directly; `make check` gates each commit, and the `Validate` result is read after each push (owner, 2026-10-05).
- Secret protection: GitHub secret scanning and push protection enabled (owner, 2026-10-05), and private vulnerability reporting enabled for `SECURITY.md`. These are backstops, not substitutes for inspecting the exact publication payload.
- Release, signing, and secret-storage policy: Not applicable yet: no public distribution until #7 lands. `make install` builds `build/Leve.app` with `scripts/package-app.sh`, signs it with `LOCAL_SIGNING_IDENTITY`, else `DEVELOPER_ID_IDENTITY`, from the untracked `.env` (ad-hoc without either) and `Support/Leve.entitlements` (calendar access only), and copies it to `/Applications`.
- Skills baseline revision: `ad4d6dc1fcc8a6d5c43a8c5a435dee50ab93f46b`
- Skills baseline applied: `2026-10-03`
- Skills baseline divergence `dependabot` at `ecd0609ec96b53aa6f2110ac4dea987a3f023318`: no `swift` entry in `.github/dependabot.yml`. Leve has no package dependency, and Dependabot's Swift 6.3.1 fails on `swift-tools-version:6.4` (run of 2026-10-05); add the entry with the first dependency (owner, 2026-10-02; reason updated 2026-10-05).
- Skills baseline divergence `canonical-scripts` at `ad4d6dc1fcc8a6d5c43a8c5a435dee50ab93f46b`: `scripts/package-app.sh` differs from the canonical copy in two places: it signs the app with `Support/Leve.entitlements`, the calendar entitlement the hardened runtime requires, and copies `Support/PrivacyInfo.xcprivacy` into the bundle. The canonical script has neither (martonpaulo/skill-deck#518).
- Skills baseline divergence `layout` at `ecd0609ec96b53aa6f2110ac4dea987a3f023318`: no `docs/architecture.md` or `docs/design-system.md`. Leve is a small app; "Architecture and patterns" below describes its architecture, and the Feel rule its visual system (owner, 2026-10-05).

Change an identifier or policy recorded above only through an explicit task describing the migration and its effects.

## Instruction hierarchy and sources of truth

- Follow the direct task, the most specific scoped instructions, this file, then general agreements. Read applicable instructions before editing.
- Code is evidence of current behavior, `AGENTS.md` is normative for process, and an approved specification for desired behavior. Expose divergence among them; never resolve it silently.
- When two sources disagree (issues, comments, this file, the agent's memory, the owner's current instruction), a newer trusted statement is the recommended side, never the decided one. Ask the owner before acting on either side and record the answer in the newer issue; `skd-agent-context-validation` owns the precedence.
- Keep one canonical source per rule; other documents link to it.
- Do not turn analysis, research, or a read-only audit into implementation without authorization.
- The owner calls `issue-*` and `project-*` skills by name; `skd-*` skills are internal: offer one in plain words, never by name.
- Be direct and evidence-based: state assumptions, risks, tradeoffs, blockers. Ask only about a material decision you cannot discover safely; otherwise make explicit, reversible assumptions.
- Give concise progress updates during long-running work.

## Long-running operations

Long-running work follows the `project-setup` skill's `references/long-running-operations.md`. A delegation brief states its concurrency budget; without one, the delegated agent spawns no sub-agents.

## Agent skill paths

- Product definition: `docs/product.md`
- Research notes: `docs/research/`; handoffs: `.scratch/handoffs/`; prototypes: `.scratch/prototypes/`.
  A path exists only once a workflow writes a real artifact there.

## Build and validate

Commands are in [`CONTRIBUTING.md`](CONTRIBUTING.md#commands). `make check` (build, lint, test,
validate) is the gate before every commit and takes about a minute, so it always runs in full. A
change to alerts, the menu or Settings is also checked in the installed app (`make install`):
read the menu bar item and menu through System Events, and capture Settings with
`screencapture -l`. In zsh, call `/usr/bin/log`; the shell's `log` builtin hides it. Each break
decision is logged once per change in the `breaks` category of the decision log (Tests and
validation).

## Architecture and patterns

- **`LeveKit`** holds every rule as pure value types and imports only Foundation:
  `MenuBarStatus`, `AlertPlanner`, `EventAttention`, `SpokenTime`, `MeetingLink`, `BreakTracker`, `OverlayDisplay`. A new rule goes
  there with a Swift Testing test; the app target only reads the system and draws.
- **`AppModel`** is the one coordinator: a minute tick drives the menu bar text, the full-screen
  alert and the spoken time; notifications are scheduled ahead and replanned when a setting, an
  override, the pause or the calendar changes.
- **Today only.** `CalendarStore` fetches the current day, plus the timed events of tomorrow's
  first hour for their alerts only; `AppModel` reloads it on the first tick of a new day, on wake
  and on a time-zone change. The menu lists today alone.
- **Settings** have one owner, `Preferences`, with `leve.<name>.v1` keys; per-event choices live in
  `OverrideStore` and expire with their event.
- **Copy** lives only in `Copy.swift`. **Shell** surfaces follow the `skd-macos-app-shell` standard
  (menu-style `MenuBarExtra`, `SMAppService` login item).
- **Settings follow WindowHop's pattern** (`martonpaulo/windowhop`, `SettingsWindow.swift`): an
  AppKit toolbar `NSTabViewController` that activates and becomes key, panes as tall as their
  content (`settingsPane()`), notes in `settingsNote()`, a status row first, a Permissions section
  with Allowed / Not allowed, and Restore Defaults… / Quit Leve… last. A new pane or row matches it.
- **Feel:** light. Native controls, soft colors, no badges or red, one question per surface
  (`docs/product.md`, Feel).
- Smart Desk (`martonpaulo/smart-desk`) is the reference project for event logic only, never for
  its interface.

## Before editing

1. Check Git status and the current branch.
2. Search for the behavior, callers, tests, contracts, and nearby patterns; read only the chunks the change needs.
3. Distinguish verified facts, reasonable inferences, and unknowns, and define the source of truth before changing data or state.
4. When the project records an upstream or reference project, consult it before planning. When
   this project solves the problem differently, document the divergence and its reason.
5. Make a short plan only for complex, risky, ambiguous, or multi-file work.

## Scope, reuse, and implementation

- Preserve behavior outside the task and unrelated or uncommitted user changes.
- Follow the patterns this project already repeats. When a change would break a recorded pattern or establish a new one, stop and ask first, naming the existing pattern, the proposed one, and why the existing one does not fit. Deviating is allowed; deviating silently is not.
- Prefer the smallest correct, readable, reversible solution that is cheap to operate.
- Keep one owner and one source of truth for each business rule, state, default, and copy value, outside presentation and adapter layers. Derive values instead of storing synchronized copies; model invalid states explicitly.
- Deliver large changes in reviewable, executable increments. Implement errors, states, accessibility, and tests with the behavior.

## Data, security, and destructive operations

- Distinguish canonical data, reconstructible cache, transient state, and preferences. Persist or synchronize only data that must survive or cross devices; a cache never becomes a source of truth.
- Use stable application-owned identifiers, and validate data at input and persistence boundaries.
- Change a relational schema only through an explicit, tested, versioned migration, never manually in production. Use transactions or atomic writes when partial failure could leave inconsistent state.
- Request only necessary permissions and scopes. Keep credentials, keys, signing material, personal data, and sensitive payloads out of the repository and logs.
- Use structured subprocess arguments and validate destinations, redirects, and untrusted inputs.
- Resolve an exact target before deletion, overwrite, interruption, or another hard-to-recover action. A clear request authorizes its exact resolved operation; ask again when the target is ambiguous, loss is difficult to recover, or effects exceed the named scope.
- Prefer recoverable deletion. Never force-push or perform broad cleanup without explicit authorization.

## Product interface and accessibility

- Prefer native platform components and established patterns; custom UI must provide clear product value.
- Before changing an interface, a style, or a visual asset, name what the product should communicate and how it should feel, from the product definition and brand decisions, and judge visual and copy choices by that intent. When none is recorded, state the one you infer and ask before a consequential visual change.
- Define the layout and the loading, empty, error, disabled, and destructive states that apply. Include keyboard navigation, focus, screen-reader labels, scalable text, contrast, reduced motion, and non-color status cues in the same change.
- Accessibility evidence: the view code, reviewed in each change; `docs/product.md` records the accepted gap under `## Accepted evidence gaps`. Manual screen-reader passes are not run and never block completion, as the `issue-capture` skill defines (martonpaulo/skill-deck#266).
- Keep visible copy centralized and localized. Keep expensive work out of render paths and hot loops. Measure before claiming a performance problem.

## Code, comments, and documentation

- Write code, comments, commits, filenames, tests, configuration, and developer documentation in English; product copy follows the localization strategy. Write human-facing English in plain international English that non-native readers understand: precise verbs, no idioms, short sentences.
- Prefer clear types and simple control flow.
- Comment non-obvious constraints, linking official documentation when a workaround must stay visible.
- Update the smallest canonical documentation section when a durable contract changes; never create empty documentation.
- A divergence answer goes in the newer issue's Clarify. A decision that changes a durable rule rewrites the document that owns it, which keeps only the current rule with a short `#N` link, and adds one row to the `## Decision index` of `docs/decisions.md`, the only home of decision history. An ADR is the owning document only for architecture. No issue, wiki page or long-lived comment serves as a decision register.
- README: the recorded `Display name` is the H1. Links to the live project are allowed. The rest
  follows the `project-setup` skill's `references/public-surface-style.md`.
- Every fenced code block you create or materially edit has an explicit language identifier.
- Preserve third-party licenses and notices in `NOTICE.md`. Maintain `CHANGELOG.md` when the project has public releases.

## Durable project learning

At wrap-up, propose recording a learning only when it is verified, specific to this project, likely
to recur, and not already recorded, as the `project-setup` skill's `references/durable-learning.md`
defines. A command that failed twice for the same cause qualifies: record the cause and working form.
Open an issue on your own, here or in `martonpaulo/skill-deck` for a finding about Skill Deck itself,
as `skd-github-publishing-conventions` section 15 defines.

## Output shape and asking the owner

Shape every message and ask the owner as Skill Deck's global rules define (`global/AGENTS.md`, which `skd sync` links into every agent); the four kinds of request are in the `skd-grilling` skill's `references/attention-cards.md`.

## Configuration and repository hygiene

- Ignore secrets, local environments, logs, caches, and build output. Keep `.env.example` with every variable and a safe placeholder, and secrets only in the platform's secure store. Nothing new in `~` (`project-layout.md`).
- Add CI, dependency updates, release workflows, and signing only when distribution or risk requires them.
- Workflows: `validate.yml` (`Validate`, `make check` on the `xcode-27` runner, #7); the release and deploy workflows arrive with #7 and #8. A workflow added outside the `project-setup` skill's `references/ci-pipelines.md` is a recorded exception. A Node repository's `validate` script runs exactly what CI runs. Do not add an image-optimisation bot.
- The agent rules live in `AGENTS.md`, the one real file; `CLAUDE.md` is a symlink to it. Do not create `GEMINI.md`, `.gemini/rules/agents.md`, or any other alias, and never commit `.claude/settings.local.json`.
- Change the repository `homepage` only as the `project-setup` skill's `references/github-settings.md` describes.

## Tests and validation

- Add or update focused tests for changed behavior, regressions, persistence, migrations, security, and critical accessibility, at stable seams.
- Run the smallest relevant check while iterating. Before each commit, run the full suite and repository validation when the full suite takes about 90 seconds or less; otherwise run the suites that cover a change or list its directory, let CI run the full suite, read its result before reporting done, and require zero failures and zero warnings. Use a real integration only when local tests cannot prove the contract.
- When a change alters behavior, run the real application with its native diagnostics and observe the changed behavior. Green tests are not seeing it run.
- macOS app: read its decision log with `/usr/bin/log show --last 1h --predicate 'subsystem == "com.martonpaulo.leve"' --style compact`, as the `skd-macos-app-shell` skill's `references/diagnostics.md` defines.
- Report skips, blockers, residual risk, what was verified manually, and what remains unverified.
- A piped check reports the last command's status: `npm run lint | tail -3` exits 0 when lint fails. Run a gating check unpiped or with `set -o pipefail`. A check whose exit code you did not observe has not run.
- Local browser tests follow the `project-setup` skill's `references/browser-test-harness.md`.

## Artifacts and processes

- Temporary is the default; retention is an explicit exception. Remove only temporary files the current task created, keeping deliverables and failure evidence, never pre-existing artifacts, fixtures, baselines, or logs, and never version caches, logs, coverage, or build output.
- Stop only processes the session started, never the user's pre-existing ones.

## Git and releases

- Follow the recorded branch, commit, push, and version policies; leave unrelated changes untouched.
- Use English Conventional Commits, one per concern: `feat: add the export button (#54)`.
- Before a commit, push, published text or release upload, apply `skd-github-publishing-conventions` section 2.
- If commit or push fails, report the exact failure.
- Close a `completed` issue with the closing comment `skd-github-publishing-conventions` defines.
- Release or change a version only when the task and recorded policy authorize it, through `project-release`.

## Completion report

Lead with the outcome, in the output shape, and include:

- what changed and why, and the files touched;
- validation commands and results, with warnings, skips, and remaining risks;
- what running the application verified, and what remains unverified;
- each issue closed, with the resolving commit its closing comment names;
- each issue opened in the run;
- temporary artifacts kept or removed, commit, branch, push, and worktree status.
