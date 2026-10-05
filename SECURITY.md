# Security Policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting
(Security → Report a vulnerability on the repository page), or open a regular issue
if the problem is not sensitive. Reports are usually acknowledged within a week.

## Scope notes

- Leve reads your calendars through EventKit. Anything that lets an event's content
  (title, notes, location, URL) run code, open an unexpected link, or leave the Mac is in
  scope.
- Leve performs no network activity. It opens a meeting link only when you choose Join.
  Any other observed network traffic is a bug — please report it.
- The signing credentials are never stored in this repository.
