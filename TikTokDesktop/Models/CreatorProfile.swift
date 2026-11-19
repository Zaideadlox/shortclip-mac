import Foundation
import SwiftUI

struct CreatorProfile: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let bio: String
    let isVerified: Bool
    let avatarSymbol: String
    let avatarAccentHex: UInt32
    let avatarSecondaryHex: UInt32
    let avatarURLString: String?
    var followersCount: Int
    var followingCount: Int
    var totalLikesCount: Int
    var isFollowed: Bool
    let tikTokProfileURL: String

    var handle: String {
        username.hasPrefix("@") ? username : "@\(username)"
    }

    var avatarURL: URL? {
        avatarURLString.flatMap(URL.init(string:))
    }

    var webURL: URL? {
        URL(string: tikTokProfileURL)
    }

    var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: avatarAccentHex), Color(hex: avatarSecondaryHex)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
