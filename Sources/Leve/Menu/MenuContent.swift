import AppKit
import LeveKit
import SwiftUI

/// The menu bar label: a small icon and one short line of text.
struct StatusLabel: View {
    let model: AppModel

    var body: some View {
        let text = Copy.status(model.status)
        // The status item draws the image and the text with no gap of its own and ignores the
        // stack's spacing, so an en space opens the room.
        HStack {
            Image(systemName: model.isPaused ? "bell.slash" : "leaf")
            if model.status != .clear {
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

/// The menu: what is happening, today's events, pause, then Settings and Quit (HIG order).
struct MenuContent: View {
    let model: AppModel

    var body: some View {
        // The events Section draws its own separators; a Divider beside it would double them.
        stateSection
        eventsSection
        pauseSection
        Divider()
        if model.preferences.debugMenu {
            debugMenu
            Divider()
        }
        Button(Copy.settings) { model.openSettings() }
            .keyboardShortcut(",")
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
            Button(override == .silenced ? Copy.alertsBackOn : Copy.alertsOffForEvent) {
                model.toggleAlerts(event)
            }
            // Offered only where a full screen would come: a calendar with All alerts.
            if rule == .everything && override != .silenced {
                Button(override == .noFullScreen ? Copy.fullScreenBackOn : Copy.noFullScreenInMenu) {
                    model.toggleFullScreen(event)
                }
            }
            Button(Copy.hideEvent) { model.hide(event) }
        } label: {
            CalendarDot.image(model.calendar.color(for: event.calendarID))
            Text(Copy.eventRow(event, override: override))
        }
    }

    private var debugMenu: some View {
        Menu(Copy.debug) {
            Button(Copy.simulateEvent) { model.simulateEvent() }
            Button(Copy.showFullScreenNow) { model.showFullScreenNow() }
            Button(Copy.sendTestNotification) { model.sendTestNotification() }
            Button(Copy.sayTimeNow) { model.previewSpeech() }
            if !model.simulatedEvents.isEmpty {
                Divider()
                Button(Copy.clearSimulated) { model.clearSimulatedEvents() }
            }
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
    }
}
