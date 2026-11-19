import AppKit
import SwiftUI
import WebKit

/// Renders TikTok's official Embedded Video Player v1 (`https://www.tiktok.com/player/v1/{videoID}`)
/// inside a dedicated WKWebView and communicates via TikTok's documented `x-tiktok-player` postMessage protocol.
struct TikTokEmbedPlayerView: NSViewRepresentable {
    let videoID: String
    let isActive: Bool
    let isMuted: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        loadEmbedHTML(in: webView, videoID: videoID, autoPlay: isActive, muted: isMuted)
        context.coordinator.loadedVideoID = videoID
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            loadEmbedHTML(in: nsView, videoID: videoID, autoPlay: isActive, muted: isMuted)
            return
        }

        if context.coordinator.lastActive != isActive {
            context.coordinator.lastActive = isActive
            context.coordinator.sendCommand(type: isActive ? "play" : "pause", value: "true")
        }

        if context.coordinator.lastMuted != isMuted {
            context.coordinator.lastMuted = isMuted
            context.coordinator.sendCommand(type: isMuted ? "mute" : "unMute", value: "true")
        }
    }

    private func loadEmbedHTML(in webView: WKWebView, videoID: String, autoPlay: Bool, muted: Bool) {
        let safeID = videoID.filter(\.isNumber)
        let autoplayParam = autoPlay ? "1" : "0"
        let mutedParam = muted ? "1" : "0"
        let src = "https://www.tiktok.com/player/v1/\(safeID)?autoplay=\(autoplayParam)&muted=\(mutedParam)&controls=1&loop=1&description=0&music_info=0&rel=0"

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            html, body {
                margin: 0;
                padding: 0;
                width: 100%;
                height: 100%;
                background: #09090B;
                overflow: hidden;
            }
            iframe {
                width: 100%;
                height: 100%;
                border: 0;
                display: block;
            }
        </style>
        </head>
        <body>
            <iframe id="tt-player"
                src="\(src)"
                allow="autoplay; fullscreen; picture-in-picture; encrypted-media"
                allowfullscreen>
            </iframe>
            <script>
                window.sendTikTokCommand = function(type, value) {
                    const frame = document.getElementById('tt-player');
                    if (frame && frame.contentWindow) {
                        frame.contentWindow.postMessage({
                            'x-tiktok-player': true,
                            type: type,
                            value: value
                        }, 'https://www.tiktok.com');
                    }
                };
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.tiktok.com"))
    }

    @MainActor
    final class Coordinator {
        weak var webView: WKWebView?
        var loadedVideoID: String = ""
        var lastActive: Bool = true
        var lastMuted: Bool = false

        func sendCommand(type: String, value: String) {
            let js = "window.sendTikTokCommand && window.sendTikTokCommand('\(type)', \(value));"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
