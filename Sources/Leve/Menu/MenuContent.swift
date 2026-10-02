import AppKit
import LeveKit
import SwiftUI

/// The menu bar label: a small icon and one short line of text.
struct StatusLabel: View {
    let model: AppModel

    var body: some View {
        let text = Copy.status(model.status, now: model.now)
        // The status item draws the image and the text with no gap of its own and ignores the
        // stack's spacing, so an en space opens the room.
        HStack {
            Image(systemName: model.isPaused ? "bell.slash" : "leaf")
            if model.status != .clear {
                Text("\u{2002}" + text)
            }
        }
        .accessibilityLabel(model.isPaused ? Copy.pausedUntil(model.preferences.pausedUntil ?? .now) : text)
    }
}

/// The menu: what is happening, today's events, pause, then Settings and Quit (HIG order).
struct MenuContent: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

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
        Button(Copy.settings) {
            // An accessory app activates first, or Settings opens behind the frontmost app.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button(Copy.quit) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder private var stateSection: some View {
        switch model.calendar.access {
        case .granted:
            Text(Copy.status(model.status, now: model.now))
        case .notDetermined:
            Text(Copy.calendarAccessNeeded)
            Button(Copy.allowCalendarAccess) {
                Task { await model.calendar.requestAccessIfNeeded() }
            }
        case .denied:
            Text(Copy.calendarAccessNeeded)
            Button(Copy.openPrivacySettings) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
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
            if model.hiddenCount > 0 {
                Button(Copy.showHidden(model.hiddenCount)) { model.overrides.unhideAll() }
            }
        }
    }

    private func eventMenu(_ event: CalendarEvent) -> some View {
        let isSilenced = model.overrides.override(for: event.id) == .silenced
        return Menu {
            Text(Copy.timeRange(event))
            Text(event.calendarTitle)
            if let link = event.link {
                Divider()
                Button(Copy.join(link.provider)) { model.join(event) }
            }
            Divider()
            Button(isSilenced ? Copy.unsilenceEvent : Copy.silenceEvent) { model.toggleSilence(event) }
            Button(Copy.hideEvent) { model.hide(event) }
        } label: {
            CalendarDot.image(color(for: event))
            Text(Copy.eventRow(event, silenced: isSilenced))
        }
    }

    private func color(for event: CalendarEvent) -> NSColor {
        event.calendarID == AppModel.debugCalendarID ? .systemGray : model.calendar.color(for: event.calendarID)
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
