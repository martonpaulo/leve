# Leve — decisions

The history of Leve's product decisions, one row per decision. Each rule lives in the document
the last column names; this file only records when and why it changed. The product definition is
[`product.md`](product.md).

## Decision index

| Date | Issue | What changed | What it replaced | Where the rule lives now |
| :--- | :--- | :--- | :--- | :--- |
| 2026-10-02 | — | Leve replaces Smart Desk's macOS event features in a new, small app | — | [`product.md`, What it is](product.md#what-it-is) |
| 2026-10-02 | — | English-only interface for now | — | [`AGENTS.md`](../AGENTS.md), Product copy |
| 2026-10-02 | — | One "Pause Alerts" for notifications, full screen and speech, always with an end time | — | [`product.md`, What it does](product.md#what-it-does) |
| 2026-10-02 | — | One attention choice per calendar, named All alerts, No full screen, No alerts, Hidden since 2026-10-03 | the first names of the four choices (2026-10-02) | [`product.md`, What it does](product.md#what-it-does) |
| 2026-10-02 | — | The menu bar shows "Free until …" when nothing is close | — | [`product.md`, What it does](product.md#what-it-does) |
| 2026-10-03 | — | Everything, including the voice, is in English | — | [`TimeSpeaker.swift`](../Sources/Leve/Speech/TimeSpeaker.swift) |
| 2026-10-03 | — | Spoken warning before events, and hours for the spoken time | — | [`product.md`, What it does](product.md#what-it-does) |
| 2026-10-03 | — | No snooze in the full screen and no second time zone, to keep Leve light | — | [`product.md`, Feel](product.md#feel) |
| 2026-10-03 | — | A debug menu, off by default, simulates events without touching Calendar; since 2026-10-04 a Settings tab that shows only while its toggle in About is on | the debug menu, by a Settings tab (2026-10-04) | [`AppModel.swift`](../Sources/Leve/App/AppModel.swift) |
| 2026-10-03 | — | A dot in each calendar's color marks events and calendars | — | [`CalendarDot.swift`](../Sources/Leve/Menu/CalendarDot.swift) |
| 2026-10-03 | — | macOS 27 minimum and the newest toolchain | — | [`product.md`, Constraints](product.md#constraints) |
| 2026-10-03 | — | Settings follow WindowHop's pattern, General split from Alerts | — | [`AGENTS.md`](../AGENTS.md), Architecture and patterns |
| 2026-10-03 | — | One word per attention level: All alerts, No full screen, No alerts, Hidden; "Don't Show Full Screen" stays in the alert and joins the event's menu | the earlier attention-level names | [`Copy.swift`](../Sources/Leve/App/Copy.swift) |
| 2026-10-04 | — | The voice says "10 o'clock" and "10:30", never AM or PM | — | [`SpokenTime.swift`](../Sources/LeveKit/SpokenTime.swift) |
| 2026-10-04 | — | The notification has two lines, "Standup (in 5 min)" over its time, and a dot in the calendar's color | — | [`ReminderScheduler.swift`](../Sources/Leve/Alerts/ReminderScheduler.swift) |
| 2026-10-04 | — | Breaks: on by default in their own Settings tab, a soft tone on by default, 5 minutes after 55 minutes of work, Skip and Later only, never during an event or a call, meeting time counts | — | [`product.md`, What it does](product.md#what-it-does) |
| 2026-10-04 | — | The full-screen alert glows in the calendar's color with a countdown ring, and every full screen fades in and out | — | [`FullScreenAlert.swift`](../Sources/Leve/Blocker/FullScreenAlert.swift) |
| 2026-10-04 | — | The voice stays quiet while a break is on screen; no setting | — | [`AppModel.swift`](../Sources/Leve/App/AppModel.swift) |
| 2026-10-04 | — | No explanation text above the calendar choices | — | [`SettingsPanes.swift`](../Sources/Leve/Settings/SettingsPanes.swift) |
| 2026-10-04 | — | All-day events in their own menu section, never alerting, with Dismiss; on by default | — | [`product.md`, What it does](product.md#what-it-does) |
| 2026-10-04 | — | Tomorrow's first hour is loaded for alerts only, never listed | — | [`product.md`, What it will never do](product.md#what-it-will-never-do) |
| 2026-10-04 | — | Out-of-office events and events of four hours or more are background: listed, but no alerts, no menu bar countdown, and they neither quiet the voice nor hold a break | — | [`CalendarEvent.swift`](../Sources/LeveKit/CalendarEvent.swift) |
| 2026-10-04 | — | A repeating event can be hidden for good ("Hide All Repeats", "Dismiss All Repeats"), and shown again from Settings, Calendars | — | [`OverrideStore.swift`](../Sources/Leve/Settings/OverrideStore.swift) |
| 2026-10-04 | — | The full screen plays the bowl tone, the break a short music-box phrase; no notification when the full screen comes at the same time | — | [`AlertPlanner.swift`](../Sources/LeveKit/AlertPlanner.swift) |
| 2026-10-05 | #4 | The menu bar never shows an event's name, with no setting, replacing the planned "show title" toggle | the planned "show title" toggle | [`product.md`, What it does](product.md#what-it-does) |
| 2026-10-05 | #10 | "Free until …" in the menu bar can be turned off in General; "Nothing else today" is not shown there either way | — | [`product.md`, What it does](product.md#what-it-does) |
| 2026-10-05 | #9 | "Take a Break Now" in the menu, while breaks are on; it restarts the work count | — | [`product.md`, What it does](product.md#what-it-does) |
| 2026-10-05 | #7 | Distributed like WindowHop: a signed, notarized disk image from a tag-run release workflow, the Homebrew cask `martonpaulo/tap/leve`, and Sparkle updates, the only network request | signed locally for the owner's Mac, not distributed, nothing sent anywhere | [`product.md`, Constraints](product.md#constraints); [`AGENTS.md`](../AGENTS.md), release policy |
