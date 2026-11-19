import AppKit
import AuthenticationServices
import Foundation
import Observation

enum AuthError: LocalizedError, Sendable {
    case missingClientKey
    case invalidRedirectURI
    case cancelled
    case stateMismatch
    case missingAuthorizationCode

    var errorDescription: String? {
        switch self {
        case .missingClientKey:
            return "Enter your TikTok Developer Client Key first (available at developers.tiktok.com), or sign in via the authentic TikTok Web Session."
        case .invalidRedirectURI:
            return "The configured OAuth Redirect URI is invalid."
        case .cancelled:
            return "TikTok sign-in was cancelled."
        case .stateMismatch:
            return "Security state validation failed. Please try signing in again."
        case .missingAuthorizationCode:
            return "TikTok did not return an authorization code."
        }
    }
}

/// Manages official TikTok OAuth 2.0 + PKCE authentication (`ASWebAuthenticationSession`),
/// secure Keychain token persistence, and TikTok Web session state.
/// Never collects or stores user passwords.
@MainActor
@Observable
final class TikTokAuthService: NSObject {
    private(set) var session = AuthSession()
    private(set) var isAuthenticating: Bool = false
    private(set) var lastError: String?

    private let apiClient: TikTokAPIClient
    private let keychain: KeychainService
    private let tokenKey = "tiktok_oauth_token_v2"
    private let userKey = "tiktok_oauth_user_v2"
    private var activeWebAuthSession: ASWebAuthenticationSession?

    init(apiClient: TikTokAPIClient, keychain: KeychainService) {
        self.apiClient = apiClient
        self.keychain = keychain
        super.init()
        restoreSavedOAuthSession()
    }

    func syncWebSessionStatus(hasCookies: Bool) {
        session.hasWebSessionCookies = hasCookies
        if session.oauthUser == nil {
            session.method = hasCookies ? .webSession : .none
        }
    }

    /// Launches Official TikTok Login Kit OAuth 2.0 with PKCE via `ASWebAuthenticationSession`.
    func signInWithOfficialOAuth(clientKey: String, redirectURI: String) async throws -> TikTokAPIUser {
        let trimmedKey = clientKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = AuthError.missingClientKey.localizedDescription
            throw AuthError.missingClientKey
        }
        guard let redirectURL = URL(string: redirectURI), let callbackScheme = redirectURL.scheme else {
            lastError = AuthError.invalidRedirectURI.localizedDescription
            throw AuthError.invalidRedirectURI
        }

        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        let pkce = PKCEHelper.generate()
        var authComponents = URLComponents(string: "https://www.tiktok.com/v2/auth/authorize/")!
        authComponents.queryItems = [
            URLQueryItem(name: "client_key", value: trimmedKey),
            URLQueryItem(name: "scope", value: "user.info.basic,video.list"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: pkce.state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authorizeURL = authComponents.url else {
            throw AuthError.invalidRedirectURI
        }

        let callbackURL = try await startWebAuthenticationSession(url: authorizeURL, callbackScheme: callbackScheme)
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let returnedState = components?.queryItems?.first(where: { $0.name == "state" })?.value
        guard returnedState == pkce.state else {
            throw AuthError.stateMismatch
        }
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw AuthError.missingAuthorizationCode
        }

        let token = try await apiClient.exchangeAuthorizationCode(
            code: code,
            codeVerifier: pkce.verifier,
            clientKey: trimmedKey,
            redirectURI: redirectURI
        )
        try keychain.saveCodable(token, forKey: tokenKey)

        let user = try await apiClient.fetchUserInfo(accessToken: token.accessToken)
        try? keychain.saveCodable(user, forKey: userKey)

        session.oauthUser = user
        session.method = .officialOAuth
        session.connectedScopes = token.scope.split(separator: ",").map(String.init)
        return user
    }

    func fetchConnectedUserVideos() async throws -> [VideoItem] {
        guard let token = try keychain.loadCodable(TikTokOAuthToken.self, forKey: tokenKey), !token.isExpired else {
            return []
        }
        return try await apiClient.fetchUserVideos(accessToken: token.accessToken)
    }

    func signOutOAuth() {
        keychain.delete(forKey: tokenKey)
        keychain.delete(forKey: userKey)
        session.oauthUser = nil
        session.connectedScopes = []
        session.method = session.hasWebSessionCookies ? .webSession : .none
    }

    private func restoreSavedOAuthSession() {
        guard let token = try? keychain.loadCodable(TikTokOAuthToken.self, forKey: tokenKey), !token.isExpired else {
            return
        }
        if let cachedUser = try? keychain.loadCodable(TikTokAPIUser.self, forKey: userKey) {
            session.oauthUser = cachedUser
            session.method = .officialOAuth
            session.connectedScopes = token.scope.split(separator: ",").map(String.init)
        }
    }

    private func startWebAuthenticationSession(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error {
                    let nsErr = error as NSError
                    if nsErr.domain == ASWebAuthenticationSessionErrorDomain,
                       nsErr.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.missingAuthorizationCode)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.activeWebAuthSession = authSession
            authSession.start()
        }
    }
}

extension TikTokAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
        }
    }
}
