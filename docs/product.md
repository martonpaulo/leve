# Leve — product definition

What Leve is, who it is for, and where it stops. The working rules are in
[`AGENTS.md`](../AGENTS.md).

## What it is

A macOS menu bar app that keeps today's time and today's events at the edge of your attention, so
deep focus never costs you a meeting.

## Who it is for

People who hyperfocus at the computer, lose track of time, and miss meetings. The owner is the
first of them.

## The job

Know, at a glance, whether a meeting is coming, whether one is happening, and when the next free
stretch ends; hear the time pass on the half hour; and be pulled out of the work when a meeting
starts. Today the owner relies on Smart Desk, which grew into a task manager with a sidebar,
pages, CloudKit sync and an iOS app, and whose code nobody wants to work on any more. Leve keeps
only its event alerts.

## What it does

- Shows one short line in the menu bar: "Free until 2:00 PM", "in 12 min", or "20 min left". It
  never names the event there, so a shared screen does not show it (Decided on #4); the menu does.
  A General setting leaves only the leaf when nothing is close (Decided on #10).
- Lists today's remaining events in the menu, with a Join button for Google Meet, Teams, Zoom and
  Webex links.
- Lists all-day events in their own section below, without alerts; Dismiss hides one for the day,
  and a General setting turns the section off.
- Sends a notification a few minutes before each event.
- Covers every display with a calm full-screen alert just before an event, washed in its
  calendar's color with a ring that counts down to the start, until the owner joins or closes it.
- Says the time as a clock does, "It's 10 o'clock" or "It's 10:30", with no AM or PM.
- Asks for a break after 55 minutes of work: "Stop. Breathe. Look away." for 5 minutes over a
  slowly breathing circle and a short music-box phrase, with Skip and Later (5 min). On by default, with its
  own Settings tab. Time away from the Mac counts as a break. "Take a Break Now" in the menu starts
  one at once, and it counts like the others (Decided on #9).
  Breaks never cover an event or a call (a microphone in use), but that time counts as work, so a
  break that falls due during it appears right after.
- Says the time on the half hour (or every 15 or 60 minutes) between chosen hours, 8:00 to 20:00
  by default, and stays quiet during events.
- Says the next event's name a couple of minutes before it starts ("Standup in 2 minutes"), at
  any hour.
- Lets the owner silence or hide one event, stop the full screen for one event, pause everything
  for a while, and choose how much attention each calendar gets.

## Feel

Leve must feel light: few words, few choices, native controls, soft colors, no badges and no red.
Every surface answers one question. A new option has to remove more effort than it adds.

## What it will never do

- **No tasks, notes or editing of events.** Calendar owns the events; Leve only reads them. Tasks
  are why Smart Desk became too heavy.
- **Nothing beyond today.** Leve plans today's events only; tomorrow starts at midnight. The one
  exception is the first hour after midnight, loaded so an event at 00:05 is still warned about,
  and never listed. A week view is a calendar app's job.
- **No main window.** The menu bar item and Settings are the whole interface, so there is nothing
  to keep open or arrange.
- **No sync, account or server.** Settings live on this Mac. iOS and notes may return later as a
  separate decision, not as hidden scope now.
- **No telemetry.** Nothing leaves the Mac.

## How you know it worked

The owner stops missing meetings while working, and does not open Calendar to check what is next.

## Constraints

- macOS 27 or later, Apple Silicon, built with SwiftPM (tools 6.4, macOS 27 SDK).
- Calendar access through EventKit (read-only) and notifications through UserNotifications.
- Signed locally for the owner's Mac; not distributed.

## Accepted evidence gaps

- Manual screen-reader passes are not run; accessibility evidence is automated
  (martonpaulo/skill-deck#266).
- "Show notifications during Focus" appears only when macOS reports time-sensitive notifications
  as supported. A locally signed build without the time-sensitive entitlement reports them as not
  supported, so the option stays hidden.

## Decision index

| Decision | Rule |
| :--- | :--- |
| Leve replaces Smart Desk's macOS event features in a new, small app (owner, 2026-10-02) | [What it is](#what-it-is) |
| English-only interface for now (owner, 2026-10-02) | `AGENTS.md`, Product copy |
| One "Pause Alerts" for notifications, full screen and speech, always with an end time (owner, 2026-10-02) | [What it does](#what-it-does) |
| One attention choice per calendar (owner, 2026-10-02), named All alerts, No full screen, No alerts, Hidden since 2026-10-03 | [What it does](#what-it-does) |
| The menu bar shows "Free until …" when nothing is close (owner, 2026-10-02) | [What it does](#what-it-does) |
| Everything, including the voice, is in English (owner, 2026-10-03) | `Sources/Leve/Speech/TimeSpeaker.swift` |
| Spoken warning before events, and hours for the spoken time (owner, 2026-10-03) | [What it does](#what-it-does) |
| No snooze in the full screen and no second time zone, to keep Leve light (owner, 2026-10-03) | [Feel](#feel) |
| A debug menu, off by default, simulates events without touching Calendar (owner, 2026-10-03); since 2026-10-04 a Settings tab that shows only while its toggle in About is on | `Sources/Leve/App/AppModel.swift` |
| A dot in each calendar's color marks events and calendars (owner, 2026-10-03) | `Sources/Leve/Menu/CalendarDot.swift` |
| macOS 27 minimum and the newest toolchain (owner, 2026-10-03) | [Constraints](#constraints) |
| Settings follow WindowHop's pattern, General split from Alerts (owner, 2026-10-03) | `AGENTS.md`, Architecture and patterns |
| One word per attention level: All alerts, No full screen, No alerts, Hidden; "Don't Show Full Screen" stays in the alert and joins the event's menu (owner, 2026-10-03) | `Sources/Leve/App/Copy.swift` |
| The voice says "10 o'clock" and "10:30", never AM or PM (owner, 2026-10-04) | `Sources/LeveKit/SpokenTime.swift` |
| The notification has two lines, "Standup (in 5 min)" over its time, and a dot in the calendar's color (owner, 2026-10-04) | `Sources/Leve/Alerts/ReminderScheduler.swift` |
| Breaks: on by default in their own Settings tab, a soft tone on by default, 5 minutes after 55 minutes of work, Skip and Later only, never during an event or a call, meeting time counts (owner, 2026-10-04) | [What it does](#what-it-does) |
| The full-screen alert glows in the calendar's color with a countdown ring, and every full screen fades in and out (owner, 2026-10-04) | `Sources/Leve/Blocker/FullScreenAlert.swift` |
| The voice stays quiet while a break is on screen; no setting (owner, 2026-10-04) | `Sources/Leve/App/AppModel.swift` |
| No explanation text above the calendar choices (owner, 2026-10-04) | `Sources/Leve/Settings/SettingsPanes.swift` |
| All-day events in their own menu section, never alerting, with Dismiss; on by default (owner, 2026-10-04) | [What it does](#what-it-does) |
| Tomorrow's first hour is loaded for alerts only, never listed (owner, 2026-10-04) | [What it will never do](#what-it-will-never-do) |
| Out-of-office events and events of four hours or more are background: listed, but no alerts, no menu bar countdown, and they neither quiet the voice nor hold a break (owner, 2026-10-04) | `Sources/LeveKit/CalendarEvent.swift` |
| A repeating event can be hidden for good ("Hide All Repeats", "Dismiss All Repeats"), and shown again from Settings, Calendars (owner, 2026-10-04) | `Sources/Leve/Settings/OverrideStore.swift` |
| The full screen plays the bowl tone, the break a short music-box phrase; no notification when the full screen comes at the same time (owner, 2026-10-04) | `Sources/LeveKit/AlertPlanner.swift` |
| The menu bar never shows an event's name, with no setting, replacing the planned "show title" toggle (owner, 2026-10-05, #4) | [What it does](#what-it-does) |
| "Free until …" in the menu bar can be turned off in General; "Nothing else today" is not shown there either way (owner, 2026-10-05, #10) | [What it does](#what-it-does) |
| "Take a Break Now" in the menu, while breaks are on; it restarts the work count (owner, 2026-10-05, #9) | [What it does](#what-it-does) |
