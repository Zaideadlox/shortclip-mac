import SwiftUI

struct AuthSheetView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isBusy = false

    private var viewModel: AuthViewModel {
        AuthViewModel(appState: appState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                TikTokLogoView(iconSize: 26, showWordmark: true)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(TTTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Sign in to TikTok")
                    .font(.system(size: 20, weight: .bold))
                Text("TikTok Desktop never asks for or stores your password. Choose one of the official, secure sign-in methods below.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TTTheme.textSecondary)
            }

            // Option 1: Authentic TikTok Web Session (Works immediately, no Developer key required)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("TikTok Web Session (Recommended)", systemImage: "globe")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TTTheme.textPrimary)
                    Spacer()
                    if appState.container.authService.session.hasWebSessionCookies {
                        CapabilityBadge(title: "Active", systemImage: "checkmark.circle.fill", tint: TTTheme.cyan)
                    }
                }

                Text("Sign in directly on tiktok.com inside the integrated macOS WebKit session (QR code, Passkey, Apple, Google, or TikTok account). Unlocks your real For You feed, Following, LIVE, and Messages in TikTok Web mode.")
                    .font(.system(size: 12))
                    .foregroundStyle(TTTheme.textSecondary)

                Button {
                    appState.openWebSignIn()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text(appState.container.authService.session.hasWebSessionCookies ? "Open TikTok Web Feed" : "Continue with TikTok Web Sign-In")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(TTTheme.pink)
            }
            .padding(16)
            .background(TTTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(TTTheme.separator, lineWidth: 1))

            // Option 2: Official TikTok Login Kit OAuth 2.0 + PKCE (Display API v2)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Official TikTok OAuth 2.0 + PKCE", systemImage: "lock.shield.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TTTheme.textPrimary)
                    Spacer()
                    if appState.container.authService.session.oauthUser != nil {
                        CapabilityBadge(title: "Connected", systemImage: "checkmark.seal.fill", tint: TTTheme.cyan)
                    } else {
                        CapabilityBadge(title: "Display API v2", systemImage: "key.fill", tint: TTTheme.textSecondary)
                    }
                }

                Text("Uses Apple's ASWebAuthenticationSession with PKCE (S256) and macOS Keychain storage to access your profile (/v2/user/info/) and public videos (/v2/video/list/).")
                    .font(.system(size: 12))
                    .foregroundStyle(TTTheme.textSecondary)

                TextField("TikTok Developer Client Key", text: Bindable(appState.container.preferences).tikTokClientKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12.5))

                HStack(spacing: 10) {
                    Button {
                        Task { await runOAuth() }
                    } label: {
                        HStack {
                            if isBusy || appState.container.authService.isAuthenticating {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "person.badge.key.fill")
                            }
                            Text("Authorize via TikTok OAuth")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)

                    if appState.container.authService.session.isSignedIn {
                        Button("Sign Out", role: .destructive) {
                            Task {
                                await viewModel.signOutAll()
                                statusMessage = "Signed out successfully."
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(16)
            .background(TTTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(TTTheme.separator, lineWidth: 1))

            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TTTheme.cyan)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TTTheme.pink)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(TTTheme.elevatedSurface)
    }

    private func runOAuth() async {
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }

        do {
            let user = try await appState.container.authService.signInWithOfficialOAuth(
                clientKey: appState.container.preferences.tikTokClientKey,
                redirectURI: appState.container.preferences.tikTokRedirectURI
            )
            statusMessage = "Connected as \(user.displayName) via TikTok OAuth 2.0."
            appState.showToast("Signed in as \(user.displayName)")

            let videos = (try? await appState.container.authService.fetchConnectedUserVideos()) ?? []
            if !videos.isEmpty {
                appState.container.feedRepository.mergeAuthenticatedUserVideos(videos)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
