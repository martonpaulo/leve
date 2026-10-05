import AppKit
import Carbon.HIToolbox
import LeveKit
import OSLog
import SwiftUI

/// A blurred layer over every display, above other apps and full-screen spaces, washed with one
/// soft color. The content sits on the display with the pointer; the others only blur, so a
/// second monitor cannot keep the owner in their work. The event alert and the break share it.
@MainActor
final class FullScreenOverlay {
    private var windows: [OverlayWindow] = []
    /// What is on screen, kept so a display change can lay it out again.
    private var shown: (content: AnyView, tint: Color, onEscape: () -> Void)?
    private var contentDisplay: UInt32?
    private var screenObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.martonpaulo.leve", category: "overlay")

    var isVisible: Bool { windows.contains { $0.isVisible } }

    func present(_ content: some View, tint: Color, onEscape: @escaping () -> Void) {
        close()
        shown = (AnyView(content), tint, onEscape)
        contentDisplay = nil
        // A resolution change or a display connected or removed would leave the windows at the
        // old frames, so the overlay is laid out again whenever the screens change (#11).
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        }
        layOut(fades: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    /// Replaces the windows at once with one per current display, the content where it was.
    private func relayout() {
        guard shown != nil, !windows.isEmpty else { return }
        for window in windows {
            window.orderOut(nil)
        }
        windows = []
        layOut(fades: false)
        logger.notice("Overlay rebuilt for \(self.windows.count, privacy: .public) displays")
    }

    private func layOut(fades: Bool) {
        guard let shown else { return }
        let screens = NSScreen.screens
        contentDisplay = OverlayDisplay.content(
            connected: screens.compactMap(Self.displayID), previous: contentDisplay,
            pointer: Self.screenWithPointer().flatMap(Self.displayID))
        let primary = screens.first { Self.displayID($0) == contentDisplay }
        for screen in screens {
            let window = makeWindow(on: screen)
            window.onEscape = shown.onEscape
            let blur = Self.blurView()
            let layer = OverlayBackdrop(tint: shown.tint) {
                if screen == primary { shown.content }
            }
            let hosting = NSHostingView(rootView: layer)
            hosting.frame = blur.bounds
            hosting.autoresizingMask = [.width, .height]
            blur.addSubview(hosting)
            window.contentView = blur
            windows.append(window)
        }
        // The blur and the glow fade in together, so the screen never changes all at once.
        // Reduce Motion shows it at once.
        // No NSApp.activate(): macOS 14+ refuses activation the owner did not ask for. A
        // non-activating panel takes the keyboard anyway, and the owner's app stays in front.
        for window in windows {
            window.alphaValue = fades ? 0 : 1
            window.orderFrontRegardless()
        }
        let key = windows.first { $0.screen == primary } ?? windows.first
        key?.makeKeyAndOrderFront(nil)
        guard fades else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeIn
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for window in windows {
                window.animator().alphaValue = 1
            }
        }
    }

    /// Fades the windows out, then removes them. A new overlay can open at once; it gets new windows.
    func close() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        shown = nil
        let closing = windows
        windows = []
        guard !closing.isEmpty else { return }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            for window in closing {
                window.orderOut(nil)
            }
            return
        }
        for window in closing {
            // The fading window must not take clicks or keys meant for the owner's app.
            window.ignoresMouseEvents = true
            window.resignKey()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeOut
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in closing {
                window.animator().alphaValue = 0
            }
        } completionHandler: {
            // AppKit calls this on the main thread.
            MainActor.assumeIsolated {
                for window in closing {
                    window.orderOut(nil)
                }
            }
        }
    }

    private static let fadeIn = 0.9
    private static let fadeOut = 0.35

    private func makeWindow(on screen: NSScreen) -> OverlayWindow {
        let window = OverlayWindow(
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

    private static func displayID(_ screen: NSScreen) -> UInt32? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    }

    private static func screenWithPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
    }
}

/// A non-activating panel receives key events (Esc, Return) without activating Leve:
/// https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel
private final class OverlayWindow: NSPanel {
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

/// The soft glow behind the content, which settles gently while the window fades in. Reduce
/// Motion keeps it still.
private struct OverlayBackdrop<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RadialGradient(
                    colors: [tint.opacity(0.32), tint.opacity(0.08), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.6
                )
                .accessibilityHidden(true)
                content
                    .scaleEffect(shown || reduceMotion ? 1 : 0.97)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { shown = true }
        }
    }
}
