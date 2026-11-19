import Foundation
import Observation

enum ProfileVideoTab: String, CaseIterable, Identifiable, Sendable {
    case videos = "Videos"
    case favorites = "Favorites"
    case liked = "Liked"

    var id: String { rawValue }
}

@MainActor
@Observable
final class ProfileViewModel {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var viewingCreator: CreatorProfile? {
        guard let creatorID = appState.selectedCreatorID else { return nil }
        return appState.container.feedRepository.creator(for: creatorID)
    }

    var isOwnProfile: Bool {
        viewingCreator == nil
    }

    var oauthUser: TikTokAPIUser? {
        appState.container.authService.session.oauthUser
    }

    var displayName: String {
        if let creator = viewingCreator { return creator.displayName }
        if let user = oauthUser { return user.displayName }
        return appState.container.authService.session.hasWebSessionCookies ? "TikTok Web Member" : "macOS Viewer"
    }

    var username: String {
        if let creator = viewingCreator { return creator.username }
        if let user = oauthUser { return user.username ?? user.openID.prefix(12).description }
        return "mac_desktop_user"
    }

    var bio: String {
        if let creator = viewingCreator { return creator.bio }
        if let user = oauthUser, let bio = user.bioDescription, !bio.isEmpty { return bio }
        return "Browsing natively with TikTok Desktop for macOS. Sign in with TikTok OAuth or TikTok Web to sync your account."
    }

    var isVerified: Bool {
        viewingCreator?.isVerified ?? oauthUser?.isVerified ?? false
    }

    var followersCount: Int {
        if let creator = viewingCreator { return creator.followersCount }
        return oauthUser?.followerCount ?? 0
    }

    var followingCount: Int {
        if let creator = viewingCreator { return creator.followingCount }
        return oauthUser?.followingCount ?? appState.container.feedRepository.creators.filter(\.isFollowed).count
    }

    var likesCount: Int {
        if let creator = viewingCreator { return creator.totalLikesCount }
        return oauthUser?.likesCount ?? appState.container.feedRepository.likedVideos.count
    }

    func videos(for tab: ProfileVideoTab) -> [VideoItem] {
        if let creator = viewingCreator {
            switch tab {
            case .videos:
                return appState.container.feedRepository.videos(byCreatorID: creator.id)
            case .favorites:
                return appState.container.feedRepository.bookmarkedVideos.filter { $0.creatorID == creator.id }
            case .liked:
                return appState.container.feedRepository.likedVideos.filter { $0.creatorID == creator.id }
            }
        } else {
            switch tab {
            case .videos:
                let apiOrCustom = appState.container.feedRepository.videos.filter {
                    $0.id.hasPrefix("api_") || $0.id.hasPrefix("tiktok_embed_") || $0.id.hasPrefix("custom_")
                }
                return apiOrCustom.isEmpty ? appState.container.feedRepository.videos : apiOrCustom
            case .favorites:
                return appState.container.feedRepository.bookmarkedVideos
            case .liked:
                return appState.container.feedRepository.likedVideos
            }
        }
    }

    func toggleFollow() {
        guard let creator = viewingCreator else { return }
        appState.container.feedRepository.toggleFollow(creatorID: creator.id)
    }
}
