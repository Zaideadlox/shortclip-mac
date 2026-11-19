import Foundation

@MainActor
final class DependencyContainer {
    let preferences: AppPreferences
    let keychain: KeychainService
    let notifications: NotificationService
    let oEmbedService: TikTokOEmbedService
    let apiClient: TikTokAPIClient
    let feedRepository: FeedRepository
    let videoPlayerManager: NativeVideoPlayerManager
    let webController: TikTokWebController
    let authService: TikTokAuthService

    init() {
        self.preferences = AppPreferences()
        self.keychain = KeychainService()
        self.notifications = NotificationService()
        self.oEmbedService = TikTokOEmbedService()
        self.apiClient = TikTokAPIClient()
        self.feedRepository = FeedRepository()
        self.videoPlayerManager = NativeVideoPlayerManager()
        self.webController = TikTokWebController()
        self.authService = TikTokAuthService(apiClient: apiClient, keychain: keychain)

        // Sync initial player preferences
        videoPlayerManager.isMuted = preferences.startMuted
        videoPlayerManager.volume = preferences.volume
        videoPlayerManager.loopEnabled = preferences.loopVideosEnabled
        videoPlayerManager.qualityPreference = preferences.qualityPreference
    }
}
