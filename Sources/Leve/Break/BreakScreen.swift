import AppKit
import SwiftUI

/// The break: "Stop. Breathe. Look away." over a slowly breathing circle, with the time left. It
/// closes by itself when the time is up, or with Skip (Esc) or Later, which leaves it waiting in the
/// menu bar (#19). When sound plays and Leve
/// does not pause it on its own, it also offers Pause Music and Videos (#13).
final class BreakScreen {
    var onDone: (() -> Void)?
    var onSkip: (() -> Void)?
    var onLater: (() -> Void)?
    var onPauseMedia: (() -> Void)?

    private let overlay = FullScreenOverlay()
    private var endTask: Task<Void, Never>?

    var isVisible: Bool { overlay.isVisible }

    func present(minutes: Int, sound: Bool, offersPause: Bool = false) {
        let end = Date.now.addingTimeInterval(Double(minutes * 60))
        let skip: () -> Void = { [weak self] in self?.finish { self?.onSkip?() } }
        let view = BreakView(
            end: end,
            minutes: minutes,
            offersPause: offersPause,
            onSkip: skip,
            onLater: { [weak self] in self?.finish { self?.onLater?() } },
            onPause: { [weak self] in self?.onPauseMedia?() }
        )
        overlay.present(view, tint: BreakView.tint, onEscape: skip)
        if sound {
            SoftSound.melody.play(volume: 0.3)
        }
        endTask?.cancel()
        endTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(end.timeIntervalSinceNow))
            guard !Task.isCancelled else { return }
            // The same tone, softer, says the break is over to someone who looked away.
            if sound {
                SoftSound.melody.play(volume: 0.18)
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
    let offersPause: Bool
    let onSkip: () -> Void
    let onLater: () -> Void
    let onPause: () -> Void
    /// The button goes once pressed; the pause it starts reports after the break (#12).
    @State private var paused = false

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
                Button(Copy.breakLater, action: onLater)
                    .accessibilityHint(Copy.breakLaterHint)
                if offersPause, !paused {
                    // Return presses it: the one action on this screen that is not leaving it.
                    Button(Copy.pauseMediaNow) {
                        paused = true
                        onPause()
                    }
                    .keyboardShortcut(.defaultAction)
                    .tint(Self.tint)
                    .accessibilityHint(Copy.pauseMediaNowHint)
                }
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
