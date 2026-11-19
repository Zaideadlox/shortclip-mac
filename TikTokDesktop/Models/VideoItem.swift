import Foundation

enum VideoSourceKind: Codable, Hashable, Sendable {
    /// Bundled local 9:16 vertical MP4 played via native AVPlayer + PiP.
    case bundledMP4(resourceName: String, thumbnailName: String)
    /// Remote direct MP4/HLS URL played via native AVPlayer + PiP.
    case remoteStream(url: URL, thumbnailURL: URL?)
    /// Official TikTok Embedded Video Player v1 (`https://www.tiktok.com/player/v1/{videoID}`).
    case officialTikTokEmbed(videoID: String, canonicalURL: URL, thumbnailURL: URL?)

    var isNativeAVPlayer: Bool {
        switch self {
        case .bundledMP4, .remoteStream:
            return true
        case .officialTikTokEmbed:
            return false
        }
    }

    var engineBadgeTitle: String {
        switch self {
        case .bundledMP4:
            return "Native AVPlayer"
        case .remoteStream:
            return "Native Stream"
        case .officialTikTokEmbed:
            return "TikTok Official Embed"
        }
    }

    var resolvedNativeMediaURL: URL? {
        switch self {
        case .bundledMP4(let resourceName, _):
            if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4", subdirectory: "SampleMedia") {
                return url
            }
            return Bundle.main.url(forResource: resourceName, withExtension: "mp4")
        case .remoteStream(let url, _):
            return url
        case .officialTikTokEmbed:
            return nil
        }
    }

    var resolvedLocalThumbnailURL: URL? {
        switch self {
        case .bundledMP4(_, let thumbnailName):
            if let url = Bundle.main.url(forResource: thumbnailName, withExtension: "jpg", subdirectory: "SampleMedia") {
                return url
            }
            return Bundle.main.url(forResource: thumbnailName, withExtension: "jpg")
        default:
            return nil
        }
    }

    var remoteThumbnailURL: URL? {
        switch self {
        case .remoteStream(_, let thumbnailURL):
            return thumbnailURL
        case .officialTikTokEmbed(_, _, let thumbnailURL):
            return thumbnailURL
        case .bundledMP4:
            return nil
        }
    }
}

enum FeedCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case forYou
    case following
    case friends
    case explore
}

struct VideoItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let creatorID: String
    let creatorUsername: String
    let creatorDisplayName: String
    let creatorVerified: Bool
    let creatorAvatarHex: UInt32
    let creatorAvatarSecondaryHex: UInt32
    let creatorAvatarSymbol: String
    let description: String
    let hashtags: [String]
    let musicTitle: String
    let musicArtist: String
    let locationTag: String?
    let postedRelativeTime: String
    let categories: [FeedCategory]
    let source: VideoSourceKind
    let shareURL: URL
    var likesCount: Int
    var commentsCount: Int
    var bookmarksCount: Int
    var sharesCount: Int
    var viewsCount: Int
    var isLiked: Bool
    var isBookmarked: Bool

    var musicCredit: String {
        "\(musicTitle) - \(musicArtist)"
    }
}
