# TikTok Desktop — Native macOS Client

A standalone native macOS application built with **Swift 6**, **SwiftUI**, **AVFoundation / AVKit**, **WebKit**, and **MVVM architecture** targeting **macOS 14+ (Apple Silicon)**.

## Architecture

```text
TikTokDesktop/
├── App/                  # Entry point, AppState, DependencyContainer, Menu Bar Commands
├── Core/                 # DesignSystem (Theme, Typography), Extensions, Keychain, PKCE, Notifications
├── Models/               # VideoItem, CreatorProfile, NavigationDestination, AuthSession, AppPreferences
├── Services/
│   ├── TikTokAPI/        # Official TikTok Display API v2, Official oEmbed API, FeedRepository
│   ├── VideoPlayer/      # Native AVPlayer + AVPlayerLayer + AVPictureInPictureController
│   ├── WebEngine/        # Persistent WKWebView session for authentic TikTok Web browsing
│   └── Authentication/   # Official TikTok OAuth 2.0 + PKCE (ASWebAuthenticationSession + Keychain)
├── Components/           # Sidebar, TopBar, ActionRail, MetadataOverlay, Embed Player, Drawers, Sheets
├── Features/
│   ├── Feed/             # Vertical 9:16 video feed with smooth transitions, scrubbing & gestures
│   ├── Search/           # Creators, videos, hashtags, TikTok URL oEmbed import & Web Search
│   ├── Profile/          # Creator & user profiles with 9:16 video, favorites & liked grids
│   ├── Authentication/   # Dual secure sign-in (Official OAuth 2.0 PKCE + TikTok Web Session)
│   └── Settings/         # Appearance, playback, API configuration & capability matrix
└── Resources/            # Info.plist, Entitlements, AppIcon.appiconset, SampleMedia
```

## Official TikTok API Boundaries & Supported Capabilities

TikTok does not expose its algorithmic For You recommendation feed, LIVE streams, or Direct Messages through public APIs. TikTok Desktop strictly adheres to documented official interfaces — no unofficial endpoints, no credential harvesting, and no scraping:

| Capability | Implementation |
| --- | --- |
| Vertical 9:16 Playback, Looping, Volume, Scrubbing, Speed, Quality & Picture-in-Picture | Native `AVPlayer` / `AVKit` (`AVPictureInPictureController`) |
| Public TikTok Video URLs & Metadata | Official TikTok oEmbed API (`https://www.tiktok.com/oembed`) + Official Embedded Video Player v1 (`https://www.tiktok.com/player/v1/{video_id}`) with `x-tiktok-player` `postMessage` bridge |
| User Profile & User Video Sync | Official TikTok Login Kit OAuth 2.0 + PKCE (`ASWebAuthenticationSession`) + Display API v2 (`https://open.tiktokapis.com/v2/user/info/`, `/v2/video/list/`) with Keychain storage |
| Live Personalized For You Feed, LIVE, Messages & Live Search | Authentic TikTok Web session via persistent `WKWebView` inside the native macOS shell |

## Keyboard Shortcuts

- `Space`: Play / Pause
- `↑` / `↓`: Previous / Next Video
- `M`: Mute / Unmute
- `⌘ F`: Search
- `⌘ P`: Picture in Picture
- `⌘ ⇧ M`: Switch between Native Player and TikTok Web
- `⌘ N`: Add Public TikTok Video URL (oEmbed) or Direct Stream
- `⌘ 1` – `⌘ 7`: Navigate Sidebar Sections
- `⌘ ,`: Settings
- `⌃ ⌘ F`: Full Screen
- `⌘ Q`: Quit

## Building Standalone `.app`

```bash
./scripts/build_app.sh
open dist/TikTokDesktop.app
```

Or open `TikTokDesktop.xcodeproj` directly in Xcode.
