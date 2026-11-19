import Foundation

enum AuthMethod: String, Codable, Sendable {
    case none
    case officialOAuth
    case webSession
}

struct TikTokOAuthToken: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let openID: String
    let scope: String
    let expiresAt: Date
    let tokenType: String

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60)
    }
}

struct TikTokAPIUser: Codable, Sendable, Equatable {
    let openID: String
    let unionID: String?
    let displayName: String
    let username: String?
    let avatarURL: String?
    let bioDescription: String?
    let isVerified: Bool?
    let followerCount: Int?
    let followingCount: Int?
    let likesCount: Int?
    let videoCount: Int?
}

struct AuthSession: Equatable, Sendable {
    var method: AuthMethod = .none
    var oauthUser: TikTokAPIUser?
    var hasWebSessionCookies: Bool = false
    var connectedScopes: [String] = []

    var isSignedIn: Bool {
        oauthUser != nil || hasWebSessionCookies
    }

    var statusLabel: String {
        if let user = oauthUser {
            return user.displayName
        }
        if hasWebSessionCookies {
            return "TikTok Web Session"
        }
        return "Guest Mode"
    }
}
