# Leve

Today's time and today's events at the edge of your attention, in the macOS menu bar, so deep focus
never costs you a meeting.

## Why Leve

When you hyperfocus, time disappears. Leve keeps it in view without asking for attention:

- The menu bar says **"Free until 2:00 PM"**, **"in 12 min"** or **"20 min left"**, never the
  event's name, so it is safe on a shared screen.
- A **notification** arrives a few minutes before each event.
- A calm **full-screen alert** covers every display just before an event, with a Join button, until
  you join or close it.
- Leve **says the time** on the half hour during the day, **says the next event** two minutes
  before it starts, and **stays quiet during events**.

It reads today's events only, never changes your calendars, and has no window to manage.

## Requirements

macOS 27 or later on a Mac with Apple silicon.

## Install

Leve is not distributed. Build and install it on this Mac:

```bash
make install
```

## Use it

Click the leaf in the menu bar:

- **Today** lists the events that have not ended. Open one to join its call, turn off its alerts or
  its full screen, or hide it.
- **Pause Alerts** stops notifications, the full screen and the spoken time for 30 minutes, an hour,
  or until tomorrow.
- **Take a Break Now** starts a break at once, when breaks are on.
- **Settings…** (<kbd>⌘</kbd> <kbd>,</kbd>) and **Quit Leve** (<kbd>⌘</kbd> <kbd>Q</kbd>).

In the full-screen alert, <kbd>Return</kbd> joins the call and <kbd>Esc</kbd> closes it.

### Settings

- **General:** open at login, how early the menu bar countdown starts, whether it shows "Free
  until", and the Calendar and Notifications permissions.
- **Alerts:** when the notification and the full screen arrive; how often, between which hours and
  in which voice Leve says the time; whether it says upcoming events.
- **Calendars:** for each calendar, All alerts, No full screen, No alerts, or Hidden.

## Privacy

Leve reads today's events from the calendars on this Mac and keeps its settings on this Mac. It
sends nothing anywhere.

## Limitations

- Today only: nothing about tomorrow until midnight.
- No tasks, notes or event editing.
- Cancelled invitations and events you declined are left out.

## Uninstall

```bash
make uninstall
```

Then remove Leve from System Settings ▸ General ▸ Login Items if you turned on "Open Leve at login".

## For developers

Commands and conventions are in [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`AGENTS.md`](AGENTS.md);
what Leve is and is not is in [`docs/product.md`](docs/product.md).

## License

[MIT](LICENSE) © 2026 Marton Paulo.
