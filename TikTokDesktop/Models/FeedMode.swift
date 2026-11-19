import Foundation

/// Separates the supported playback & browsing engines transparently.
enum BrowsingEngine: String, CaseIterable, Identifiable, Codable, Sendable {
    case nativeFeed = "Native Player"
    case tikTokWeb = "TikTok Web"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .nativeFeed: return "play.rectangle.fill"
        case .tikTokWeb: return "globe"
        }
    }

    var subtitle: String {
        switch self {
        case .nativeFeed:
            return "Native AVPlayer + Official TikTok Embedded Player v1"
        case .tikTokWeb:
            return "Authentic TikTok Web Session via WKWebView"
        }
    }
}

enum VideoQualityPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto = "Auto"
    case hd1080 = "1080p"
    case hd720 = "720p"
    case sd480 = "480p"

    var id: String { rawValue }

    var preferredPeakBitRate: Double {
        switch self {
        case .auto: return 0
        case .hd1080: return 8_000_000
        case .hd720: return 4_000_000
        case .sd480: return 1_800_000
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"

    var id: String { rawValue }
}
