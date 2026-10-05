# Leve — product definition

What Leve is, who it is for, and where it stops. The working rules are in
[`AGENTS.md`](../AGENTS.md).

## What it is

A macOS menu bar app that keeps today's time and today's events at the edge of your attention, so
deep focus never costs you a meeting.

## Who it is for

People who hyperfocus at the computer, lose track of time, and miss meetings.

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
- **No telemetry.** The only network request is Sparkle's update check against Leve's feed on
  GitHub; nothing about the person, the Mac or the calendars leaves it (#7).

## How you know it worked

The owner stops missing meetings while working, and does not open Calendar to check what is next.

## Constraints

- macOS 27 or later, Apple Silicon, built with SwiftPM (tools 6.4, macOS 27 SDK).
- Calendar access through EventKit (read-only) and notifications through UserNotifications.
- Distributed directly, like WindowHop: a Developer ID signed and notarized disk image on GitHub
  Releases, the Homebrew cask `martonpaulo/tap/leve`, and Sparkle updates (#7). The release policy
  is in [`AGENTS.md`](../AGENTS.md).

## Accepted evidence gaps

- Manual screen-reader passes are not run; the view code, reviewed in each change, is the
  accessibility evidence (martonpaulo/skill-deck#266).
- "Show notifications during Focus" appears only when macOS reports time-sensitive notifications
  as supported. A locally signed build without the time-sensitive entitlement reports them as not
  supported, so the option stays hidden.

## Decisions

The history of every product decision is in [`decisions.md`](decisions.md).
