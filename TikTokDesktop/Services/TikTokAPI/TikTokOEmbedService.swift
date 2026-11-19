import Foundation

struct TikTokOEmbedResponse: Codable, Sendable {
    let version: String?
    let type: String?
    let title: String?
    let authorName: String?
    let authorURL: String?
    let authorUniqueID: String?
    let embedProductID: String?
    let embedType: String?
    let thumbnailURL: String?
    let html: String?
    let providerName: String?
    let providerURL: String?

    enum CodingKeys: String, CodingKey {
        case version
        case type
        case title
        case authorName = "author_name"
        case authorURL = "author_url"
        case authorUniqueID = "author_unique_id"
        case embedProductID = "embed_product_id"
        case embedType = "embed_type"
        case thumbnailURL = "thumbnail_url"
        case html
        case providerName = "provider_name"
        case providerURL = "provider_url"
    }
}

enum TikTokOEmbedError: LocalizedError, Sendable {
    case invalidURL
    case requestFailed(Int)
    case missingVideoID

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Please enter a valid public TikTok video URL (e.g. https://www.tiktok.com/@user/video/1234567890)."
        case .requestFailed(let code):
            return "TikTok oEmbed API returned HTTP \(code). Verify the video is public."
        case .missingVideoID:
            return "Could not extract a TikTok video ID from that URL."
        }
    }
}

final class TikTokOEmbedService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Queries TikTok's official public oEmbed endpoint:
    /// GET https://www.tiktok.com/oembed?url={video_url}
    func fetchOEmbed(for videoURLString: String) async throws -> TikTokOEmbedResponse {
        let trimmed = videoURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let targetURL = URL(string: trimmed),
              let host = targetURL.host?.lowercased(),
              host.contains("tiktok.com")
        else {
            throw TikTokOEmbedError.invalidURL
        }

        var components = URLComponents(string: "https://www.tiktok.com/oembed")!
        components.queryItems = [URLQueryItem(name: "url", value: trimmed)]
        guard let requestURL = components.url else {
            throw TikTokOEmbedError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw TikTokOEmbedError.requestFailed(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(TikTokOEmbedResponse.self, from: data)
    }

    /// Extracts a numeric TikTok video ID from a canonical URL or oEmbed response.
    func extractVideoID(from urlString: String, oEmbed: TikTokOEmbedResponse?) -> String? {
        if let embedID = oEmbed?.embedProductID, !embedID.isEmpty {
            return embedID
        }
        let pattern = #"/video/(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
           let range = Range(match.range(at: 1), in: urlString) {
            return String(urlString[range])
        }
        return nil
    }

    /// Resolves a public TikTok URL into a playable VideoItem backed by TikTok's official v1 Embedded Video Player.
    func resolveVideoItem(from urlString: String) async throws -> VideoItem {
        let oEmbed = try await fetchOEmbed(for: urlString)
        guard let videoID = extractVideoID(from: urlString, oEmbed: oEmbed) else {
            throw TikTokOEmbedError.missingVideoID
        }

        let canonicalURL = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? URL(string: "https://www.tiktok.com/video/\(videoID)")!

        let username = oEmbed.authorUniqueID
            ?? extractHandle(from: urlString)
            ?? "tiktok_creator"
        let displayName = oEmbed.authorName ?? username
        let caption = (oEmbed.title?.isEmpty == false ? oEmbed.title! : "Official TikTok Video #\(videoID)")
        let hashtags = extractHashtags(from: caption)
        let thumbnailURL = oEmbed.thumbnailURL.flatMap(URL.init(string:))

        return VideoItem(
            id: "tiktok_embed_\(videoID)",
            creatorID: "creator_\(username.lowercased())",
            creatorUsername: username,
            creatorDisplayName: displayName,
            creatorVerified: false,
            creatorAvatarHex: 0xFE2C55,
            creatorAvatarSecondaryHex: 0x25F4EE,
            creatorAvatarSymbol: "music.note",
            description: caption,
            hashtags: hashtags.isEmpty ? ["tiktok", "embed"] : hashtags,
            musicTitle: "Original Sound",
            musicArtist: displayName,
            locationTag: nil,
            postedRelativeTime: "Official Embed",
            categories: [.forYou, .explore],
            source: .officialTikTokEmbed(videoID: videoID, canonicalURL: canonicalURL, thumbnailURL: thumbnailURL),
            shareURL: canonicalURL,
            likesCount: 0,
            commentsCount: 0,
            bookmarksCount: 0,
            sharesCount: 0,
            viewsCount: 0,
            isLiked: false,
            isBookmarked: false
        )
    }

    private func extractHandle(from urlString: String) -> String? {
        let pattern = #"/@([A-Za-z0-9._]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
              let range = Range(match.range(at: 1), in: urlString)
        else { return nil }
        return String(urlString[range])
    }

    private func extractHashtags(from text: String) -> [String] {
        let pattern = #"#([A-Za-z0-9_]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }
}
