import Foundation
import Observation

@MainActor
@Observable
final class AppPreferences {
    private let defaults: UserDefaults

    var appearanceMode: AppAppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    var defaultEngine: BrowsingEngine {
        didSet { defaults.set(defaultEngine.rawValue, forKey: Keys.defaultEngine) }
    }

    var autoPlayEnabled: Bool {
        didSet { defaults.set(autoPlayEnabled, forKey: Keys.autoPlayEnabled) }
    }

    var loopVideosEnabled: Bool {
        didSet { defaults.set(loopVideosEnabled, forKey: Keys.loopVideosEnabled) }
    }

    var startMuted: Bool {
        didSet { defaults.set(startMuted, forKey: Keys.startMuted) }
    }

    var volume: Float {
        didSet { defaults.set(volume, forKey: Keys.volume) }
    }

    var qualityPreference: VideoQualityPreference {
        didSet { defaults.set(qualityPreference.rawValue, forKey: Keys.qualityPreference) }
    }

    var enableNotifications: Bool {
        didSet { defaults.set(enableNotifications, forKey: Keys.enableNotifications) }
    }

    var tikTokClientKey: String {
        didSet { defaults.set(tikTokClientKey, forKey: Keys.tikTokClientKey) }
    }

    var tikTokRedirectURI: String {
        didSet { defaults.set(tikTokRedirectURI, forKey: Keys.tikTokRedirectURI) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appearanceMode = AppAppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "") ?? .dark
        self.defaultEngine = BrowsingEngine(rawValue: defaults.string(forKey: Keys.defaultEngine) ?? "") ?? .nativeFeed
        self.autoPlayEnabled = defaults.object(forKey: Keys.autoPlayEnabled) as? Bool ?? true
        self.loopVideosEnabled = defaults.object(forKey: Keys.loopVideosEnabled) as? Bool ?? true
        self.startMuted = defaults.object(forKey: Keys.startMuted) as? Bool ?? false
        self.volume = defaults.object(forKey: Keys.volume) as? Float ?? 0.85
        self.qualityPreference = VideoQualityPreference(rawValue: defaults.string(forKey: Keys.qualityPreference) ?? "") ?? .auto
        self.enableNotifications = defaults.object(forKey: Keys.enableNotifications) as? Bool ?? true
        self.tikTokClientKey = defaults.string(forKey: Keys.tikTokClientKey) ?? ""
        self.tikTokRedirectURI = defaults.string(forKey: Keys.tikTokRedirectURI) ?? "tiktokdesktop://oauth/callback"
    }

    private enum Keys {
        static let appearanceMode = "tt.appearanceMode"
        static let defaultEngine = "tt.defaultEngine"
        static let autoPlayEnabled = "tt.autoPlayEnabled"
        static let loopVideosEnabled = "tt.loopVideosEnabled"
        static let startMuted = "tt.startMuted"
        static let volume = "tt.volume"
        static let qualityPreference = "tt.qualityPreference"
        static let enableNotifications = "tt.enableNotifications"
        static let tikTokClientKey = "tt.oauth.clientKey"
        static let tikTokRedirectURI = "tt.oauth.redirectURI"
    }
}
