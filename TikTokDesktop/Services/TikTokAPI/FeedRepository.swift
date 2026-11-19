import Foundation
import Observation

/// Central repository for native AVPlayer vertical videos, official TikTok oEmbed videos,
/// creators, comments, and local interactive state (likes, bookmarks, follows).
@MainActor
@Observable
final class FeedRepository {
    private(set) var videos: [VideoItem] = []
    private(set) var creators: [CreatorProfile] = []
    private(set) var commentsByVideoID: [String: [CommentItem]] = [:]

    private let persistenceURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("TikTokDesktop", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.persistenceURL = dir.appendingPathComponent("user_state_v1.json")

        seedCatalog()
        loadPersistedState()
    }

    func videos(for destination: NavigationDestination) -> [VideoItem] {
        switch destination {
        case .forYou:
            return videos
        case .following:
            let followedIDs = Set(creators.filter(\.isFollowed).map(\.id))
            let filtered = videos.filter { followedIDs.contains($0.creatorID) || $0.categories.contains(.following) }
            return filtered.isEmpty ? videos : filtered
        case .friends:
            let filtered = videos.filter { $0.categories.contains(.friends) }
            return filtered.isEmpty ? Array(videos.prefix(4)) : filtered
        case .explore:
            return videos.sorted { $0.viewsCount > $1.viewsCount }
        default:
            return videos
        }
    }

    func creator(for id: String) -> CreatorProfile? {
        creators.first { $0.id == id }
    }

    func creator(byUsername username: String) -> CreatorProfile? {
        let normalized = username.replacingOccurrences(of: "@", with: "").lowercased()
        return creators.first { $0.username.lowercased() == normalized }
    }

    func videos(byCreatorID creatorID: String) -> [VideoItem] {
        videos.filter { $0.creatorID == creatorID }
    }

    var likedVideos: [VideoItem] {
        videos.filter(\.isLiked)
    }

    var bookmarkedVideos: [VideoItem] {
        videos.filter(\.isBookmarked)
    }

    var suggestedCreators: [CreatorProfile] {
        Array(creators.prefix(5))
    }

    func toggleLike(videoID: String) {
        guard let idx = videos.firstIndex(where: { $0.id == videoID }) else { return }
        videos[idx].isLiked.toggle()
        videos[idx].likesCount += videos[idx].isLiked ? 1 : -1
        savePersistedState()
    }

    func toggleBookmark(videoID: String) {
        guard let idx = videos.firstIndex(where: { $0.id == videoID }) else { return }
        videos[idx].isBookmarked.toggle()
        videos[idx].bookmarksCount += videos[idx].isBookmarked ? 1 : -1
        savePersistedState()
    }

    func toggleFollow(creatorID: String) {
        guard let idx = creators.firstIndex(where: { $0.id == creatorID }) else { return }
        creators[idx].isFollowed.toggle()
        creators[idx].followersCount += creators[idx].isFollowed ? 1 : -1
        savePersistedState()
    }

    func isFollowing(creatorID: String) -> Bool {
        creators.first(where: { $0.id == creatorID })?.isFollowed ?? false
    }

    func comments(for videoID: String) -> [CommentItem] {
        commentsByVideoID[videoID] ?? []
    }

    func addComment(to videoID: String, text: String, authorName: String = "You", authorUsername: String = "mac_viewer") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item = CommentItem(
            id: UUID().uuidString,
            videoID: videoID,
            authorUsername: authorUsername,
            authorDisplayName: authorName,
            authorAccentHex: 0x25F4EE,
            text: trimmed,
            timestamp: "Just now",
            likesCount: 0,
            isLiked: false
        )
        commentsByVideoID[videoID, default: []].insert(item, at: 0)
        if let idx = videos.firstIndex(where: { $0.id == videoID }) {
            videos[idx].commentsCount += 1
        }
        savePersistedState()
    }

    func toggleCommentLike(videoID: String, commentID: String) {
        guard var list = commentsByVideoID[videoID],
              let idx = list.firstIndex(where: { $0.id == commentID })
        else { return }
        list[idx].isLiked.toggle()
        list[idx].likesCount += list[idx].isLiked ? 1 : -1
        commentsByVideoID[videoID] = list
    }

    func prependCustomVideo(_ item: VideoItem) {
        videos.removeAll { $0.id == item.id }
        videos.insert(item, at: 0)

        if !creators.contains(where: { $0.id == item.creatorID }) {
            let newCreator = CreatorProfile(
                id: item.creatorID,
                username: item.creatorUsername,
                displayName: item.creatorDisplayName,
                bio: "Added via Official TikTok oEmbed API",
                isVerified: item.creatorVerified,
                avatarSymbol: item.creatorAvatarSymbol,
                avatarAccentHex: item.creatorAvatarHex,
                avatarSecondaryHex: item.creatorAvatarSecondaryHex,
                avatarURLString: nil,
                followersCount: 12_400,
                followingCount: 184,
                totalLikesCount: 184_000,
                isFollowed: false,
                tikTokProfileURL: "https://www.tiktok.com/@\(item.creatorUsername)"
            )
            creators.append(newCreator)
        }
        savePersistedState()
    }

    func mergeAuthenticatedUserVideos(_ apiVideos: [VideoItem]) {
        for item in apiVideos.reversed() {
            if !videos.contains(where: { $0.id == item.id }) {
                videos.insert(item, at: 0)
            }
        }
    }

    func allHashtags() -> [HashtagSummary] {
        var counts: [String: (Int, Int)] = [:]
        for video in videos {
            for tag in video.hashtags {
                let normalized = tag.lowercased()
                let current = counts[normalized] ?? (0, 0)
                counts[normalized] = (current.0 + 1, current.1 + max(video.viewsCount, 12_000))
            }
        }
        return counts.map { HashtagSummary(tag: $0.key, videoCount: $0.value.0, totalViews: $0.value.1) }
            .sorted { $0.totalViews > $1.totalViews }
    }

    // MARK: - Persistence

    private struct PersistedUserState: Codable {
        var likedIDs: [String]
        var bookmarkedIDs: [String]
        var followedCreatorIDs: [String]
        var customVideos: [VideoItem]
    }

    private func savePersistedState() {
        let custom = videos.filter { $0.id.hasPrefix("tiktok_embed_") || $0.id.hasPrefix("custom_") }
        let state = PersistedUserState(
            likedIDs: videos.filter(\.isLiked).map(\.id),
            bookmarkedIDs: videos.filter(\.isBookmarked).map(\.id),
            followedCreatorIDs: creators.filter(\.isFollowed).map(\.id),
            customVideos: custom
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: persistenceURL, options: .atomic)
        }
    }

    private func loadPersistedState() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let state = try? JSONDecoder().decode(PersistedUserState.self, from: data)
        else { return }

        for custom in state.customVideos.reversed() where !videos.contains(where: { $0.id == custom.id }) {
            videos.insert(custom, at: 0)
        }

        let likedSet = Set(state.likedIDs)
        let bookmarkedSet = Set(state.bookmarkedIDs)
        let followedSet = Set(state.followedCreatorIDs)

        for i in videos.indices {
            if likedSet.contains(videos[i].id) { videos[i].isLiked = true }
            if bookmarkedSet.contains(videos[i].id) { videos[i].isBookmarked = true }
        }
        for i in creators.indices {
            if followedSet.contains(creators[i].id) { creators[i].isFollowed = true }
        }
    }

    // MARK: - Curated Native & Official Embed Seed Catalog

    private func seedCatalog() {
        creators = [
            CreatorProfile(
                id: "creator_alvin",
                username: "alvin.nyc",
                displayName: "Alvin",
                bio: "Visual director & midnight motion loops in NYC. Shot & graded natively on Mac.",
                isVerified: true,
                avatarSymbol: "sparkles",
                avatarAccentHex: 0xFE2C55,
                avatarSecondaryHex: 0x6C2BD9,
                avatarURLString: nil,
                followersCount: 2_480_000,
                followingCount: 214,
                totalLikesCount: 48_900_000,
                isFollowed: true,
                tikTokProfileURL: "https://www.tiktok.com/@tiktok"
            ),
            CreatorProfile(
                id: "creator_kaia",
                username: "kaia.waves",
                displayName: "Kaia Sato",
                bio: "Pacific ambient sound design, shaders & ocean visualizers. 9:16 vertical art.",
                isVerified: true,
                avatarSymbol: "water.waves",
                avatarAccentHex: 0x25F4EE,
                avatarSecondaryHex: 0x0EA5E9,
                avatarURLString: nil,
                followersCount: 1_190_000,
                followingCount: 142,
                totalLikesCount: 21_300_000,
                isFollowed: true,
                tikTokProfileURL: "https://www.tiktok.com/@tiktok"
            ),
            CreatorProfile(
                id: "creator_nordic",
                username: "nordic.light",
                displayName: "Soren Lind",
                bio: "Aurora chaser, minimal synth sketches & vertical cinematography from Tromsø.",
                isVerified: true,
                avatarSymbol: "moon.stars.fill",
                avatarAccentHex: 0x10B981,
                avatarSecondaryHex: 0x25F4EE,
                avatarURLString: nil,
                followersCount: 842_000,
                followingCount: 98,
                totalLikesCount: 14_700_000,
                isFollowed: false,
                tikTokProfileURL: "https://www.tiktok.com/@tiktok"
            ),
            CreatorProfile(
                id: "creator_pulse",
                username: "cyber.pulse",
                displayName: "Mina K.",
                bio: "Live audio-reactive club visuals & Tokyo neon loops.",
                isVerified: false,
                avatarSymbol: "waveform.path.ecg",
                avatarAccentHex: 0xEC4899,
                avatarSecondaryHex: 0xF97316,
                avatarURLString: nil,
                followersCount: 519_000,
                followingCount: 310,
                totalLikesCount: 9_120_000,
                isFollowed: false,
                tikTokProfileURL: "https://www.tiktok.com/@tiktok"
            ),
            CreatorProfile(
                id: "creator_vinyl",
                username: "thelotradio.vibes",
                displayName: "Sunset Vinyl",
                bio: "Analog warmth, golden hour palettes & desktop focus beats.",
                isVerified: true,
                avatarSymbol: "opticaldisc.fill",
                avatarAccentHex: 0xF59E0B,
                avatarSecondaryHex: 0xFE2C55,
                avatarURLString: nil,
                followersCount: 1_650_000,
                followingCount: 87,
                totalLikesCount: 31_400_000,
                isFollowed: true,
                tikTokProfileURL: "https://www.tiktok.com/@thelotradio"
            ),
            CreatorProfile(
                id: "creator_scout",
                username: "scout2015",
                displayName: "Scout (Official Embed)",
                bio: "Official public TikTok video loaded via TikTok's documented oEmbed & v1 Embedded Player.",
                isVerified: true,
                avatarSymbol: "play.circle.fill",
                avatarAccentHex: 0x25F4EE,
                avatarSecondaryHex: 0xFE2C55,
                avatarURLString: nil,
                followersCount: 640_000,
                followingCount: 54,
                totalLikesCount: 12_800_000,
                isFollowed: false,
                tikTokProfileURL: "https://www.tiktok.com/@scout2015"
            )
        ]

        videos = [
            VideoItem(
                id: "native_neon_tokyo",
                creatorID: "creator_alvin",
                creatorUsername: "alvin.nyc",
                creatorDisplayName: "Alvin",
                creatorVerified: true,
                creatorAvatarHex: 0xFE2C55,
                creatorAvatarSecondaryHex: 0x6C2BD9,
                creatorAvatarSymbol: "sparkles",
                description: "Midnight neon gradients & spatial synth on macOS. Smooth 9:16 AVPlayer playback with native Picture-in-Picture! #neon #macos #design #foryou",
                hashtags: ["neon", "macos", "design", "foryou"],
                musicTitle: "Ultra Instinct (Lo-Fi Flip)",
                musicArtist: "adamdev",
                locationTag: "New York",
                postedRelativeTime: "4d ago",
                categories: [.forYou, .following, .explore],
                source: .bundledMP4(resourceName: "sample_neon_tokyo", thumbnailName: "sample_neon_tokyo"),
                shareURL: URL(string: "https://www.tiktok.com/foryou")!,
                likesCount: 2_214_800,
                commentsCount: 3_368,
                bookmarksCount: 145_600,
                sharesCount: 28_420,
                viewsCount: 18_400_000,
                isLiked: false,
                isBookmarked: false
            ),
            VideoItem(
                id: "native_ocean_wave",
                creatorID: "creator_kaia",
                creatorUsername: "kaia.waves",
                creatorDisplayName: "Kaia Sato",
                creatorVerified: true,
                creatorAvatarHex: 0x25F4EE,
                creatorAvatarSecondaryHex: 0x0EA5E9,
                creatorAvatarSymbol: "water.waves",
                description: "Deep Pacific turquoise currents — built for calm focus sessions while working on Apple Silicon. Press Space to pause or ⌘P for PiP. #ambient #ocean #chill #apple",
                hashtags: ["ambient", "ocean", "chill", "apple"],
                musicTitle: "Tidal Resonance",
                musicArtist: "Kaia Sato",
                locationTag: "Kyoto",
                postedRelativeTime: "1d ago",
                categories: [.forYou, .following, .friends, .explore],
                source: .bundledMP4(resourceName: "sample_ocean_wave", thumbnailName: "sample_ocean_wave"),
                shareURL: URL(string: "https://www.tiktok.com/explore")!,
                likesCount: 948_200,
                commentsCount: 1_924,
                bookmarksCount: 82_100,
                sharesCount: 14_300,
                viewsCount: 7_850_000,
                isLiked: false,
                isBookmarked: false
            ),
            VideoItem(
                id: "official_embed_scout",
                creatorID: "creator_scout",
                creatorUsername: "scout2015",
                creatorDisplayName: "Scout (Official TikTok Embed)",
                creatorVerified: true,
                creatorAvatarHex: 0x25F4EE,
                creatorAvatarSecondaryHex: 0xFE2C55,
                creatorAvatarSymbol: "play.circle.fill",
                description: "Real public TikTok video rendered via TikTok's official v1 Embedded Video Player (tiktok.com/player/v1/) with native postMessage controls! #tiktok #officialembed #pets",
                hashtags: ["tiktok", "officialembed", "pets"],
                musicTitle: "Original Sound",
                musicArtist: "scout2015",
                locationTag: "Official Player v1",
                postedRelativeTime: "Official Embed",
                categories: [.forYou, .explore],
                source: .officialTikTokEmbed(
                    videoID: "6718335390845095173",
                    canonicalURL: URL(string: "https://www.tiktok.com/@scout2015/video/6718335390845095173")!,
                    thumbnailURL: nil
                ),
                shareURL: URL(string: "https://www.tiktok.com/@scout2015/video/6718335390845095173")!,
                likesCount: 1_420_000,
                commentsCount: 14_200,
                bookmarksCount: 96_400,
                sharesCount: 41_200,
                viewsCount: 24_900_000,
                isLiked: false,
                isBookmarked: false
            ),
            VideoItem(
                id: "native_aurora_drift",
                creatorID: "creator_nordic",
                creatorUsername: "nordic.light",
                creatorDisplayName: "Soren Lind",
                creatorVerified: true,
                creatorAvatarHex: 0x10B981,
                creatorAvatarSecondaryHex: 0x25F4EE,
                creatorAvatarSymbol: "moon.stars.fill",
                description: "Northern lights color field study over Tromsø. Scroll with ↑ / ↓ arrows or your trackpad to flip smoothly between clips. #aurora #minimal #nordic #art",
                hashtags: ["aurora", "minimal", "nordic", "art"],
                musicTitle: "Arctic Drift (C Major)",
                musicArtist: "Soren Lind",
                locationTag: "Tromsø, Norway",
                postedRelativeTime: "6h ago",
                categories: [.forYou, .friends, .explore],
                source: .bundledMP4(resourceName: "sample_aurora_drift", thumbnailName: "sample_aurora_drift"),
                shareURL: URL(string: "https://www.tiktok.com/foryou")!,
                likesCount: 612_400,
                commentsCount: 842,
                bookmarksCount: 54_900,
                sharesCount: 8_910,
                viewsCount: 5_120_000,
                isLiked: false,
                isBookmarked: false
            ),
            VideoItem(
                id: "native_cyber_pulse",
                creatorID: "creator_pulse",
                creatorUsername: "cyber.pulse",
                creatorDisplayName: "Mina K.",
                creatorVerified: false,
                creatorAvatarHex: 0xEC4899,
                creatorAvatarSecondaryHex: 0xF97316,
                creatorAvatarSymbol: "waveform.path.ecg",
                description: "Audio-reactive radial pulse built for late-night synth jams. Double-click the video to send a TikTok heart burst! #synthwave #cyber #visuals #music",
                hashtags: ["synthwave", "cyber", "visuals", "music"],
                musicTitle: "Shibuya Sub-Bass",
                musicArtist: "Mina K.",
                locationTag: "Tokyo",
                postedRelativeTime: "12h ago",
                categories: [.forYou, .explore],
                source: .bundledMP4(resourceName: "sample_cyber_pulse", thumbnailName: "sample_cyber_pulse"),
                shareURL: URL(string: "https://www.tiktok.com/foryou")!,
                likesCount: 389_500,
                commentsCount: 615,
                bookmarksCount: 29_300,
                sharesCount: 6_450,
                viewsCount: 3_410_000,
                isLiked: false,
                isBookmarked: false
            ),
            VideoItem(
                id: "native_sunset_vinyl",
                creatorID: "creator_vinyl",
                creatorUsername: "thelotradio.vibes",
                creatorDisplayName: "Sunset Vinyl",
                creatorVerified: true,
                creatorAvatarHex: 0xF59E0B,
                creatorAvatarSecondaryHex: 0xFE2C55,
                creatorAvatarSymbol: "opticaldisc.fill",
                description: "Golden hour warm tape chords spinning live from Brooklyn. Switch to TikTok Web in the top bar anytime to browse your live TikTok account feed! #vinyl #lofi #brooklyn #beats",
                hashtags: ["vinyl", "lofi", "brooklyn", "beats"],
                musicTitle: "Warm Tape Loop 04",
                musicArtist: "Sunset Vinyl",
                locationTag: "Brooklyn, NY",
                postedRelativeTime: "2d ago",
                categories: [.forYou, .following, .friends],
                source: .bundledMP4(resourceName: "sample_sunset_vinyl", thumbnailName: "sample_sunset_vinyl"),
                shareURL: URL(string: "https://www.tiktok.com/foryou")!,
                likesCount: 1_105_000,
                commentsCount: 2_140,
                bookmarksCount: 112_000,
                sharesCount: 19_800,
                viewsCount: 11_600_000,
                isLiked: false,
                isBookmarked: false
            ),
            VideoItem(
                id: "native_minimal_kinetics",
                creatorID: "creator_alvin",
                creatorUsername: "alvin.nyc",
                creatorDisplayName: "Alvin",
                creatorVerified: true,
                creatorAvatarHex: 0xFE2C55,
                creatorAvatarSecondaryHex: 0x6C2BD9,
                creatorAvatarSymbol: "sparkles",
                description: "Kinetic cyan prism study — testing 60fps SwiftUI animations alongside hardware-accelerated AVFoundation video playback. #swiftui #kinetics #motion #creative",
                hashtags: ["swiftui", "kinetics", "motion", "creative"],
                musicTitle: "Prism Arpeggio",
                musicArtist: "Alvin Studio",
                locationTag: "San Francisco",
                postedRelativeTime: "3d ago",
                categories: [.forYou, .following, .explore],
                source: .bundledMP4(resourceName: "sample_minimal_kinetics", thumbnailName: "sample_minimal_kinetics"),
                shareURL: URL(string: "https://www.tiktok.com/foryou")!,
                likesCount: 734_100,
                commentsCount: 1_108,
                bookmarksCount: 64_200,
                sharesCount: 9_820,
                viewsCount: 6_290_000,
                isLiked: false,
                isBookmarked: false
            )
        ]

        commentsByVideoID = [
            "native_neon_tokyo": [
                CommentItem(id: "c1", videoID: "native_neon_tokyo", authorUsername: "elena.design", authorDisplayName: "Elena M.", authorAccentHex: 0x25F4EE, text: "The native macOS smoothness on this player is unreal.", timestamp: "2h ago", likesCount: 428, isLiked: false),
                CommentItem(id: "c2", videoID: "native_neon_tokyo", authorUsername: "dev_marcus", authorDisplayName: "Marcus", authorAccentHex: 0xFE2C55, text: "Picture-in-Picture while coding in Xcode is a game changer.", timestamp: "5h ago", likesCount: 196, isLiked: false),
                CommentItem(id: "c3", videoID: "native_neon_tokyo", authorUsername: "sora_beats", authorDisplayName: "Sora", authorAccentHex: 0xA855F7, text: "Track ID hits so clean on MacBook speakers.", timestamp: "1d ago", likesCount: 84, isLiked: false)
            ],
            "native_ocean_wave": [
                CommentItem(id: "c4", videoID: "native_ocean_wave", authorUsername: "kaito.dev", authorDisplayName: "Kaito", authorAccentHex: 0x0EA5E9, text: "Leaving this looping in PiP on the corner of my display all afternoon.", timestamp: "3h ago", likesCount: 215, isLiked: false)
            ],
            "official_embed_scout": [
                CommentItem(id: "c5", videoID: "official_embed_scout", authorUsername: "swift_fan", authorDisplayName: "Alex", authorAccentHex: 0x10B981, text: "Love that you can paste any public TikTok link and play it through the official embed player.", timestamp: "1d ago", likesCount: 310, isLiked: false)
            ]
        ]
    }
}
