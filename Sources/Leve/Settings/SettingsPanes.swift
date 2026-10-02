import AppKit
import LeveKit
import SwiftUI

// MARK: - General

struct GeneralPane: View {
    @Bindable var model: AppModel
    @State private var login = LoginItem()
    @State private var restoreShown = false
    @State private var quitShown = false

    var body: some View {
        @Bindable var preferences = model.preferences
        Form {
            Section {
                HStack(spacing: 12) {
                    AppIconImage(size: 32).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Copy.appName).font(.headline)
                        Text(statusLine).foregroundStyle(.secondary)
                    }
                }
                // The binding shows the status macOS reports; only a click requests a change.
                Toggle(Copy.launchAtLogin, isOn: Binding(get: { login.state == .on }, set: { login.set($0) }))
                    .disabled(login.state == .unavailable)
                loginNote
            }

            Section(Copy.menuBarSection) {
                Picker(Copy.countdown, selection: $preferences.countdownMinutes) {
                    ForEach(Preferences.countdownOptions, id: \.self) { minutes in
                        Text(Copy.minutesBefore(minutes)).tag(minutes)
                    }
                }
            }

            permissionsSection

            Section {
                HStack {
                    Button(Copy.restoreDefaultsButton) { restoreShown = true }
                        .confirmationDialog(Copy.restoreDefaultsQuestion, isPresented: $restoreShown) {
                            Button(Copy.restoreDefaults) { model.preferences.restoreDefaults() }
                            Button(Copy.cancel, role: .cancel) {}
                        } message: {
                            Text(Copy.restoreDefaultsMessage)
                        }
                    Spacer()
                    // Quitting loses no data, so the button is not destructive; the dialog says what stops.
                    Button(Copy.quitButton) { quitShown = true }
                        .confirmationDialog(Copy.quitQuestion, isPresented: $quitShown) {
                            Button(Copy.quit) { NSApp.terminate(nil) }
                            Button(Copy.cancel, role: .cancel) {}
                        } message: {
                            Text(Copy.quitMessage)
                        }
                }
            }
        }
        .settingsPane()
        // The window is kept, so re-read what System Settings may have changed whenever the pane
        // shows or Leve becomes active.
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private var statusLine: String {
        if model.isPaused, let until = model.preferences.pausedUntil {
            return Copy.pausedUntil(until)
        }
        return Copy.status(model.status)
    }

    private var permissionsSection: some View {
        Section(Copy.permissions) {
            let calendarAllowed = model.calendar.access == .granted
            LabeledContent {
                PermissionStatus(granted: calendarAllowed)
            } label: {
                Text(Copy.calendarPermission)
                Text(Copy.calendarPermissionNote)
            }
            if !calendarAllowed {
                Button(Copy.openSystemSettings) { SystemSettings.openCalendarPrivacy() }
            }
            let notificationsAllowed = model.reminders.notificationsAllowed != false
            LabeledContent {
                PermissionStatus(granted: notificationsAllowed)
            } label: {
                Text(Copy.notificationPermission)
                Text(Copy.notificationPermissionNote)
            }
            if !notificationsAllowed {
                Button(Copy.openSystemSettings) { SystemSettings.openNotifications() }
            }
        }
    }

    @ViewBuilder private var loginNote: some View {
        switch login.state {
        case .needsApproval:
            Label(Copy.loginNeedsApproval, systemImage: "exclamationmark.triangle.fill").settingsNote()
            Button(Copy.openLoginItems) { login.openSystemSettings() }
        case .unavailable:
            Label(Copy.loginUnavailable, systemImage: "info.circle").settingsNote()
        case .on, .off:
            if login.failed {
                Label(Copy.loginFailed, systemImage: "exclamationmark.triangle.fill").settingsNote()
            }
        }
    }

    private func refresh() {
        login.refresh()
        model.calendar.refreshAccess()
        Task { await model.reminders.refreshSettings() }
    }
}

// MARK: - Alerts

/// When Leve warns before an event, and what it says out loud.
struct AlertsPane: View {
    @Bindable var model: AppModel

    var body: some View {
        @Bindable var preferences = model.preferences
        Form {
            Section {
                Picker(Copy.notification, selection: $preferences.reminderLeadMinutes) {
                    Text(Copy.off).tag(Int?.none)
                    ForEach(Preferences.reminderLeadOptions, id: \.self) { minutes in
                        Text(Copy.minutesBefore(minutes)).tag(Int?.some(minutes))
                    }
                }
                Picker(Copy.fullScreen, selection: $preferences.fullScreenLeadMinutes) {
                    Text(Copy.off).tag(Int?.none)
                    ForEach(Preferences.fullScreenLeadOptions, id: \.self) { minutes in
                        Text(minutes == 0 ? Copy.atStart : Copy.minutesBefore(minutes)).tag(Int?.some(minutes))
                    }
                }
                if model.reminders.supportsUrgentDelivery == true {
                    Toggle(Copy.urgentDelivery, isOn: $preferences.urgentDelivery)
                        .disabled(preferences.reminderLeadMinutes == nil)
                }
            } header: {
                Text(Copy.alertsSection)
            } footer: {
                Text(Copy.alertsFooter).settingsNote()
            }

            speechSection(preferences)
        }
        .settingsPane()
    }

    private func speechSection(_ preferences: Preferences) -> some View {
        @Bindable var preferences = preferences
        return Section {
            Picker(Copy.speakTime, selection: $preferences.speechInterval) {
                ForEach(SpeechInterval.allCases, id: \.self) { interval in
                    Text(Copy.speechInterval(interval)).tag(interval)
                }
            }
            LabeledContent(Copy.speechHours) {
                HStack {
                    hourPicker($preferences.speechStartHour, label: Copy.speechHoursFrom)
                    Text(Copy.speechHoursTo).foregroundStyle(.secondary)
                    hourPicker($preferences.speechEndHour, label: Copy.speechHoursUntil)
                }
            }
            .disabled(preferences.speechInterval == .off)
            Picker(Copy.sayUpcoming, selection: $preferences.spokenAlertMinutes) {
                Text(Copy.off).tag(Int?.none)
                ForEach(Preferences.spokenAlertOptions, id: \.self) { minutes in
                    Text(Copy.minutesBefore(minutes)).tag(Int?.some(minutes))
                }
            }
            LabeledContent(Copy.voice) {
                HStack {
                    Picker(Copy.voice, selection: $preferences.voiceIdentifier) {
                        Text(TimeSpeaker.defaultVoiceName).tag(String?.none)
                        ForEach(TimeSpeaker.englishVoices) { voice in
                            Text(voice.name).tag(String?.some(voice.id))
                        }
                    }
                    .labelsHidden()
                    Button(Copy.preview) { model.previewSpeech() }
                }
            }
            .disabled(preferences.speechInterval == .off && preferences.spokenAlertMinutes == nil)
        } header: {
            Text(Copy.speechSection)
        } footer: {
            Text(Copy.speechFooter).settingsNote()
        }
    }

    private func hourPicker(_ hour: Binding<Int>, label: String) -> some View {
        Picker(label, selection: hour) {
            ForEach(0..<24, id: \.self) { value in
                Text(Copy.hour(value)).tag(value)
            }
        }
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel(label)
    }

}

// MARK: - Calendars

struct CalendarsPane: View {
    let model: AppModel

    /// Calendars grouped by account, in the store's order, so the account is a header.
    private var groups: [(source: String, calendars: [CalendarStore.CalendarInfo])] {
        var order: [String] = []
        var bySource: [String: [CalendarStore.CalendarInfo]] = [:]
        for calendar in model.calendar.calendars {
            if bySource[calendar.source] == nil {
                order.append(calendar.source)
            }
            bySource[calendar.source, default: []].append(calendar)
        }
        return order.map { ($0, bySource[$0] ?? []) }
    }

    var body: some View {
        Form {
            Section {
                Text(Copy.calendarsHeader).settingsNote()
                if model.calendar.calendars.isEmpty {
                    Text(Copy.noCalendars).settingsNote()
                }
            }
            ForEach(groups, id: \.source) { group in
                Section(group.source) {
                    ForEach(group.calendars) { calendar in
                        Picker(selection: ruleBinding(calendar.id)) {
                            ForEach(CalendarRule.allCases, id: \.self) { rule in
                                Text(Copy.rule(rule)).tag(rule)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                CalendarDot.image(calendar.color).accessibilityHidden(true)
                                Text(calendar.title)
                            }
                        }
                        .accessibilityLabel(calendar.title)
                    }
                }
            }
        }
        .settingsPane()
    }

    private func ruleBinding(_ id: String) -> Binding<CalendarRule> {
        Binding(get: { model.preferences.rule(for: id) }, set: { model.preferences.setRule($0, for: id) })
    }
}

// MARK: - About

struct AboutPane: View {
    @Bindable var preferences: Preferences
    private let info = Bundle.main.infoDictionary ?? [:]

    var body: some View {
        Form {
            Section {
                VStack(spacing: 3) {
                    AppIconImage(size: 64).accessibilityHidden(true)
                    Text(Copy.appName).font(.title2.weight(.semibold))
                    Text(Copy.aboutDescription)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(versionLine)
                        .settingsNote()
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            Section {
                Toggle(Copy.debugMenu, isOn: $preferences.debugMenu)
            } header: {
                Text(Copy.developer)
            } footer: {
                Text(Copy.debugFooter).settingsNote()
            }
            Section {
                Text(Copy.copyright)
                    .settingsNote()
                    .frame(maxWidth: .infinity)
            }
        }
        .settingsPane()
    }

    /// "Version 0.1.0 (100) · 3 October 2026": the build only when it differs from the version,
    /// the date only for a packaged build (version-and-release-date.md).
    private var versionLine: String {
        let version = info["CFBundleShortVersionString"] as? String ?? "–"
        let build = info["CFBundleVersion"] as? String ?? "–"
        let label = build == version ? Copy.version(version) : Copy.version(version, build: build)
        return Copy.versionLine(label, released: releaseDate)
    }

    /// Parsed and shown in UTC, so the date never shifts by a day.
    private var releaseDate: String? {
        guard let raw = info["AppReleaseDate"] as? String,
            let date = try? Date.ISO8601FormatStyle().year().month().day().parse(raw)
        else { return nil }
        return date.formatted(Date.FormatStyle(date: .long, time: .omitted, timeZone: .gmt))
    }
}

// MARK: - Shared

/// A permission as a row value: a green check when allowed, an orange warning otherwise. The words
/// carry the state, so color is never the only cue.
private struct PermissionStatus: View {
    let granted: Bool

    var body: some View {
        if granted {
            Label(Copy.allowed, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Label(Copy.notAllowed, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}

/// The app icon at `size` points. AppKit draws it at each display's scale, picking the icon file's
/// representation for that size instead of scaling the 1024 px image.
private struct AppIconImage: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: Self.icon(size: size))
            .frame(width: size, height: size)
    }

    private static func icon(size: CGFloat) -> NSImage {
        let source = NSApp.applicationIconImage ?? NSImage()
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
    }
}
