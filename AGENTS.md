# Leve Working Agreements

## Project identity and policy

- Display name: `Leve`
- Code name: `Leve`
- Slug: `leve`
- Identifier name: `leve`
- Benefit-first description: Today's time and today's events at the edge of your attention, in the macOS menu bar, so deep focus never costs you a meeting.
- Repository: `martonpaulo/leve` (private)
- Public identifiers: bundle identifier `com.martonpaulo.leve`; executable `Leve`; app `Leve.app`.
- Landing page: None. The repository README is the only project surface.
- License: `MIT`
- Copyright: 2026 Marton Paulo
- Development language: English.
- Product copy: English only (owner, 2026-10-02). Every visible word lives in `Sources/Leve/App/Copy.swift` and goes through `String(localized:)`; the String Catalog (`Support/Localizable.xcstrings`) arrives with the first second locale.
- Branch policy: work on `main`; a branch only when the owner asks for one.
- Commit policy: commit each coherent task automatically once it is complete and `make check` passes; commit only task files.
- Push policy: push completed, validated commits straight to `origin/main`. Never force-push.
- Product versioning: SemVer `X.Y.Z` in `CFBundleShortVersionString` (`Support/Info.plist`), starting at `0.1.0`; `CFBundleVersion` is `MAJOR*10000 + MINOR*100 + PATCH`, checked by `make validate`. Versions change only when the owner asks.
- Merge policy: merge commits only, every commit of the branch preserved. Never squash.
- Commit subject: a commit made for an issue ends with `(#<issue number>)`.
- Delete branches after merge: enabled.
- Release, signing, and secret-storage policy: Not applicable: no public distribution (owner, 2026-10-02). `make install` builds `build/Leve.app` with `scripts/build-app.sh`, signs it with `DEVELOPER_ID_IDENTITY` from the untracked `.env` (ad-hoc without it), with hardened runtime and `Support/Leve.entitlements` (calendar access only), and copies it to `/Applications`. No notarization, release, tag, appcast or secret.
- Skills baseline revision: `ad4d6dc1fcc8a6d5c43a8c5a435dee50ab93f46b`
- Skills baseline applied: `2026-10-03`
- Skills baseline divergence `continuous-integration` at `ad4d6dc1fcc8a6d5c43a8c5a435dee50ab93f46b`: no Validate workflow. macOS runners spend the private repository's minutes on every push for one author; `make check` runs locally before each commit instead (owner, 2026-10-02).
- Skills baseline divergence `dependabot` at `ad4d6dc1fcc8a6d5c43a8c5a435dee50ab93f46b`: no `.github/dependabot.yml`. Leve has no package dependency and no workflow, so there is nothing to update; add it with the first dependency.
- Skills baseline divergence `canonical-scripts` at `ad4d6dc1fcc8a6d5c43a8c5a435dee50ab93f46b`: `scripts/build-app.sh` replaces the canonical `package-app.sh`, which requires Sparkle and has no entitlements option; Leve has neither updates nor distribution and needs the calendar entitlement.

Change an established identifier, license, visibility, branch, versioning, localization, landing-page or release policy only through an explicit task describing the migration and its effects.

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

For any command, process, browser action, integration, or delegated task likely to run long:

- Use the client's bounded yield, timeout, or status mechanism and wait for an observable
  condition instead of an arbitrary sleep.
- Keep the user informed at least once per minute when the client supports progress commentary.
- Distinguish slow but progressing work from a stall using new output, state changes, resource
  activity, the known duration of the current phase, or a tool-reported deadline. Elapsed time
  alone is not evidence of a stall.
- Inspect the current output and state before interrupting, retrying, or changing approach.
- Interrupt only when there is evidence of no useful progress, a deadline has expired, or the
  continued cost or risk is no longer justified.
- After an interruption, explain what state or output was preserved, diagnose the likely cause,
  and choose a narrower retry, a different tool, a smaller unit of work, or an explicit blocker.
- Never rerun the same unchanged failure, and do not add a polling service, background job, timer,
  or other infrastructure merely to satisfy this rule.
- Keep termination thresholds task-specific. Workflow-specific wait tools and user-input
  boundaries remain authoritative.

## Agent skill paths

- Product definition: `docs/product.md`
- Research notes: `docs/research/`; handoffs: `.scratch/handoffs/`; prototypes: `.scratch/prototypes/`.
  A path exists only once a workflow writes a real artifact there.

## Build and validate

Commands are in [`CONTRIBUTING.md`](CONTRIBUTING.md#commands). `make check` (build, lint, test,
validate) is the gate before every commit and takes about a minute, so it always runs in full. A
change to alerts, the menu or Settings is also checked in the installed app (`make install`):
read the menu bar item and menu through System Events, and capture Settings with
`screencapture -l`. In zsh, call `/usr/bin/log`; the shell's `log` builtin hides it.
Each break decision is logged once per change in the `breaks` category:
`/usr/bin/log show --last 1h --predicate 'subsystem == "com.martonpaulo.leve"' --style compact`.

## Architecture and patterns

- **`LeveKit`** holds every rule as pure value types and imports only Foundation:
  `MenuBarStatus`, `AlertPlanner`, `EventAttention`, `SpokenTime`, `MeetingLink`, `BreakTracker`. A new rule goes
  there with a Swift Testing test; the app target only reads the system and draws.
- **`AppModel`** is the one coordinator: a minute tick drives the menu bar text, the full-screen
  alert and the spoken time; notifications are scheduled ahead and replanned when a setting, an
  override, the pause or the calendar changes.
- **Today only.** `CalendarStore` fetches the current day; `AppModel` reloads it on the first tick
  of a new day, on wake and on a time-zone change. Nothing plans beyond today.
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

1. Check applicable instructions, Git status, and the current branch.
2. Search for the behavior, callers, tests, contracts, and nearby patterns; read only the chunks the change needs.
3. Distinguish verified facts, reasonable inferences, and unknowns, and define the source of truth before changing data or state.
4. When the project records an upstream or reference project, consult it before planning. When
   this project solves the problem differently, document the divergence and its reason.
5. Make a short plan only for complex, risky, ambiguous, or multi-file work.

## Scope, reuse, and implementation

- Keep changes scoped to the requested result: no unrelated cleanup, redesign, dependency updates, broad refactors, or future work. Preserve behavior outside the task and unrelated or uncommitted user changes.
- Reuse existing code, tokens, configuration, tests, and platform capabilities before creating new ones.
- Follow the patterns this project already repeats. When a change would break a recorded pattern or establish a new one, stop and ask first, naming the existing pattern, the proposed one, and why the existing one does not fit. Deviating is allowed; deviating silently is not.
- Prefer the smallest correct, readable, reversible solution that is cheap to operate.
- Keep one owner and one source of truth for each business rule, state, default, and copy value, outside presentation and adapter layers. Derive values instead of storing synchronized copies; model invalid states explicitly.
- Add no dependency, service, layer, cache, timer, polling or background job without a current requirement and an owner.
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
- Before creating or changing an interface, a style, or a visual asset, name what the product should communicate and how it should feel to the person using it, from the product definition and brand decisions, and judge visual and copy choices by that intent. When none is recorded, state the one you infer and ask before a consequential visual change.
- Define the layout and the loading, empty, error, disabled, and destructive states that apply. Include keyboard navigation, focus, screen-reader labels, scalable text, contrast, reduced motion, and non-color status cues in the same change.
- Accessibility evidence is automated. Manual screen-reader passes are not run; the owner accepted that gap in `docs/product.md` under `## Accepted evidence gaps` (martonpaulo/skill-deck#266), so a missing pass never blocks completion.
- Keep visible copy centralized and localized. Keep expensive work out of render paths and hot loops. Measure before claiming a performance problem.

## Code, comments, and documentation

- Write code, comments, commits, filenames, tests, configuration, and developer documentation in English; product copy follows the localization strategy. Write human-facing English in plain international English that non-native readers understand: precise verbs, no idioms, short sentences.
- Follow the existing formatter, linter, naming, layout, and architecture. Prefer clear types and simple control flow.
- Comment non-obvious constraints, linking official documentation when a workaround must stay visible.
- Update the smallest canonical documentation section when a durable contract changes; never create empty documentation.
- Record a consequential decision in the canonical document that owns the rule, with the deciding
  issue cited beside it as `Decided on #N`. No issue, wiki page or long-lived comment serves as a
  decision register. Index those decisions in a `## Decision index` section of the product definition, one row each, pointing to the rule.
- README: the recorded `Display name` is the H1. Links to the live project are allowed. The rest
  follows the `project-setup` skill's `references/public-surface-style.md`.
- Every fenced code block you create or materially edit has an explicit language identifier.
- Preserve third-party licenses and notices in `NOTICE.md`. Maintain `CHANGELOG.md` when the project has public releases.

## Durable project learning

At wrap-up, propose recording a learning only when it is verified, specific to this project, likely
to recur, and not already recorded, as the `project-setup` skill's `references/durable-learning.md`
defines. A command that failed twice for the same cause qualifies: record the cause and working form.

## Output shape

Shape every message so it can be acted on at once, including by a reader with ADHD. Adapted from
[ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT, Ayoub Ghriss).

1. **Lead with the next action.** A command, path or snippet comes first; prose follows, if at all.
2. **Number multi-step work.** One bounded action per step, the fewest steps that work.
3. **End with one concrete next action** doable in under two minutes, when anything is left open.
4. **Suppress tangents.** Finish the first thing; offer the second as a separate question.
5. **Restate the state every turn**: what is done and what is next.
6. **Give time estimates in concrete units**, never "some work".
7. **Make completed work visible**: what now works and how to see it.
8. **State errors plainly**: the cause, then the fix.
9. **Keep lists short**: grouped, most relevant first, at most five per group, none dropped.
10. **No preamble, no recap, no closing pleasantries.**

The shape gives way for an explanation the user asks for, before a destructive action (confirm
first), after repeated failures (name the doubtful assumption, ask one question), for real
ambiguity or options (one question; two to four ranked options), and for a required format such
as an attention card, an execution plan, a completion report, or machine-read output.

## User attention cards

When the user must notice and respond to a proposed follow-up, a material choice, a permission
boundary, or a blocker, use exactly one of the four attention cards below. Their templates and
full rules are in the `skd-grilling` skill's `references/attention-cards.md`. Never hide one inside a
general summary, ordinary bullet list, or vague "human review" note.

Render every visible heading, field label, explanation, option, recommendation, and reply token in
the language already used with the user. Follow a later explicit change of language.
Surround every card with a Markdown horizontal rule: a standalone `---` before its heading and
another after its final response line. The emoji supplements the descriptive heading and never
replaces it. Use one card per request, ending with an exact reply format.

A card alone ends the turn without asking: also ask through the client's structured-question
tool when it has one (`AskUserQuestion` in Claude Code). When several
decisions are pending and the client can publish interactive HTML, the decision page that
`skd-grilling` defines asks them instead.

- **Proposed issue**: an evidence-backed improvement outside the accepted scope, not already
  tracked. The card proposes backlog capture; it never authorizes creating or publishing the issue.
- **Decision needed**: materially different outcomes. Show options and tradeoffs, recommend one.
- **Approval needed**: one preferred action across a permission, publication, destructive, cost,
  privacy, or external boundary. Name the exact target, expected change, risk, reversibility, and recovery path.
- **Action needed**: work blocked by one user action. State what is blocked, why the agent cannot continue, the smallest unblocking action, and the observable condition for resumption.

## Configuration and repository hygiene

- Ignore secrets, local environments, logs, caches, and build output. Keep `.env.example` with every variable and a safe placeholder, and secrets only in the platform's secure store.
- Add CI, dependency updates, release workflows, and signing only when distribution or risk requires them.
- Workflows are `validate.yml` (`Validate`), `deploy.yml` (`Deploy`, started by Validate through `workflow_run`) and `release.yml` (`Release`); any other is a recorded exception. A Node repository's `validate` script runs exactly what CI runs. Do not add an image-optimisation bot.
- The agent rules live in `AGENTS.md`, the one real file, at most 24,000 bytes (the most Antigravity CLI loads); `CLAUDE.md` is a symlink to it. Do not create `GEMINI.md`, `.gemini/rules/agents.md`, or any other alias, and never commit `.claude/settings.local.json`.
- Change the repository `homepage` only as the `project-setup` skill's `references/github-settings.md` describes.

## Tests and validation

- Add or update focused tests for changed behavior, regressions, persistence, migrations, security, and critical accessibility, at stable seams.
- A behavioral bug fix includes a regression test proven to fail without the fix: run it against the unfixed code and see it fail before committing.
- Run the smallest relevant check while iterating. Before each commit, run the full suite and repository validation when the full suite takes about 90 seconds or less; otherwise run the suites that cover a change or list its directory, let CI run the full suite, read its result before reporting done, and require zero failures and zero warnings. Use a real integration only when local tests cannot prove the contract.
- When a change alters behavior, run the real application with its native diagnostics and observe the changed behavior. Green tests are not seeing it run.
- Never claim a check passed unless it ran. Report skips, blockers, residual risk, what was verified manually, and what remains unverified.
- A piped check reports the last command's status: `npm run lint | tail -3` exits 0 when lint fails. Run a gating check unpiped or with `set -o pipefail`. A check whose exit code you did not observe has not run.
- Local browser tests (Playwright or similar) run one project and the targeted tests while iterating (`--project=<name> -g "<pattern>"`), always pass `--workers=1`, and do not launch one while the 1-minute load average is above 8; run the full browser suite only as the final step before commit. They apply to local runs, not to CI on dedicated runners.

## Artifacts and processes

- Temporary is the default; retention is an explicit exception. Remove only temporary files the current task created, keeping deliverables and failure evidence, never pre-existing artifacts, fixtures, baselines, or logs, and never version caches, logs, coverage, or build output.
- Before ending the turn, stop every server, watcher, browser, simulator, container, worker, and other process the session started. Do not stop the user's pre-existing processes.

## Git and releases

- Follow the recorded branch, commit, push, and version policies. Check status and branch before editing and before the final report; leave unrelated changes untouched.
- Use English Conventional Commits, one per concern, ending with the issue number, never the pull request's: `feat: add the export button (#54)`.
- Merge with every commit: `gh pr merge <number> --merge --delete-branch`. Never squash.
- Read the exact payload before a commit, push, published text, or release upload. Stop on a
  credential, key, signing material, or sensitive personal value, never print it, and refuse a
  plaintext secret even on request. A published value is revoked or rotated; deleting it does not
  unpublish it. `skd-github-publishing-conventions` owns the gate.
- Never force-push. If commit or push fails, report the exact failure.
- Close an issue resolved as `completed` only with one signed closing comment on the issue that names the resolving commit, what was verified (checks, tests, manual runs), and what was not verified.
- Release or change a version only when the task and recorded policy authorize it, through `project-release`.

## Completion report

Lead with the outcome, in the output shape above, and include:

- what changed and why, and the files touched;
- validation commands and results, with warnings, skips, and remaining risks;
- what running the application verified, and what remains unverified;
- each issue closed, with the resolving commit its closing comment names;
- temporary artifacts kept or removed, commit, branch, push, and worktree status.
