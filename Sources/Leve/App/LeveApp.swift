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

        Settings {
            SettingsView(model: delegate.model)
        }
    }
}

/// Starts the model at launch, before anyone opens the menu.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await model.start() }
    }
}
