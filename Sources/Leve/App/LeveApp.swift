import AppKit
import SwiftUI

@main
struct LeveApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: delegate.model)
        } label: {
            StatusLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Starts the model at launch, before anyone opens the menu, and owns the Settings window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private lazy var settings = SettingsWindowController(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.openSettings = { [weak self] in self?.settings.show() }
        model.openSettingsPane = { [weak self] pane in self?.settings.show(pane: pane) }
        model.updates.startIfBundled()
        Task { await model.start() }
    }
}
