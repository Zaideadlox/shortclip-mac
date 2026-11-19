import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var preferences: AppPreferences {
        appState.container.preferences
    }

    func applyPlaybackPreferences() {
        let player = appState.container.videoPlayerManager
        player.loopEnabled = preferences.loopVideosEnabled
        player.volume = preferences.volume
        player.qualityPreference = preferences.qualityPreference
    }

    func clearWebSession() async {
        await appState.container.webController.clearWebSession()
        appState.container.authService.syncWebSessionStatus(hasCookies: false)
        appState.showToast("Cleared TikTok web cookies and cache")
    }

    func signOutOAuth() {
        appState.container.authService.signOutOAuth()
        appState.showToast("Disconnected TikTok OAuth session")
    }
}
