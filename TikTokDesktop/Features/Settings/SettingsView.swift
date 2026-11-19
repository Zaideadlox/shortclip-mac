import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    private var viewModel: SettingsViewModel {
        SettingsViewModel(appState: appState)
    }

    var body: some View {
        let prefs = Bindable(appState.container.preferences)

        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(TTTheme.textPrimary)
                    Text("Customize playback, appearance, official TikTok API integration, and macOS shortcuts.")
                        .font(TTTypography.body)
                        .foregroundStyle(TTTheme.textSecondary)
                }

                // Appearance & Default Experience
                settingsCard(title: "Appearance & Browsing Mode", icon: "paintbrush.fill", tint: TTTheme.pink) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Appearance")
                                .font(TTTypography.sectionTitle)
                            Text("Dark mode is default for TikTok Desktop.")
                                .font(TTTypography.caption)
                                .foregroundStyle(TTTheme.textTertiary)
                        }
                        Spacer()
                        Picker("", selection: prefs.appearanceMode) {
                            ForEach(AppAppearanceMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    Divider().overlay(TTTheme.separator)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Feed Engine")
                                .font(TTTypography.sectionTitle)
                            Text("Choose whether For You launches in Native AVPlayer or TikTok Web.")
                                .font(TTTypography.caption)
                                .foregroundStyle(TTTheme.textTertiary)
                        }
                        Spacer()
                        Picker("", selection: prefs.defaultEngine) {
                            ForEach(BrowsingEngine.allCases) { engine in
                                Text(engine.rawValue).tag(engine)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }

                    Divider().overlay(TTTheme.separator)

                    Toggle(isOn: prefs.enableNotifications) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("macOS Notifications")
                                .font(TTTypography.sectionTitle)
                            Text("Show native notifications for sign-in and media events.")
                                .font(TTTypography.caption)
                                .foregroundStyle(TTTheme.textTertiary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(TTTheme.pink)
                }

                // Video Playback Preferences
                settingsCard(title: "Native Video Player (AVFoundation)", icon: "play.rectangle.fill", tint: TTTheme.cyan) {
                    Toggle("Auto-play active videos", isOn: prefs.autoPlayEnabled)
                        .toggleStyle(.switch)
                        .tint(TTTheme.pink)

                    Toggle("Loop videos continuously", isOn: prefs.loopVideosEnabled)
                        .toggleStyle(.switch)
                        .tint(TTTheme.pink)
                        .onChange(of: appState.container.preferences.loopVideosEnabled) { _, _ in
                            viewModel.applyPlaybackPreferences()
                        }

                    Toggle("Start videos muted", isOn: prefs.startMuted)
                        .toggleStyle(.switch)
                        .tint(TTTheme.pink)

                    Divider().overlay(TTTheme.separator)

                    HStack {
                        Text("Default Volume")
                            .font(TTTypography.sectionTitle)
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { Double(appState.container.preferences.volume) },
                                set: {
                                    appState.container.preferences.volume = Float($0)
                                    viewModel.applyPlaybackPreferences()
                                }
                            ),
                            in: 0...1
                        )
                        .tint(TTTheme.cyan)
                        .frame(width: 180)
                        Text("\(Int(appState.container.preferences.volume * 100))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(TTTheme.textSecondary)
                            .frame(width: 40, alignment: .trailing)
                    }

                    HStack {
                        Text("Adaptive Video Quality")
                            .font(TTTypography.sectionTitle)
                        Spacer()
                        Picker("", selection: prefs.qualityPreference) {
                            ForEach(VideoQualityPreference.allCases) { quality in
                                Text(quality.rawValue).tag(quality)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                        .onChange(of: appState.container.preferences.qualityPreference) { _, _ in
                            viewModel.applyPlaybackPreferences()
                        }
                    }
                }

                // Official TikTok API & Session Security
                settingsCard(title: "Official TikTok API & Session Security", icon: "lock.shield.fill", tint: TTTheme.cyan) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TikTok Developer Client Key (Display API v2 / Login Kit)")
                            .font(TTTypography.caption)
                            .foregroundStyle(TTTheme.textSecondary)
                        TextField("Optional: paste Client Key from developers.tiktok.com", text: prefs.tikTokClientKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("OAuth Redirect URI")
                            .font(TTTypography.caption)
                            .foregroundStyle(TTTheme.textSecondary)
                        TextField("tiktokdesktop://oauth/callback", text: prefs.tikTokRedirectURI)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 12) {
                        Button("Manage Sign-In...") {
                            appState.isShowingAuthSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TTTheme.pink)

                        Button("Clear TikTok Web Cookies") {
                            Task { await viewModel.clearWebSession() }
                        }
                        .buttonStyle(.bordered)

                        if appState.container.authService.session.oauthUser != nil {
                            Button("Disconnect OAuth", role: .destructive) {
                                viewModel.signOutOAuth()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 4)
                }

                // Platform Capabilities Matrix (Transparent API separation per Section 6)
                settingsCard(title: "Platform Capabilities & Official API Boundaries", icon: "checkmark.seal.fill", tint: TTTheme.pink) {
                    capabilityRow(
                        feature: "Native 9:16 Vertical Feed, PiP, Volume, Scrubbing & Looping",
                        implementation: "Native AVPlayer / AVKit",
                        color: TTTheme.cyan
                    )
                    capabilityRow(
                        feature: "Public TikTok Video Links & Metadata",
                        implementation: "Official oEmbed API + Player v1",
                        color: TTTheme.cyan
                    )
                    capabilityRow(
                        feature: "Account Profile & User Videos Sync",
                        implementation: "Official OAuth 2.0 PKCE + Display API v2",
                        color: TTTheme.cyan
                    )
                    capabilityRow(
                        feature: "Full Personalized For You Feed, LIVE Streams, Messages & Live Search",
                        implementation: "Authentic TikTok Web (WKWebView)",
                        color: TTTheme.pink
                    )

                    Text("TikTok does not expose its algorithmic For You feed, LIVE streams, or Direct Messages via public APIs. TikTok Desktop uses zero unofficial endpoints or scraping — combining native AVPlayer + official TikTok APIs with an integrated authenticated WKWebView session.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TTTheme.textTertiary)
                        .padding(.top, 4)
                }

                // Keyboard Shortcuts Reference
                settingsCard(title: "macOS Keyboard Shortcuts", icon: "keyboard.fill", tint: TTTheme.textPrimary) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        shortcutRow("Play / Pause", keys: "Space")
                        shortcutRow("Next Video", keys: "↓")
                        shortcutRow("Previous Video", keys: "↑")
                        shortcutRow("Search", keys: "⌘ F")
                        shortcutRow("Mute / Unmute", keys: "M")
                        shortcutRow("Picture in Picture", keys: "⌘ P")
                        shortcutRow("Switch Native / Web", keys: "⌘ ⇧ M")
                        shortcutRow("Quit App", keys: "⌘ Q")
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 880, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TTTheme.canvas)
    }

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(TTTheme.separator, lineWidth: 1))
    }

    private func capabilityRow(feature: String, implementation: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(feature)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(TTTheme.textPrimary)
            Spacer()
            Text(implementation)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color.opacity(0.14), in: Capsule())
        }
    }

    private func shortcutRow(_ label: String, keys: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(TTTheme.textSecondary)
            Spacer()
            Text(keys)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(TTTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(TTTheme.cardSurface, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(TTTheme.separator, lineWidth: 1))
        }
        .padding(.vertical, 2)
    }
}
