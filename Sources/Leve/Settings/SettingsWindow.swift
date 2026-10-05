import AppKit
import SwiftUI

/// The Settings window: a toolbar-style NSTabViewController hosting SwiftUI panes, as WindowHop's
/// Settings and the settings of Safari or Mail. It activates and becomes key when shown, so its
/// controls draw as active; a SwiftUI `Settings` scene in a menu bar app opened inactive and dim.
/// Each pane is as tall as its content, and the window keeps its position across launches.
final class SettingsWindowController {
    private static let frameAutosaveName = "LeveSettings"
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: SettingsTabViewController(model: model))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        // The pane decides the size; only the top edge comes from the saved frame.
        let size = window.frame.size
        if window.setFrameUsingName(Self.frameAutosaveName) {
            let saved = window.frame
            window.setFrame(
                CGRect(x: saved.minX, y: saved.maxY - size.height, width: size.width, height: size.height),
                display: false)
        } else {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)
        return window
    }
}

/// The panes, in order: General, one pane per job, About last (skd-macos-app-shell). Debug sits
/// before About and shows only while its toggle in About is on.
enum SettingsPane: String, CaseIterable {
    case general, alerts, breaks, calendars, debug, about

    func isShown(_ preferences: Preferences) -> Bool {
        self != .debug || preferences.debugMenu
    }

    var title: String {
        switch self {
        case .general: Copy.general
        case .alerts: Copy.alerts
        case .breaks: Copy.breaks
        case .calendars: Copy.calendars
        case .debug: Copy.debug
        case .about: Copy.about
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .alerts: "bell"
        case .breaks: "cup.and.saucer"
        case .calendars: "calendar"
        case .debug: "ladybug"
        case .about: "info.circle"
        }
    }

    @ViewBuilder func content(_ model: AppModel) -> some View {
        switch self {
        case .general: GeneralPane(model: model)
        case .alerts: AlertsPane(model: model)
        case .breaks: BreaksPane(model: model)
        case .calendars: CalendarsPane(model: model)
        case .debug: DebugPane(model: model)
        case .about: AboutPane(preferences: model.preferences, updates: model.updates)
        }
    }
}

/// Toolbar tabs with SF Symbols; the selected pane persists by its stable identifier.
private final class SettingsTabViewController: NSTabViewController {
    private static let selectedPaneKey = "leve.settingsPane.v1"

    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        // Instant pane switches, friendly to Reduce Motion.
        transitionOptions = []
        for pane in SettingsPane.allCases where pane.isShown(model.preferences) {
            addTabViewItem(item(for: pane))
        }
        if let saved = UserDefaults.standard.string(forKey: Self.selectedPaneKey),
            let index = tabViewItems.firstIndex(where: { $0.identifier as? String == saved })
        {
            selectedTabViewItemIndex = index
        }
        observeDebugTab()
    }

    private func item(for pane: SettingsPane) -> NSTabViewItem {
        let hosting = NSHostingController(rootView: AnyView(pane.content(model)))
        hosting.title = pane.title
        hosting.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: hosting)
        item.identifier = pane.rawValue
        item.label = pane.title
        item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
        return item
    }

    /// Adds or removes the Debug tab when its toggle changes, keeping the panes' order.
    private func observeDebugTab() {
        withObservationTracking {
            _ = model.preferences.debugMenu
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.syncDebugTab()
                self?.observeDebugTab()
            }
        }
    }

    private func syncDebugTab() {
        let shown = SettingsPane.debug.isShown(model.preferences)
        let existing = tabViewItems.first { $0.identifier as? String == SettingsPane.debug.rawValue }
        if shown, existing == nil {
            let index = tabViewItems.firstIndex { $0.identifier as? String == SettingsPane.about.rawValue }
            insertTabViewItem(item(for: .debug), at: index ?? tabViewItems.count)
        } else if !shown, let existing {
            removeTabViewItem(existing)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        if let identifier = tabViewItem?.identifier as? String {
            UserDefaults.standard.set(identifier, forKey: Self.selectedPaneKey)
        }
    }
}

extension View {
    /// One fixed width, as tall as the content, scrolling only past the display's usable height.
    func settingsPane() -> some View {
        formStyle(.grouped)
            .frame(width: 520)
            .frame(maxHeight: max((NSScreen.main?.visibleFrame.height ?? 800) - 120, 320))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Secondary, callout-sized text for footers and inline notes.
    func settingsNote() -> some View {
        font(.callout).foregroundStyle(.secondary)
    }
}
