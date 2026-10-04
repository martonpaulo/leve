import AppKit
import SwiftUI

/// The break: "Stop. Breathe. Look away." over a slowly breathing circle, with the time left. It
/// closes by itself when the time is up, or with Skip (Esc) or Later.
final class BreakScreen {
    var onDone: (() -> Void)?
    var onSkip: (() -> Void)?
    var onLater: (() -> Void)?

    private let overlay = FullScreenOverlay()
    private var endTask: Task<Void, Never>?

    var isVisible: Bool { overlay.isVisible }

    func present(minutes: Int, laterMinutes: Int, sound: Bool) {
        let end = Date.now.addingTimeInterval(Double(minutes * 60))
        let skip: () -> Void = { [weak self] in self?.finish { self?.onSkip?() } }
        let view = BreakView(
            end: end,
            minutes: minutes,
            laterMinutes: laterMinutes,
            onSkip: skip,
            onLater: { [weak self] in self?.finish { self?.onLater?() } }
        )
        overlay.present(view, tint: BreakView.tint, onEscape: skip)
        if sound {
            BreakSound.play(volume: 0.35)
        }
        endTask?.cancel()
        endTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(end.timeIntervalSinceNow))
            guard !Task.isCancelled else { return }
            // The same tone, softer, says the break is over to someone who looked away.
            if sound {
                BreakSound.play(volume: 0.2)
            }
            self?.finish { self?.onDone?() }
        }
    }

    /// Hides the break without counting it, when an event's alert takes the screen.
    func dismissSilently() {
        endTask?.cancel()
        overlay.close()
    }

    private func finish(then action: () -> Void) {
        endTask?.cancel()
        overlay.close()
        action()
    }
}

private struct BreakView: View {
    static let tint = Color.teal

    let end: Date
    let minutes: Int
    let laterMinutes: Int
    let onSkip: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 36) {
            BreathingCircle(end: end, tint: Self.tint)
            VStack(spacing: 12) {
                Text(Copy.breakTitle)
                    .font(.system(size: 52, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text(Copy.breakBack(minutes))
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                Button(Copy.breakSkip, action: onSkip)
                    .keyboardShortcut(.cancelAction)
                Button(Copy.breakLater(laterMinutes), action: onLater)
            }
            .controlSize(.extraLarge)
        }
        .padding(64)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// A soft circle that grows for four seconds and shrinks for four, a slow breath to follow, with
/// the time left inside. Reduce Motion keeps it still.
private struct BreathingCircle: View {
    let end: Date
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhale = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.22))
                .scaleEffect(inhale || reduceMotion ? 1 : 0.72)
                .accessibilityHidden(true)
            Circle()
                .stroke(tint.opacity(0.5), lineWidth: 2)
                .accessibilityHidden(true)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = max(0, end.timeIntervalSince(context.date))
                Text(Copy.clock(seconds: left))
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel(Copy.breakLeft(left))
            }
        }
        .frame(width: 180, height: 180)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { inhale = true }
        }
    }
}
