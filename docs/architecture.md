# Leve architecture and patterns

The modules and patterns every change follows, moved from `AGENTS.md`.

- **`LeveKit`** holds every rule as pure value types and imports only Foundation:
  `MenuBarStatus`, `AlertPlanner`, `EventAttention`, `SpokenTime`, `MeetingLink`, `BreakTracker`, `OverlayDisplay`, `MediaPause`. A new rule goes
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
