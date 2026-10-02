import Foundation

/// The video-call service a link belongs to, so the menu can say "Join Google Meet".
public enum MeetingProvider: String, Sendable, Hashable, CaseIterable {
    case googleMeet
    case microsoftTeams
    case zoom
    case webex
    case other

    static func detect(_ text: String) -> MeetingProvider {
        let value = text.lowercased()
        if value.contains("meet.google.com") {
            return .googleMeet
        }
        if value.contains("teams.microsoft.com") || value.contains("teams.live.com") || value.contains("msteams:") {
            return .microsoftTeams
        }
        if value.contains("zoom.us") || value.contains("zoom.com") {
            return .zoom
        }
        if value.contains("webex.com") {
            return .webex
        }
        return .other
    }
}

public struct MeetingLink: Sendable, Hashable {
    public let url: URL
    public let provider: MeetingProvider

    public init(url: URL, provider: MeetingProvider) {
        self.url = url
        self.provider = provider
    }

    /// The link to join: the event's own URL first, then a known call link found in the location
    /// or notes, then any other web link there. Ported from Smart Desk's `ItemLinkResolver`.
    public static func resolve(url: URL?, location: String?, notes: String?) -> MeetingLink? {
        if let url, isWebLink(url) {
            return MeetingLink(url: url, provider: .detect(url.absoluteString))
        }
        let found = extractURLs(from: location) + extractURLs(from: notes)
        let known = found.first { MeetingProvider.detect($0.absoluteString) != .other }
        guard let chosen = known ?? found.first else { return nil }
        return MeetingLink(url: chosen, provider: .detect(chosen.absoluteString))
    }

    static func extractURLs(from text: String?) -> [URL] {
        guard let text, !text.isEmpty,
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url).filter(isWebLink)
    }

    private static func isWebLink(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http" || scheme == "msteams" || scheme == "zoommtg"
    }
}
