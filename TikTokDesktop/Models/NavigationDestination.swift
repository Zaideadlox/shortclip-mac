import Foundation

enum NavigationDestination: String, CaseIterable, Identifiable, Hashable, Sendable {
    case forYou
    case following
    case friends
    case explore
    case live
    case messages
    case profile
    case settings
    case search

    var id: String { rawValue }

    static var sidebarItems: [NavigationDestination] {
        [.forYou, .following, .friends, .explore, .live, .messages, .profile, .settings]
    }

    var title: String {
        switch self {
        case .forYou: return "For You"
        case .following: return "Following"
        case .friends: return "Friends"
        case .explore: return "Explore"
        case .live: return "LIVE"
        case .messages: return "Messages"
        case .profile: return "Profile"
        case .settings: return "Settings"
        case .search: return "Search"
        }
    }

    var systemImage: String {
        switch self {
        case .forYou: return "house.fill"
        case .following: return "person.2.fill"
        case .friends: return "person.3.fill"
        case .explore: return "safari.fill"
        case .live: return "dot.radiowaves.left.and.right"
        case .messages: return "paperplane.fill"
        case .profile: return "person.crop.circle.fill"
        case .settings: return "gearshape.fill"
        case .search: return "magnifyingglass"
        }
    }

    var supportsFeedView: Bool {
        switch self {
        case .forYou, .following, .friends, .explore:
            return true
        default:
            return false
        }
    }

    var prefersWebByDefault: Bool {
        switch self {
        case .live, .messages:
            return true
        default:
            return false
        }
    }

    var tikTokWebURL: URL {
        switch self {
        case .forYou:
            return URL(string: "https://www.tiktok.com/foryou")!
        case .following:
            return URL(string: "https://www.tiktok.com/following")!
        case .friends:
            return URL(string: "https://www.tiktok.com/friends")!
        case .explore:
            return URL(string: "https://www.tiktok.com/explore")!
        case .live:
            return URL(string: "https://www.tiktok.com/live")!
        case .messages:
            return URL(string: "https://www.tiktok.com/messages")!
        case .profile:
            return URL(string: "https://www.tiktok.com/profile")!
        case .search:
            return URL(string: "https://www.tiktok.com/search")!
        case .settings:
            return URL(string: "https://www.tiktok.com/setting")!
        }
    }
}
