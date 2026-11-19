import CryptoKit
import Foundation
import Security

struct PKCEPair: Sendable {
    let verifier: String
    let challenge: String
    let state: String
}

enum PKCEHelper {
    /// Generates an RFC 7636 S256 PKCE verifier, challenge, and CSRF state token.
    static func generate() -> PKCEPair {
        let verifier = randomURLSafeString(byteCount: 48)
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncodedString()
        let state = randomURLSafeString(byteCount: 24)
        return PKCEPair(verifier: verifier, challenge: challenge, state: state)
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
