import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A blurred layer over every display, above other apps and full-screen spaces, washed with one
/// soft color. The content sits on the display with the pointer; the others only blur, so a
/// second monitor cannot keep the owner in their work. The event alert and the break share it.
@MainActor
final class FullScreenOverlay {
    private var windows: [OverlayWindow] = []

    var isVisible: Bool { windows.contains { $0.isVisible } }

    func present(_ content: some View, tint: Color, onEscape: @escaping () -> Void) {
        close()
        let primary = Self.screenWithPointer()
        for screen in NSScreen.screens {
            let window = makeWindow(on: screen)
            window.onEscape = onEscape
            let blur = Self.blurView()
            let layer = OverlayBackdrop(tint: tint) {
                if screen == primary { content }
            }
            let hosting = NSHostingView(rootView: layer)
            hosting.frame = blur.bounds
            hosting.autoresizingMask = [.width, .height]
            blur.addSubview(hosting)
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

    func close() {
        for window in windows {
            window.orderOut(nil)
        }
        windows = []
    }

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

/// The soft glow behind the content, and one gentle fade in. Reduce Motion skips the fade.
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
            .opacity(shown || reduceMotion ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { shown = true }
        }
    }
}
