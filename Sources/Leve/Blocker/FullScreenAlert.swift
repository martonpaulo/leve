import AppKit
import Carbon.HIToolbox
import LeveKit
import SwiftUI

/// The full-screen alert before an event: a blurred layer over the screen with the pointer, above
/// other apps and full-screen spaces, that stays until the owner joins or closes it.
final class FullScreenAlert: NSObject {
    var onJoin: ((CalendarEvent) -> Void)?
    var onClose: ((CalendarEvent) -> Void)?
    var onNeverForEvent: ((CalendarEvent) -> Void)?

    /// One window per display: the alert on the display with the pointer, a blur on the others,
    /// so a second monitor cannot keep the owner in their work.
    private var windows: [AlertWindow] = []
    private(set) var event: CalendarEvent?

    var isVisible: Bool { windows.contains { $0.isVisible } }

    func present(_ event: CalendarEvent) {
        self.event = event
        closeWindows()
        let close: () -> Void = { [weak self] in
            self?.finish { self?.onClose?(event) }
        }
        let view = FullScreenAlertView(
            event: event,
            onJoin: { [weak self] in self?.finish { self?.onJoin?(event) } },
            onClose: close,
            onNever: { [weak self] in self?.finish { self?.onNeverForEvent?(event) } }
        )
        let primary = Self.screenWithPointer()
        for screen in NSScreen.screens {
            let window = makeWindow(on: screen)
            window.onEscape = close
            let blur = Self.blurView()
            if screen == primary {
                let hosting = NSHostingView(rootView: view)
                hosting.frame = blur.bounds
                hosting.autoresizingMask = [.width, .height]
                blur.addSubview(hosting)
            }
            window.contentView = blur
            windows.append(window)
        }
        // No NSApp.activate(): macOS 14+ refuses activation the owner did not ask for. A
        // non-activating panel takes the keyboard anyway, and the owner's app stays in front.
        for window in windows {
            window.orderFrontRegardless()
        }
        let key = windows.first { $0.screen == primary } ?? windows.first
        key?.makeKeyAndOrderFront(nil)
    }

    /// Hides the alert without counting it as closed by the owner, for an event that disappeared.
    func dismissSilently() {
        closeWindows()
        event = nil
    }

    private func finish(then action: () -> Void) {
        closeWindows()
        event = nil
        action()
    }

    private func closeWindows() {
        for window in windows {
            window.orderOut(nil)
        }
        windows = []
    }

    private func makeWindow(on screen: NSScreen) -> AlertWindow {
        let window = AlertWindow(
            contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.becomesKeyOnlyIfNeeded = false
        window.hidesOnDeactivate = false
        window.setFrame(screen.frame, display: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        // Follow the active space, including another app's full-screen space:
        // https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications
        window.collectionBehavior = [.canJoinAllApplications, .moveToActiveSpace, .ignoresCycle]
        window.isMovable = false
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        return window
    }

    private static func blurView() -> NSVisualEffectView {
        let effect = NSVisualEffectView()
        effect.material = .fullScreenUI
        effect.blendingMode = .behindWindow
        effect.state = .active
        return effect
    }

    private static func screenWithPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
    }
}

/// A non-activating panel receives key events (Esc, Return) without activating Leve:
/// https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel
private final class AlertWindow: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}

private struct FullScreenAlertView: View {
    let event: CalendarEvent
    let onJoin: () -> Void
    let onClose: () -> Void
    let onNever: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text(event.calendarTitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(event.title)
                    .font(.system(size: 56, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    Text(Copy.startsIn(event, now: context.date))
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 14) {
                Button(Copy.close, action: onClose)
                    .keyboardShortcut(.cancelAction)
                if let link = event.link {
                    Button(Copy.join(link.provider), action: onJoin)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.extraLarge)
            Button(Copy.noFullScreenForEvent, action: onNever)
                .buttonStyle(.link)
                .foregroundStyle(.secondary)
        }
        .padding(64)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}
