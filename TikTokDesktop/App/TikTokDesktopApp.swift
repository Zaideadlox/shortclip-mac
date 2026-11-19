import AppKit
import SwiftUI

@main
struct TikTokDesktopApp: App {
    @State private var appState: AppState
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let container = DependencyContainer()
        _appState = State(initialValue: AppState(container: container))
    }

    var body: some Scene {
        WindowGroup("TikTok Desktop") {
            MainShellView(appState: appState)
                .frame(minWidth: 980, minHeight: 680)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    // Keep playing if Picture-in-Picture is active; otherwise pause when switching away
                    if !appState.container.videoPlayerManager.isPiPActive && appState.activeEngine == .nativeFeed {
                        // Allow audio/video pause only if window is hidden or minimized; keep responsive during active macOS use
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didHideNotification)) { _ in
                    if !appState.container.videoPlayerManager.isPiPActive {
                        appState.container.videoPlayerManager.pause()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1260, height: 840)
        .commands {
            AppCommands(appState: appState)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
