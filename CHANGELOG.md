# Changelog

Every notable change to Leve. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Leve uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-10-05

### Added

- The menu bar shows "Free until 2:00 PM", "in 12 min" or "20 min left", never an event's name.
- A notification a few minutes before each event, and a calm full-screen alert with a Join button
  just before it starts.
- Leve says the time on the half hour, says the next event two minutes before it starts, and
  stays quiet during events.
- Breaks: five minutes after 55 minutes of work, never during an event or a call.
- Breaks can pause Music, Spotify, TV and the videos in Brave, Chrome and Safari, when turned on in
  Settings, Breaks.
- One attention level per calendar: All alerts, No full screen, No alerts or Hidden.
- Automatic updates, and Check for Updates… in the menu and in Settings, About.
- A signed and notarized disk image on GitHub Releases, and a Homebrew cask:
  `brew install --cask martonpaulo/tap/leve`.
