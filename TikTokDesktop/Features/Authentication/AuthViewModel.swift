import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    var statusMessage: String?
    var errorMessage: String?
    var isSyncingVideos: Bool = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var session: AuthSession {
        appState.container.authService.session
    }

    var isAuthenticating: Bool {
        appState.container.authService.isAuthenticating
    }

    var hasClientKey: Bool {
        !appState.container.preferences.tikTokClientKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func signInWithOfficialOAuth() async {
        errorMessage = nil
        statusMessage = nil

        do {
            let user = try await appState.container.authService.signInWithOfficialOAuth(
                clientKey: appState.container.preferences.tikTokClientKey,
                redirectURI: appState.container.preferences.tikTokRedirectURI
            )
            statusMessage = "Signed in as \(user.displayName) via TikTok OAuth 2.0."
            appState.container.notifications.post(
                title: "TikTok Connected",
                body: "Signed in as \(user.displayName) using official TikTok OAuth.",
                enabled: appState.container.preferences.enableNotifications
            )

            isSyncingVideos = true
            let apiVideos = (try? await appState.container.authService.fetchConnectedUserVideos()) ?? []
            if !apiVideos.isEmpty {
                appState.container.feedRepository.mergeAuthenticatedUserVideos(apiVideos)
                statusMessage = "Signed in as \(user.displayName) • Loaded \(apiVideos.count) public videos."
            }
            isSyncingVideos = false
        } catch {
            isSyncingVideos = false
            errorMessage = error.localizedDescription
        }
    }

    func signOutAll() async {
        appState.container.authService.signOutOAuth()
        await appState.container.webController.clearWebSession()
        appState.container.authService.syncWebSessionStatus(hasCookies: false)
        statusMessage = "Signed out and cleared local session tokens & cookies."
        appState.showToast("Signed out of TikTok Desktop")
    }
}
