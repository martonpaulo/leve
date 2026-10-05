import AppKit
import LeveKit
import SwiftUI

/// The menu bar label: a small icon and one short line of text.
struct StatusLabel: View {
    let model: AppModel

    var body: some View {
        let text = Copy.menuBarStatus(model.status)
        // The status item draws the image and the text with no gap of its own and ignores the
        // stack's spacing, so an en space opens the room.
        HStack {
            Image(systemName: model.isPaused ? "bell.slash" : "leaf")
            if model.status.showsText(freeUntil: model.preferences.showFreeUntil) {
                Text("\u{2002}" + text)
            }
        }
        .accessibilityLabel(accessibilityText(text))
    }

    /// The visible status first, then the pause, so the spoken label never hides what is shown.
    private func accessibilityText(_ text: String) -> String {
        guard model.isPaused, let until = model.preferences.pausedUntil else { return text }
        return "\(text). \(Copy.pausedUntil(until))"
    }
}

/// The menu: what is happening, today's events, pause, then the closing group: Check for Updates…,
/// Settings…, and Quit (skd-macos-app-shell, menu-architecture.md).
struct MenuContent: View {
    let model: AppModel

    var body: some View {
        // The events Section draws its own separators; a Divider beside it would double them.
        stateSection
        eventsSection
        allDaySection
        pauseSection
        Divider()
        // An unbundled build has no updater: the command is absent rather than doing nothing.
        if model.updates.isAvailable {
            Button(Copy.checkForUpdates) { model.updates.checkForUpdates() }
                .disabled(!model.updates.canCheckForUpdates)
        }
        Button(Copy.settings) { model.openSettings() }
            .keyboardShortcut(",")
        Divider()
        Button(Copy.quit) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder private var stateSection: some View {
        switch model.calendar.access {
        case .granted:
            // "Nothing else today" would repeat the empty Today section just below.
            if model.status != .clear {
                Text(Copy.status(model.status))
            }
        case .notDetermined:
            Text(Copy.calendarAccessNeeded)
            Button(Copy.allowCalendarAccess) {
                Task { await model.calendar.requestAccessIfNeeded() }
            }
        case .denied:
            Text(Copy.calendarAccessNeeded)
            Button(Copy.openPrivacySettings) { SystemSettings.openCalendarPrivacy() }
        }
        if model.isPaused, let until = model.preferences.pausedUntil {
            Text(Copy.pausedUntil(until))
        }
    }

    @ViewBuilder private var eventsSection: some View {
        Section(Copy.today) {
            let events = model.menuEvents
            if events.isEmpty {
                Text(Copy.noMoreEvents)
            }
            ForEach(events, id: \.event.id) { item in
                eventMenu(item.event)
            }
            let hidden = model.hiddenCount
            if hidden > 0 {
                Button(Copy.showHidden(hidden)) { model.overrides.unhideAll() }
            }
        }
    }

    /// All-day events below the timed ones: listed only, with no alert choices, since they never alert.
    @ViewBuilder private var allDaySection: some View {
        let events = model.allDayEvents
        if !events.isEmpty {
            Section(Copy.allDay) {
                ForEach(events, id: \.event.id) { item in
                    allDayMenu(item.event)
                }
            }
        }
    }

    private func allDayMenu(_ event: CalendarEvent) -> some View {
        Menu {
            Text(event.calendarTitle)
            if let link = event.link {
                Divider()
                Button(Copy.join(link.provider)) { model.join(event) }
            }
            Divider()
            // Dismiss hides it until the day ends, like Hide; "Show Hidden" brings it back. One word that
            // fits a task, a holiday or a birthday alike.
            Button(Copy.dismissAllDay) { model.hide(event) }
            if event.isRecurring {
                Button(Copy.dismissSeries) { model.hideSeries(event) }
            }
        } label: {
            CalendarDot.image(model.calendar.color(for: event.calendarID))
            Text(event.title)
        }
    }

    private func eventMenu(_ event: CalendarEvent) -> some View {
        let override = model.overrides.override(for: event)
        let rule = model.preferences.rule(for: event.calendarID)
        return Menu {
            Text(Copy.timeRange(event))
            Text(event.calendarTitle)
            if let link = event.link {
                Divider()
                Button(Copy.join(link.provider)) { model.join(event) }
            }
            Divider()
            // A background event (out of office, four hours or more) never alerts: nothing to turn off.
            if !event.isBackground {
                Button(override == .silenced ? Copy.alertsBackOn : Copy.alertsOffForEvent) {
                    model.toggleAlerts(event)
                }
                // Offered only where a full screen would come: a calendar with All alerts.
                if rule == .everything && override != .silenced {
                    Button(override == .noFullScreen ? Copy.fullScreenBackOn : Copy.noFullScreenInMenu) {
                        model.toggleFullScreen(event)
                    }
                }
            }
            Button(Copy.hideEvent) { model.hide(event) }
            if event.isRecurring {
                Button(Copy.hideSeries) { model.hideSeries(event) }
            }
        } label: {
            CalendarDot.image(model.calendar.color(for: event.calendarID))
            Text(Copy.eventRow(event, override: override))
        }
    }

    @ViewBuilder private var pauseSection: some View {
        if model.isPaused {
            Button(Copy.resume) { model.preferences.resume() }
        } else {
            Menu(Copy.pause) {
                Button(Copy.pauseThirtyMinutes) { model.pause(minutes: 30) }
                Button(Copy.pauseOneHour) { model.pause(minutes: 60) }
                Button(Copy.pauseUntilTomorrow) { model.pauseUntilTomorrow() }
            }
        }
        if model.preferences.breaks {
            Button(Copy.takeBreakNow) { model.takeBreakNow() }
                .disabled(model.isBreakVisible)
        }
    }
}
