import Foundation
import Observation

@MainActor
@Observable
final class FeedViewModel {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var videos: [VideoItem] {
        appState.currentFeedVideos
    }

    var currentIndex: Int {
        get {
            guard !videos.isEmpty else { return 0 }
            return min(max(appState.activeFeedIndex, 0), videos.count - 1)
        }
        set {
            guard !videos.isEmpty else { return }
            let clamped = min(max(newValue, 0), videos.count - 1)
            appState.activeFeedIndex = clamped
            appState.activeVideoID = videos[clamped].id
            syncPlaybackForCurrentVideo()
        }
    }

    var currentVideo: VideoItem? {
        guard !videos.isEmpty else { return nil }
        return videos[currentIndex]
    }

    var canGoPrevious: Bool {
        currentIndex > 0
    }

    var canGoNext: Bool {
        currentIndex + 1 < videos.count
    }

    var playerManager: NativeVideoPlayerManager {
        appState.container.videoPlayerManager
    }

    func syncPlaybackForCurrentVideo() {
        guard let video = currentVideo else {
            playerManager.pause()
            return
        }

        if appState.activeEngine == .tikTokWeb || !appState.selectedDestination.supportsFeedView {
            playerManager.pause()
            return
        }

        switch video.source {
        case .bundledMP4, .remoteStream:
            if let url = video.source.resolvedNativeMediaURL {
                playerManager.load(url: url, autoPlay: appState.container.preferences.autoPlayEnabled)
            }
        case .officialTikTokEmbed:
            playerManager.pause()
        }
    }

    func goNext() {
        guard canGoNext else { return }
        currentIndex += 1
    }

    func goPrevious() {
        guard canGoPrevious else { return }
        currentIndex -= 1
    }

    func toggleLike(for video: VideoItem) {
        appState.container.feedRepository.toggleLike(videoID: video.id)
    }

    func toggleBookmark(for video: VideoItem) {
        appState.container.feedRepository.toggleBookmark(videoID: video.id)
        let isSaved = appState.container.feedRepository.videos.first(where: { $0.id == video.id })?.isBookmarked ?? false
        appState.showToast(isSaved ? "Saved to Favorites" : "Removed from Favorites")
    }

    func toggleFollow(creatorID: String) {
        appState.container.feedRepository.toggleFollow(creatorID: creatorID)
        let following = appState.container.feedRepository.isFollowing(creatorID: creatorID)
        appState.showToast(following ? "Following creator" : "Unfollowed creator")
    }

    func isFollowing(creatorID: String) -> Bool {
        appState.container.feedRepository.isFollowing(creatorID: creatorID)
    }
}
