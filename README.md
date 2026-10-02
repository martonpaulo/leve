# Leve

Today's time and today's events at the edge of your attention, in the macOS menu bar, so deep focus
never costs you a meeting.

## Why Leve

When you hyperfocus, time disappears. Leve keeps it in view without asking for attention:

- The menu bar says **"Free until 2:00 PM"**, **"Standup in 12 min"** or **"Standup · 20 min left"**.
- A **notification** arrives a few minutes before each event.
- A calm **full-screen alert** covers every display just before an event, with a Join button, until
  you join or close it.
- Leve **says the time** on the half hour, and **stays quiet during events**.

It reads today's events only, never changes your calendars, and has no window to manage.

## Requirements

macOS 26 or later on a Mac with Apple silicon.

## Install

Leve is not distributed. Build and install it on this Mac:

```bash
make install
```

## Use it

Click the leaf in the menu bar:

- **Today** lists the events that have not ended. Open one to join its call, silence it, or hide it.
- **Pause Alerts** stops notifications, the full screen and the spoken time for 30 minutes, an hour,
  or until tomorrow.
- **Settings…** (<kbd>⌘</kbd> <kbd>,</kbd>) and **Quit Leve** (<kbd>⌘</kbd> <kbd>Q</kbd>).

In the full-screen alert, <kbd>Return</kbd> joins the call and <kbd>Esc</kbd> closes it.

### Settings

- **General:** open at login, when the notification and the full screen arrive, how early the
  countdown starts, how often and in which voice Leve says the time.
- **Calendars:** for each calendar, All alerts, No full screen, Menu only, or Ignore.

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
