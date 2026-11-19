import Foundation

enum TikTokAPIError: LocalizedError, Sendable {
    case missingClientKey
    case invalidResponse
    case apiError(code: String, message: String)
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingClientKey:
            return "Configure your official TikTok Developer Client Key in Settings to use OAuth Display API v2."
        case .invalidResponse:
            return "Received an unexpected response from TikTok Open API."
        case .apiError(let code, let message):
            return "TikTok API Error (\(code)): \(message)"
        case .httpError(let statusCode, let message):
            return "TikTok Open API HTTP \(statusCode): \(message)"
        }
    }
}

/// Official TikTok Display API v2 client (`https://open.tiktokapis.com/v2/`).
/// Uses only documented public endpoints:
/// - POST /v2/oauth/token/
/// - GET  /v2/user/info/
/// - POST /v2/video/list/
final class TikTokAPIClient: Sendable {
    private let session: URLSession
    private let baseURL = URL(string: "https://open.tiktokapis.com/v2")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func exchangeAuthorizationCode(
        code: String,
        codeVerifier: String,
        clientKey: String,
        redirectURI: String
    ) async throws -> TikTokOAuthToken {
        let endpoint = baseURL.appendingPathComponent("oauth/token/")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_key", value: clientKey),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TikTokAPIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(OAuthTokenPayload.self, from: data)
        if let err = decoded.error, !err.isEmpty {
            throw TikTokAPIError.apiError(code: err, message: decoded.errorDescription ?? "Token exchange failed")
        }
        guard (200...299).contains(http.statusCode),
              let accessToken = decoded.accessToken,
              let openID = decoded.openID
        else {
            throw TikTokAPIError.httpError(statusCode: http.statusCode, message: decoded.errorDescription ?? "Unable to authenticate")
        }

        let expiresIn = TimeInterval(decoded.expiresIn ?? 86_400)
        return TikTokOAuthToken(
            accessToken: accessToken,
            refreshToken: decoded.refreshToken,
            openID: openID,
            scope: decoded.scope ?? "user.info.basic",
            expiresAt: Date().addingTimeInterval(expiresIn),
            tokenType: decoded.tokenType ?? "Bearer"
        )
    }

    func fetchUserInfo(accessToken: String) async throws -> TikTokAPIUser {
        var components = URLComponents(url: baseURL.appendingPathComponent("user/info/"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(
                name: "fields",
                value: "open_id,union_id,avatar_url,display_name,bio_description,is_verified,follower_count,following_count,likes_count,video_count,username"
            )
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TikTokAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw TikTokAPIError.httpError(statusCode: http.statusCode, message: "Could not fetch TikTok user profile.")
        }

        let envelope = try JSONDecoder().decode(UserInfoEnvelope.self, from: data)
        if let err = envelope.error, err.code != "ok" && !err.code.isEmpty {
            throw TikTokAPIError.apiError(code: err.code, message: err.message)
        }
        guard let user = envelope.data?.user else {
            throw TikTokAPIError.invalidResponse
        }

        return TikTokAPIUser(
            openID: user.openID,
            unionID: user.unionID,
            displayName: user.displayName ?? "TikTok User",
            username: user.username,
            avatarURL: user.avatarURL,
            bioDescription: user.bioDescription,
            isVerified: user.isVerified,
            followerCount: user.followerCount,
            followingCount: user.followingCount,
            likesCount: user.likesCount,
            videoCount: user.videoCount
        )
    }

    func fetchUserVideos(accessToken: String, maxCount: Int = 20) async throws -> [VideoItem] {
        var components = URLComponents(url: baseURL.appendingPathComponent("video/list/"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(
                name: "fields",
                value: "id,create_time,cover_image_url,share_url,video_description,title,like_count,comment_count,share_count,view_count,embed_link"
            )
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["max_count": min(max(maxCount, 1), 20)])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TikTokAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw TikTokAPIError.httpError(statusCode: http.statusCode, message: "Could not fetch user videos.")
        }

        let envelope = try JSONDecoder().decode(VideoListEnvelope.self, from: data)
        if let err = envelope.error, err.code != "ok" && !err.code.isEmpty {
            throw TikTokAPIError.apiError(code: err.code, message: err.message)
        }

        let apiVideos = envelope.data?.videos ?? []
        return apiVideos.compactMap { v in
            let canonical = URL(string: v.shareURL ?? "https://www.tiktok.com/video/\(v.id)")!
            let thumb = v.coverImageURL.flatMap(URL.init(string:))
            return VideoItem(
                id: "api_\(v.id)",
                creatorID: "me",
                creatorUsername: "my_tiktok",
                creatorDisplayName: "My TikTok Account",
                creatorVerified: false,
                creatorAvatarHex: 0x25F4EE,
                creatorAvatarSecondaryHex: 0xFE2C55,
                creatorAvatarSymbol: "person.fill",
                description: v.videoDescription ?? v.title ?? "TikTok Video",
                hashtags: ["tiktok", "displayapi"],
                musicTitle: "Original Sound",
                musicArtist: "My TikTok Account",
                locationTag: nil,
                postedRelativeTime: "Official API",
                categories: [.forYou],
                source: .officialTikTokEmbed(videoID: v.id, canonicalURL: canonical, thumbnailURL: thumb),
                shareURL: canonical,
                likesCount: v.likeCount ?? 0,
                commentsCount: v.commentCount ?? 0,
                bookmarksCount: 0,
                sharesCount: v.shareCount ?? 0,
                viewsCount: v.viewCount ?? 0,
                isLiked: false,
                isBookmarked: false
            )
        }
    }
}

// MARK: - Wire DTOs

private struct OAuthTokenPayload: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let openID: String?
    let scope: String?
    let expiresIn: Int?
    let tokenType: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case openID = "open_id"
        case scope
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case error
        case errorDescription = "error_description"
    }
}

private struct APIErrorPayload: Decodable {
    let code: String
    let message: String
}

private struct UserInfoEnvelope: Decodable {
    let data: UserInfoData?
    let error: APIErrorPayload?
}

private struct UserInfoData: Decodable {
    let user: UserInfoWire?
}

private struct UserInfoWire: Decodable {
    let openID: String
    let unionID: String?
    let avatarURL: String?
    let displayName: String?
    let username: String?
    let bioDescription: String?
    let isVerified: Bool?
    let followerCount: Int?
    let followingCount: Int?
    let likesCount: Int?
    let videoCount: Int?

    enum CodingKeys: String, CodingKey {
        case openID = "open_id"
        case unionID = "union_id"
        case avatarURL = "avatar_url"
        case displayName = "display_name"
        case username
        case bioDescription = "bio_description"
        case isVerified = "is_verified"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case likesCount = "likes_count"
        case videoCount = "video_count"
    }
}

private struct VideoListEnvelope: Decodable {
    let data: VideoListData?
    let error: APIErrorPayload?
}

private struct VideoListData: Decodable {
    let videos: [VideoWire]?
}

private struct VideoWire: Decodable {
    let id: String
    let coverImageURL: String?
    let shareURL: String?
    let videoDescription: String?
    let title: String?
    let likeCount: Int?
    let commentCount: Int?
    let shareCount: Int?
    let viewCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case coverImageURL = "cover_image_url"
        case shareURL = "share_url"
        case videoDescription = "video_description"
        case title
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case shareCount = "share_count"
        case viewCount = "view_count"
    }
}
