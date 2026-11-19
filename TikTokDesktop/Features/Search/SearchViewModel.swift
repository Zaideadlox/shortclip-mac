import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var selectedTab: SearchFilterTab = .top
    var isResolvingURL: Bool = false
    var urlError: String?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var query: String {
        appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isTikTokURLQuery: Bool {
        query.lowercased().contains("tiktok.com/") && query.lowercased().contains("/video/")
    }

    var matchingVideos: [VideoItem] {
        let all = appState.container.feedRepository.videos
        guard !query.isEmpty else { return all }
        let q = query.lowercased().replacingOccurrences(of: "#", with: "")
        return all.filter { video in
            video.description.lowercased().contains(q)
                || video.creatorUsername.lowercased().contains(q)
                || video.creatorDisplayName.lowercased().contains(q)
                || video.musicTitle.lowercased().contains(q)
                || video.hashtags.contains { $0.lowercased().contains(q) }
        }
    }

    var matchingCreators: [CreatorProfile] {
        let all = appState.container.feedRepository.creators
        guard !query.isEmpty else { return all }
        let q = query.lowercased().replacingOccurrences(of: "@", with: "")
        return all.filter { creator in
            creator.username.lowercased().contains(q)
                || creator.displayName.lowercased().contains(q)
                || creator.bio.lowercased().contains(q)
        }
    }

    var matchingHashtags: [HashtagSummary] {
        let all = appState.container.feedRepository.allHashtags()
        guard !query.isEmpty else { return all }
        let q = query.lowercased().replacingOccurrences(of: "#", with: "")
        return all.filter { $0.tag.lowercased().contains(q) }
    }
}
