import Foundation

struct CommentItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let videoID: String
    let authorUsername: String
    let authorDisplayName: String
    let authorAccentHex: UInt32
    let text: String
    let timestamp: String
    var likesCount: Int
    var isLiked: Bool
}
