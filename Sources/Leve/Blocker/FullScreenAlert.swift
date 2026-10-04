import AppKit
import LeveKit
import SwiftUI

/// The full-screen alert before an event, washed in its calendar's color, that stays until the
/// owner joins or closes it.
final class FullScreenAlert {
    var onJoin: ((CalendarEvent) -> Void)?
    var onClose: ((CalendarEvent) -> Void)?
    var onNeverForEvent: ((CalendarEvent) -> Void)?
    /// The event's calendar color; the model sets it.
    var tint: (CalendarEvent) -> NSColor = { _ in .controlAccentColor }

    private let overlay = FullScreenOverlay()
    private(set) var event: CalendarEvent?

    var isVisible: Bool { overlay.isVisible }

    func present(_ event: CalendarEvent) {
        self.event = event
        let close: () -> Void = { [weak self] in
            self?.finish { self?.onClose?(event) }
        }
        let color = Color(nsColor: tint(event))
        let view = FullScreenAlertView(
            event: event,
            tint: color,
            presentedAt: .now,
            onJoin: { [weak self] in self?.finish { self?.onJoin?(event) } },
            onClose: close,
            onNever: { [weak self] in self?.finish { self?.onNeverForEvent?(event) } }
        )
        overlay.present(view, tint: color, onEscape: close)
        SoftSound.bowl.play(volume: 0.35)
    }

    /// Hides the alert without counting it as closed by the owner, for an event that disappeared.
    func dismissSilently() {
        overlay.close()
        event = nil
    }

    private func finish(then action: () -> Void) {
        overlay.close()
        event = nil
        action()
    }
}

private struct FullScreenAlertView: View {
    let event: CalendarEvent
    let tint: Color
    let presentedAt: Date
    let onJoin: () -> Void
    let onClose: () -> Void
    let onNever: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(tint).frame(width: 10, height: 10).accessibilityHidden(true)
                    Text(event.calendarTitle)
                }
                .font(.title3)
                .foregroundStyle(.secondary)
                Text(event.title)
                    .font(.system(size: 56, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                Text(Copy.timeRange(event))
                    .font(.title2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            CountdownRing(start: event.start, presentedAt: presentedAt, tint: tint)
            HStack(spacing: 14) {
                Button(Copy.close, action: onClose)
                    .keyboardShortcut(.cancelAction)
                if let link = event.link {
                    Button(Copy.join(link.provider), action: onJoin)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(tint)
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

/// A thin ring that empties until the event starts, with the time left inside: "0:42", then "Now".
private struct CountdownRing: View {
    let start: Date
    let presentedAt: Date
    let tint: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, start.timeIntervalSince(context.date))
            let total = max(60, start.timeIntervalSince(presentedAt))
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: left / total)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(left > 0 ? Copy.clock(seconds: left) : Copy.now)
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 128, height: 128)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(left > 0 ? Copy.startsInSeconds(left) : Copy.startingNow)
        }
    }
}
