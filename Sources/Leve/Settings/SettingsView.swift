import AppKit
import LeveKit
import SwiftUI

/// Settings with toolbar tabs: General first, one pane per job, About last (menu-bar app).
struct SettingsView: View {
    private enum Pane: String {
        case general, calendars, about
    }

    let model: AppModel
    @AppStorage("leve.settingsPane.v1") private var pane = Pane.general.rawValue

    var body: some View {
        TabView(selection: $pane) {
            GeneralPane(model: model)
                .tabItem { Label(Copy.general, systemImage: "gearshape") }
                .tag(Pane.general.rawValue)
            CalendarsPane(model: model)
                .tabItem { Label(Copy.calendars, systemImage: "calendar") }
                .tag(Pane.calendars.rawValue)
            AboutPane(preferences: model.preferences)
                .tabItem { Label(Copy.about, systemImage: "info.circle") }
                .tag(Pane.about.rawValue)
        }
    }
}

private struct GeneralPane: View {
    @Bindable var model: AppModel
    @State private var login = LoginItem()
    private let voices = TimeSpeaker.availableVoices()

    var body: some View {
        @Bindable var preferences = model.preferences
        Form {
            Section {
                Toggle(Copy.launchAtLogin, isOn: Binding(get: { login.state == .on }, set: { login.set($0) }))
                    .disabled(login.state == .unavailable)
                loginStatus
            }

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
                if model.reminders.notificationsAllowed == false {
                    LabeledContent {
                        Button(Copy.openNotificationSettings) { model.reminders.openSystemSettings() }
                    } label: {
                        Text(Copy.notificationsOff).foregroundStyle(.secondary)
                    }
                }
                if model.reminders.supportsUrgentDelivery == true {
                    Toggle(Copy.urgentDelivery, isOn: $preferences.urgentDelivery)
                        .disabled(preferences.reminderLeadMinutes == nil)
                }
            } header: {
                Text(Copy.alertsSection)
            } footer: {
                Text(Copy.alertsFooter).foregroundStyle(.secondary)
            }

            Section(Copy.menuBarSection) {
                Picker(Copy.countdown, selection: $preferences.countdownMinutes) {
                    ForEach(Preferences.countdownOptions, id: \.self) { minutes in
                        Text(Copy.minutes(minutes)).tag(minutes)
                    }
                }
            }

            Section {
                Picker(Copy.speakTime, selection: $preferences.speechInterval) {
                    ForEach(SpeechInterval.allCases, id: \.self) { interval in
                        Text(Copy.speechInterval(interval)).tag(interval)
                    }
                }
                LabeledContent(Copy.speechHours) {
                    HStack {
                        hourPicker($preferences.speechStartHour)
                        Text(Copy.speechHoursTo).foregroundStyle(.secondary)
                        hourPicker($preferences.speechEndHour)
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
                            ForEach(voices) { voice in
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
                Text(Copy.speechFooter).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        // Tall enough for the rows on screen, so the pane opens without a scroll bar or a gap.
        .frame(width: 500, height: height)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func hourPicker(_ hour: Binding<Int>) -> some View {
        Picker(Copy.speechHours, selection: hour) {
            ForEach(0..<24, id: \.self) { value in
                Text(Copy.hour(value)).tag(value)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    private var height: CGFloat {
        var height: CGFloat = 590
        if model.reminders.notificationsAllowed == false { height += 52 }
        if model.reminders.supportsUrgentDelivery == true { height += 40 }
        if login.state == .needsApproval || login.state == .unavailable || login.failed { height += 40 }
        return height
    }

    private func refresh() {
        login.refresh()
        Task { await model.reminders.refreshSettings() }
    }

    @ViewBuilder private var loginStatus: some View {
        switch login.state {
        case .needsApproval:
            LabeledContent {
                Button(Copy.openLoginItems) { login.openSystemSettings() }
            } label: {
                Text(Copy.loginNeedsApproval).foregroundStyle(.secondary)
            }
        case .unavailable:
            Text(Copy.loginUnavailable).foregroundStyle(.secondary)
        case .on, .off:
            if login.failed {
                Text(Copy.loginFailed).foregroundStyle(.secondary)
            }
        }
    }
}

private struct CalendarsPane: View {
    let model: AppModel

    /// Calendars grouped by account, in the store's order, so "Google" is a header, not a row label.
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
            if model.calendar.calendars.isEmpty {
                Text(Copy.noCalendars).foregroundStyle(.secondary)
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
                                CalendarDot.image(calendar.color)
                                Text(calendar.title)
                            }
                        }
                    }
                }
            }
            Section {
            } footer: {
                Text(Copy.calendarsFooter).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 520)
    }

    private func ruleBinding(_ id: String) -> Binding<CalendarRule> {
        Binding(get: { model.preferences.rule(for: id) }, set: { model.preferences.setRule($0, for: id) })
    }
}

private struct AboutPane: View {
    @Bindable var preferences: Preferences
    private let info = Bundle.main.infoDictionary ?? [:]

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: Self.icon(side: 64))
                .accessibilityHidden(true)
            Text(Copy.appName).font(.title2.weight(.semibold))
            Text(Copy.aboutDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(versionLine)
                .font(.callout)
                .monospacedDigit()
                .padding(.top, 4)
            if let released = releaseDate {
                Text(Copy.released(released)).font(.callout).foregroundStyle(.secondary)
            }
            Text(Copy.copyright).font(.caption).foregroundStyle(.secondary)
            Toggle(Copy.debugMenu, isOn: $preferences.debugMenu)
                .toggleStyle(.checkbox)
                .font(.caption)
                .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 500)
    }

    /// "0.1.0 (100)": the build only when it differs from the version (version-and-release-date.md).
    private var versionLine: String {
        let version = info["CFBundleShortVersionString"] as? String ?? "–"
        let build = info["CFBundleVersion"] as? String ?? "–"
        return build == version ? Copy.version(version) : Copy.version(version, build: build)
    }

    /// The packaged release date, parsed and shown in UTC so it never shifts by a day.
    private var releaseDate: String? {
        guard let raw = info["AppReleaseDate"] as? String,
            let date = try? Date.ISO8601FormatStyle().year().month().day().parse(raw)
        else { return nil }
        return date.formatted(Date.FormatStyle(date: .long, time: .omitted, timeZone: .gmt))
    }

    /// AppKit draws the icon at the target size; a resized copy keeps SwiftUI from scaling the
    /// 1024 px representation (settings-architecture.md, "The app icon in a pane").
    private static func icon(side: CGFloat) -> NSImage {
        let icon = (NSApp.applicationIconImage.copy() as? NSImage) ?? NSImage()
        icon.size = NSSize(width: side, height: side)
        return icon
    }
}
