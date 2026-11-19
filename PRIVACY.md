# Privacy Policy — ShortClip Mac (TikTok Desktop Client)

_Last updated: November 19, 2026_

## 1. Local-First Privacy
ShortClip Mac ("the Application") runs entirely locally on your macOS device. We do **not** operate external backend servers, analytics trackers, or third-party data collection pipelines.

## 2. Information Accessed via Official TikTok APIs
When you choose to authorize your account via TikTok Login Kit (OAuth 2.0 + PKCE):
- **Profile Information (`user.info.basic`)**: Used solely to display your TikTok display name, avatar, and profile statistics inside the app on your Mac.
- **Public Video List (`video.list`)**: Used solely to display your own public videos inside the app's Profile and Feed views.

## 3. Credentials & Storage
- The Application **never collects, sees, or stores your TikTok password**.
- OAuth access tokens are stored locally in your **macOS Keychain** (`Security.framework`).
- Web session cookies (when using TikTok Web mode) are managed directly by Apple's `WKWebsiteDataStore` on your device.
- Preferences and local bookmarks/likes are stored locally on your Mac.

## 4. Data Sharing & Deletion
- We do not sell, transfer, or share any user data with third parties.
- You can revoke access and delete all locally stored tokens, cookies, and session data at any time from **Settings → Clear TikTok Web Cookies** and **Disconnect OAuth**, or by revoking app access in your TikTok account settings.

## 5. Contact
For privacy questions, please open an issue in this repository.
