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

Download `Leve-<version>.dmg` from the
[latest release](https://github.com/martonpaulo/leve/releases/latest), open it, and drag Leve to
Applications. The disk image is signed and notarized, and Leve updates itself.

Or install it with [Homebrew](https://brew.sh):

```bash
brew install --cask martonpaulo/tap/leve
```

If Leve is already installed from the disk image, let Homebrew manage that copy:

```bash
brew install --cask --adopt martonpaulo/tap/leve
```

Or build it from source, with Xcode 27 ([`CONTRIBUTING.md`](CONTRIBUTING.md)):

```bash
git clone https://github.com/martonpaulo/leve.git && cd leve && make install
```

## Use it

Click the leaf in the menu bar:

- **Today** lists the events that have not ended. Open one to join its call, turn off its alerts or
  its full screen, or hide it.
- **Pause Alerts** stops notifications, the full screen and the spoken time for 30 minutes, an hour,
  or until tomorrow.
- **Take a Break Now** starts a break at once, when breaks are on.
- **Check for Updates…**, **Settings…** (<kbd>⌘</kbd> <kbd>,</kbd>) and **Quit Leve**
  (<kbd>⌘</kbd> <kbd>Q</kbd>).

In the full-screen alert, <kbd>Return</kbd> joins the call and <kbd>Esc</kbd> closes it.

### Settings

- **General:** open at login, how early the menu bar countdown starts, whether it shows "Free
  until", and the Calendar and Notifications permissions.
- **Alerts:** when the notification and the full screen arrive; how often, between which hours and
  in which voice Leve says the time; whether it says upcoming events.
- **Breaks:** whether Leve asks for breaks, after how much work and for how long, the soft sound,
  and whether a break pauses Music, Spotify, TV and the videos in Brave, Chrome and Safari. With it
  off, a break that starts while sound plays offers Pause Music and Videos. When an app kept
  playing, a notification after the break opens the fix here.
- **Calendars:** for each calendar, All alerts, No full screen, No alerts, or Hidden.
- **About:** the version, and whether Leve checks for updates automatically.

## Privacy

Leve reads today's events from the calendars on this Mac and keeps its settings on this Mac. The
only thing it sends over the network is the update check: it reads Leve's update feed on GitHub,
once a day or when you choose Check for Updates…. Nothing about you, your Mac or your calendars
leaves it. Turn automatic checks off in Settings ▸ About. If you turn on pausing music and videos in
Settings ▸ Breaks, or press Pause Music and Videos in a break, Leve asks those apps on this Mac to
pause, after macOS asks you once for each. To offer that button, Leve checks whether any app plays
sound, without listening to it.

## Limitations

- Today only: nothing about tomorrow until midnight.
- No tasks, notes or event editing.
- Cancelled invitations and events you declined are left out.

## Uninstall

Quit Leve and move it from Applications to the Bin. With Homebrew, this also removes its settings:

```bash
brew uninstall --zap --cask leve
```

For a build from source, run `make uninstall`. Then remove Leve from System Settings ▸ General ▸
Login Items if you turned on "Open Leve at login".

## For developers

Commands and conventions are in [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`AGENTS.md`](AGENTS.md);
what Leve is and is not is in [`docs/product.md`](docs/product.md).

## License

[MIT](LICENSE) © 2026 Marton Paulo.
