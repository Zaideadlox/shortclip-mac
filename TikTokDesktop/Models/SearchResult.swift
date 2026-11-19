import Foundation

enum SearchFilterTab: String, CaseIterable, Identifiable, Sendable {
    case top = "Top"
    case videos = "Videos"
    case creators = "Creators"
    case hashtags = "Hashtags"
    case webSearch = "TikTok Web"

    var id: String { rawValue }
}

struct HashtagSummary: Identifiable, Hashable, Sendable {
    var id: String { tag }
    let tag: String
    let videoCount: Int
    let totalViews: Int
}
