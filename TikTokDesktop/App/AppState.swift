import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    let container: DependencyContainer

    var selectedDestination: NavigationDestination = .forYou
    var activeEngine: BrowsingEngine
    var searchQuery: String = ""
    var isSearchFocused: Bool = false
    var selectedCreatorID: String? = nil

    // Modals & Drawers
    var isShowingAuthSheet: Bool = false
    var isShowingAddURLSheet: Bool = false
    var isShowingCommentsDrawer: Bool = false
    var shareTargetVideo: VideoItem? = nil
    var toastMessage: String? = nil

    // Active Feed Video Tracking
    var activeFeedIndex: Int = 0
    var activeVideoID: String? = nil

    private var toastTask: Task<Void, Never>?

    init(container: DependencyContainer) {
        self.container = container
        self.activeEngine = container.preferences.defaultEngine
        self.activeVideoID = container.feedRepository.videos.first?.id
    }

    var preferredColorScheme: ColorScheme? {
        switch container.preferences.appearanceMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    var currentFeedVideos: [VideoItem] {
        container.feedRepository.videos(for: selectedDestination)
    }

    var currentVideo: VideoItem? {
        let list = currentFeedVideos
        guard !list.isEmpty else { return nil }
        let clamped = min(max(activeFeedIndex, 0), list.count - 1)
        return list[clamped]
    }

    func navigate(to destination: NavigationDestination) {
        if destination != .profile {
            selectedCreatorID = nil
        }
        selectedDestination = destination

        if destination.prefersWebByDefault {
            container.videoPlayerManager.pause()
            container.webController.load(destination: destination)
        } else if destination.supportsFeedView {
            if activeEngine == .tikTokWeb {
                container.videoPlayerManager.pause()
                container.webController.load(destination: destination)
            } else {
                container.webController.pauseMediaPlayback()
                activeFeedIndex = 0
                activeVideoID = currentFeedVideos.first?.id
            }
        } else {
            container.videoPlayerManager.pause()
            container.webController.pauseMediaPlayback()
        }
    }

    func setEngine(_ engine: BrowsingEngine) {
        activeEngine = engine
        if engine == .tikTokWeb {
            container.videoPlayerManager.pause()
            container.webController.load(destination: selectedDestination.supportsFeedView ? selectedDestination : .forYou)
        } else {
            container.webController.pauseMediaPlayback()
        }
    }

    func toggleEngine() {
        setEngine(activeEngine == .nativeFeed ? .tikTokWeb : .nativeFeed)
    }

    func openCreatorProfile(creatorID: String) {
        container.videoPlayerManager.pause()
        selectedCreatorID = creatorID
        selectedDestination = .profile
    }

    func openVideoInFeed(_ video: VideoItem) {
        activeEngine = .nativeFeed
        selectedDestination = .forYou
        let list = container.feedRepository.videos(for: .forYou)
        if let idx = list.firstIndex(where: { $0.id == video.id }) {
            activeFeedIndex = idx
            activeVideoID = video.id
        }
    }

    func triggerSearch(query: String? = nil) {
        if let query {
            searchQuery = query
        }
        selectedDestination = .search
        isSearchFocused = true
        container.videoPlayerManager.pause()
    }

    func openWebSignIn() {
        isShowingAuthSheet = false
        activeEngine = .tikTokWeb
        selectedDestination = .forYou
        container.videoPlayerManager.pause()
        container.webController.loadLoginPage()
        showToast("Sign in securely on TikTok's official login page")
    }

    func nextVideo() {
        if activeEngine == .tikTokWeb || selectedDestination.prefersWebByDefault {
            container.webController.dispatchKeyboardAction(key: "ArrowDown", code: "ArrowDown", keyCode: 40)
            return
        }
        let list = currentFeedVideos
        guard activeFeedIndex + 1 < list.count else { return }
        activeFeedIndex += 1
        activeVideoID = list[activeFeedIndex].id
    }

    func previousVideo() {
        if activeEngine == .tikTokWeb || selectedDestination.prefersWebByDefault {
            container.webController.dispatchKeyboardAction(key: "ArrowUp", code: "ArrowUp", keyCode: 38)
            return
        }
        let list = currentFeedVideos
        guard activeFeedIndex > 0, !list.isEmpty else { return }
        activeFeedIndex -= 1
        activeVideoID = list[activeFeedIndex].id
    }

    func togglePlayPause() {
        if activeEngine == .tikTokWeb || selectedDestination.prefersWebByDefault {
            container.webController.dispatchKeyboardAction(key: " ", code: "Space", keyCode: 32)
            return
        }
        container.videoPlayerManager.togglePlayPause()
    }

    func toggleMute() {
        container.videoPlayerManager.toggleMute()
        showToast(container.videoPlayerManager.isMuted ? "Muted" : "Unmuted")
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            toastMessage = message
        }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                toastMessage = nil
            }
        }
    }
}
