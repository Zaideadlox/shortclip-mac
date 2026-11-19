import AppKit
import SwiftUI

struct MainShellView: View {
    @Bindable var appState: AppState
    @State private var keyMonitor: Any?

    var body: some View {
        HStack(spacing: 0) {
            // Left: 220px Navigation Sidebar
            SidebarView(appState: appState)

            Divider().overlay(TTTheme.separator)

            // Right: Top Bar + Primary Content Canvas
            VStack(spacing: 0) {
                TopBarView(appState: appState)

                ZStack(alignment: .bottom) {
                    contentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if let toast = appState.toastMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(TTTheme.cyan)
                            Text(toast)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(TTTheme.elevatedSurface.opacity(0.95), in: Capsule())
                        .overlay(Capsule().strokeBorder(TTTheme.subtleBorder, lineWidth: 1))
                        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
                        .padding(.bottom, 22)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .background(TTTheme.canvas)
        .preferredColorScheme(appState.preferredColorScheme)
        .sheet(isPresented: $appState.isShowingAuthSheet) {
            AuthSheetView(appState: appState)
                .preferredColorScheme(appState.preferredColorScheme)
        }
        .sheet(isPresented: $appState.isShowingAddURLSheet) {
            AddTikTokURLSheet(oEmbedService: appState.container.oEmbedService) { resolvedVideo in
                appState.container.feedRepository.prependCustomVideo(resolvedVideo)
                appState.openVideoInFeed(resolvedVideo)
                appState.showToast("Added \"\(resolvedVideo.creatorDisplayName)\" to your feed")
            }
            .preferredColorScheme(appState.preferredColorScheme)
        }
        .sheet(item: $appState.shareTargetVideo) { video in
            ShareSheetView(video: video) {
                appState.showToast("Copied link to clipboard")
            }
            .preferredColorScheme(appState.preferredColorScheme)
        }
        .onChange(of: appState.container.webController.hasSessionCookies) { _, hasCookies in
            appState.container.authService.syncWebSessionStatus(hasCookies: hasCookies)
        }
        .onAppear {
            appState.container.notifications.requestAuthorizationIfNeeded()
            installKeyboardShortcutMonitor()
        }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
            }
        }
    }

    private func installKeyboardShortcutMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore when modifiers like Command/Control/Option are pressed (handled by Menu Bar)
            let relevantModifiers = event.modifierFlags.intersection([.command, .control, .option])
            guard relevantModifiers.isEmpty else { return event }

            // Never intercept keys while typing in a text field, search bar, or comment box
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            // Don't hijack keys when a modal sheet is open or when user is on Settings/Search/Web mode
            guard !appState.isShowingAuthSheet,
                  !appState.isShowingAddURLSheet,
                  appState.shareTargetVideo == nil,
                  appState.selectedDestination.supportsFeedView,
                  appState.activeEngine == .nativeFeed
            else {
                return event
            }

            switch event.keyCode {
            case 49: // Space
                appState.togglePlayPause()
                return nil
            case 126: // Up Arrow
                appState.previousVideo()
                return nil
            case 125: // Down Arrow
                appState.nextVideo()
                return nil
            case 46: // M
                appState.toggleMute()
                return nil
            default:
                return event
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch appState.selectedDestination {
        case .forYou, .following, .friends, .explore:
            FeedView(appState: appState)

        case .live:
            TikTokWebContainerView(
                controller: appState.container.webController,
                destination: .live,
                bannerMessage: "TikTok LIVE streams run through TikTok's authentic web experience (no public TikTok LIVE API is available).",
                onSwitchToNative: {
                    appState.setEngine(.nativeFeed)
                    appState.navigate(to: .forYou)
                }
            )

        case .messages:
            TikTokWebContainerView(
                controller: appState.container.webController,
                destination: .messages,
                bannerMessage: "TikTok Direct Messages require an authenticated TikTok Web session (no public messaging API is available).",
                onSwitchToNative: {
                    appState.setEngine(.nativeFeed)
                    appState.navigate(to: .forYou)
                }
            )

        case .search:
            SearchView(appState: appState)

        case .profile:
            ProfileView(appState: appState)

        case .settings:
            SettingsView(appState: appState)
        }
    }
}
