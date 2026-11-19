import AppKit
import SwiftUI

struct FeedView: View {
    @Bindable var appState: AppState
    @State private var transitionEdge: Edge = .bottom

    private var viewModel: FeedViewModel {
        FeedViewModel(appState: appState)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                TTTheme.canvas

                if appState.activeEngine == .tikTokWeb {
                    TikTokWebContainerView(
                        controller: appState.container.webController,
                        destination: appState.selectedDestination,
                        bannerMessage: nil,
                        onSwitchToNative: {
                            appState.setEngine(.nativeFeed)
                        }
                    )
                } else if let video = viewModel.currentVideo {
                    // Trackpad/Mouse Wheel Vertical Paging Listener
                    ScrollWheelListenerView(
                        onScrollDown: {
                            navigateNext()
                        },
                        onScrollUp: {
                            navigatePrevious()
                        }
                    )

                    VerticalFeedCardView(
                        video: video,
                        playerManager: viewModel.playerManager,
                        isFollowing: viewModel.isFollowing(creatorID: video.creatorID),
                        onTapCreator: {
                            appState.openCreatorProfile(creatorID: video.creatorID)
                        },
                        onTapFollow: {
                            viewModel.toggleFollow(creatorID: video.creatorID)
                        },
                        onTapLike: {
                            viewModel.toggleLike(for: video)
                        },
                        onTapComment: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                appState.isShowingCommentsDrawer.toggle()
                            }
                        },
                        onTapBookmark: {
                            viewModel.toggleBookmark(for: video)
                        },
                        onTapShare: {
                            appState.shareTargetVideo = video
                        },
                        onTapHashtag: { hashtag in
                            appState.triggerSearch(query: hashtag)
                        }
                    )
                    .id(video.id)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: transitionEdge).combined(with: .opacity),
                            removal: .move(edge: transitionEdge == .bottom ? .top : .bottom).combined(with: .opacity)
                        )
                    )

                    // Floating Right-Edge Desktop Feed Up/Down Controls
                    VStack(spacing: 12) {
                        Button {
                            navigatePrevious()
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(viewModel.canGoPrevious ? .white : TTTheme.textTertiary)
                                .frame(width: 42, height: 42)
                                .background(TTTheme.elevatedSurface, in: Circle())
                                .overlay(Circle().strokeBorder(TTTheme.separator, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canGoPrevious)
                        .help("Previous Video (↑)")

                        Text("\(viewModel.currentIndex + 1)/\(viewModel.videos.count)")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(TTTheme.textTertiary)

                        Button {
                            navigateNext()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(viewModel.canGoNext ? .white : TTTheme.textTertiary)
                                .frame(width: 42, height: 42)
                                .background(TTTheme.elevatedSurface, in: Circle())
                                .overlay(Circle().strokeBorder(TTTheme.separator, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canGoNext)
                        .help("Next Video (↓)")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 20)
                } else {
                    emptyFeedView
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: appState.activeVideoID)

            // Native Comments Side Drawer
            if appState.isShowingCommentsDrawer,
               appState.activeEngine == .nativeFeed,
               let activeVideo = viewModel.currentVideo {
                CommentsDrawerView(
                    video: activeVideo,
                    comments: appState.container.feedRepository.comments(for: activeVideo.id),
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.isShowingCommentsDrawer = false
                        }
                    },
                    onPostComment: { text in
                        let displayName = appState.container.authService.session.oauthUser?.displayName ?? "You"
                        let username = appState.container.authService.session.oauthUser?.username ?? "mac_viewer"
                        appState.container.feedRepository.addComment(
                            to: activeVideo.id,
                            text: text,
                            authorName: displayName,
                            authorUsername: username
                        )
                    },
                    onLikeComment: { commentID in
                        appState.container.feedRepository.toggleCommentLike(videoID: activeVideo.id, commentID: commentID)
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .onAppear {
            viewModel.syncPlaybackForCurrentVideo()
        }
        .onDisappear {
            viewModel.playerManager.pause()
        }
        .onChange(of: appState.activeVideoID) { _, _ in
            viewModel.syncPlaybackForCurrentVideo()
        }
        .onChange(of: appState.selectedDestination) { _, _ in
            viewModel.syncPlaybackForCurrentVideo()
        }
        .onChange(of: appState.activeEngine) { _, _ in
            viewModel.syncPlaybackForCurrentVideo()
        }
    }

    private func navigateNext() {
        guard viewModel.canGoNext else { return }
        transitionEdge = .bottom
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            viewModel.goNext()
        }
    }

    private func navigatePrevious() {
        guard viewModel.canGoPrevious else { return }
        transitionEdge = .top
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            viewModel.goPrevious()
        }
    }

    private var emptyFeedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "film.stack")
                .font(.system(size: 36))
                .foregroundStyle(TTTheme.textTertiary)
            Text("No videos in this feed yet")
                .font(TTTypography.pageTitle)
                .foregroundStyle(TTTheme.textPrimary)
            HStack(spacing: 12) {
                Button("Add TikTok URL") {
                    appState.isShowingAddURLSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(TTTheme.pink)

                Button("Switch to TikTok Web") {
                    appState.setEngine(.tikTokWeb)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

/// Captures trackpad & mouse vertical scroll-wheel gestures to switch videos smoothly
/// without interfering with child controls or drawers.
private struct ScrollWheelListenerView: NSViewRepresentable {
    let onScrollDown: () -> Void
    let onScrollUp: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrollDown: onScrollDown, onScrollUp: onScrollUp)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.installMonitor(attachedTo: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onScrollDown = onScrollDown
        context.coordinator.onScrollUp = onScrollUp
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    @MainActor
    final class Coordinator {
        var onScrollDown: () -> Void
        var onScrollUp: () -> Void
        private weak var attachedView: NSView?
        private var monitor: Any?
        private var lastTriggerDate: Date = .distantPast
        private var accumulatedDelta: CGFloat = 0

        init(onScrollDown: @escaping () -> Void, onScrollUp: @escaping () -> Void) {
            self.onScrollDown = onScrollDown
            self.onScrollUp = onScrollUp
        }

        func installMonitor(attachedTo view: NSView) {
            self.attachedView = view
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let view = self.attachedView, let window = view.window else {
                    return event
                }
                guard event.window === window else { return event }
                let locInView = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(locInView) else { return event }

                let dy = event.scrollingDeltaY
                guard abs(dy) > 1.5 else { return event }

                let now = Date()
                if now.timeIntervalSince(self.lastTriggerDate) < 0.42 {
                    return nil
                }

                self.accumulatedDelta += dy
                let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 36 : 4

                if self.accumulatedDelta <= -threshold {
                    self.accumulatedDelta = 0
                    self.lastTriggerDate = now
                    self.onScrollDown()
                    return nil
                } else if self.accumulatedDelta >= threshold {
                    self.accumulatedDelta = 0
                    self.lastTriggerDate = now
                    self.onScrollUp()
                    return nil
                }

                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
