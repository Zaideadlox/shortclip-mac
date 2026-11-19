import AppKit
import AVFoundation
import SwiftUI

struct VerticalFeedCardView: View {
    let video: VideoItem
    let playerManager: NativeVideoPlayerManager
    let isFollowing: Bool
    let onTapCreator: () -> Void
    let onTapFollow: () -> Void
    let onTapLike: () -> Void
    let onTapComment: () -> Void
    let onTapBookmark: () -> Void
    let onTapShare: () -> Void
    let onTapHashtag: (String) -> Void

    @State private var isHoveringVideo = false
    @State private var showHeartBurst = false
    @State private var showPlayPausePulse = false
    @State private var showVolumeSlider = false
    @State private var isDraggingScrubber = false
    @State private var scrubFraction: Double = 0

    var body: some View {
        GeometryReader { geo in
            let maxCardHeight = max(min(geo.size.height - 28, 860), 380)
            let cardWidth = min(maxCardHeight * (9.0 / 16.0), max(geo.size.width - 120, 260))
            let cardHeight = cardWidth * (16.0 / 9.0)

            HStack(alignment: .bottom, spacing: 18) {
                Spacer(minLength: 0)

                // Center 9:16 Video Card
                ZStack {
                    videoSurface

                    // Gradient scrim for crisp typography legibility
                    if video.source.isNativeAVPlayer {
                        TTTheme.subtleVideoScrim
                            .allowsHitTesting(false)
                    }

                    // Double-click Heart Burst Animation
                    if showHeartBurst {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 86, weight: .bold))
                            .foregroundStyle(TTTheme.pink)
                            .shadow(color: TTTheme.pink.opacity(0.6), radius: 18)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }

                    // Play/Pause indicator flash
                    if showPlayPausePulse && video.source.isNativeAVPlayer {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.5))
                                .frame(width: 68, height: 68)
                            Image(systemName: playerManager.isPlaying ? "play.fill" : "pause.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                    }

                    // Buffering spinner
                    if playerManager.isBuffering && video.source.isNativeAVPlayer {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    }

                    // Top Controls Overlay (Mute/Volume, Engine Badge, PiP, Quality, Fullscreen)
                    VStack {
                        topControlsBar
                        Spacer()

                        // Bottom Metadata + Native Scrubber
                        VStack(spacing: 10) {
                            VideoMetadataOverlay(
                                video: video,
                                onTapCreator: onTapCreator,
                                onTapHashtag: onTapHashtag
                            )

                            if video.source.isNativeAVPlayer {
                                nativePlaybackBar
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: TTTheme.videoCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TTTheme.videoCornerRadius, style: .continuous)
                        .strokeBorder(TTTheme.subtleBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 28, y: 12)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isHoveringVideo = hovering
                        if !hovering {
                            showVolumeSlider = false
                        }
                    }
                }

                // Right-side Vertical Interaction Rail (matches Image #1)
                VideoActionRailView(
                    video: video,
                    isFollowing: isFollowing,
                    isPlaying: video.source.isNativeAVPlayer ? playerManager.isPlaying : true,
                    onTapCreator: onTapCreator,
                    onTapFollow: onTapFollow,
                    onTapLike: onTapLike,
                    onTapComment: onTapComment,
                    onTapBookmark: onTapBookmark,
                    onTapShare: onTapShare
                )
                .padding(.bottom, 14)

                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    @ViewBuilder
    private var videoSurface: some View {
        switch video.source {
        case .bundledMP4, .remoteStream:
            ZStack {
                Color.black
                NativeVideoPlayerView(manager: playerManager, videoGravity: .resizeAspectFill)

                // Invisible tap surface for single-click play/pause and double-click like
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        triggerHeartBurst()
                    }
                    .onTapGesture(count: 1) {
                        playerManager.togglePlayPause()
                        flashPlayPauseIndicator()
                    }

                if let error = playerManager.loadError {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(TTTheme.pink)
                        Text(error)
                            .font(TTTypography.caption)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(16)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                }
            }

        case .officialTikTokEmbed(let videoID, _, _):
            TikTokEmbedPlayerView(
                videoID: videoID,
                isActive: true,
                isMuted: playerManager.isMuted
            )
        }
    }

    private var topControlsBar: some View {
        HStack(spacing: 8) {
            // Mute + Hover Volume Slider (matches top-left mute icon in Image #1)
            HStack(spacing: 6) {
                Button {
                    playerManager.toggleMute()
                } label: {
                    Image(systemName: playerManager.isMuted || playerManager.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Mute / Unmute (M)")

                if showVolumeSlider && video.source.isNativeAVPlayer {
                    Slider(
                        value: Binding(
                            get: { Double(playerManager.volume) },
                            set: { playerManager.volume = Float($0) }
                        ),
                        in: 0...1
                    )
                    .tint(TTTheme.pink)
                    .frame(width: 78)
                    .padding(.trailing, 8)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(2)
            .background(showVolumeSlider ? Color.black.opacity(0.45) : Color.clear, in: Capsule())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.16)) {
                    showVolumeSlider = hovering
                }
            }

            Spacer()

            // Transparent Source Engine Badge
            CapabilityBadge(
                title: video.source.engineBadgeTitle,
                systemImage: video.source.isNativeAVPlayer ? "play.tv.fill" : "checkmark.shield.fill",
                tint: video.source.isNativeAVPlayer ? TTTheme.cyan : TTTheme.pink
            )

            // Native AVPlayer Controls (PiP, Quality/Speed Menu, Fullscreen)
            if video.source.isNativeAVPlayer {
                if playerManager.isPiPSupported {
                    Button {
                        playerManager.togglePictureInPicture()
                    } label: {
                        Image(systemName: playerManager.isPiPActive ? "pip.exit" : "pip.enter")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(playerManager.isPiPActive ? TTTheme.cyan : .white)
                            .frame(width: 32, height: 32)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Picture in Picture (⌘P)")
                }

                Menu {
                    Section("Playback Speed") {
                        ForEach([Float(0.75), 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                            Button {
                                playerManager.playbackRate = rate
                            } label: {
                                if playerManager.playbackRate == rate {
                                    Label("\(String(format: "%g", rate))x", systemImage: "checkmark")
                                } else {
                                    Text("\(String(format: "%g", rate))x")
                                }
                            }
                        }
                    }

                    Section("Adaptive Quality") {
                        ForEach(VideoQualityPreference.allCases) { quality in
                            Button {
                                playerManager.qualityPreference = quality
                            } label: {
                                if playerManager.qualityPreference == quality {
                                    Label(quality.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(quality.rawValue)
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        NSApplication.shared.keyWindow?.toggleFullScreen(nil)
                    } label: {
                        Label("Toggle Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Playback Options")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private var nativePlaybackBar: some View {
        HStack(spacing: 10) {
            Button {
                playerManager.togglePlayPause()
                flashPlayPauseIndicator()
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            // Interactive Scrubber
            GeometryReader { barGeo in
                let activeProgress = isDraggingScrubber ? scrubFraction : playerManager.progress
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.24))
                        .frame(height: isHoveringVideo || isDraggingScrubber ? 5 : 3)

                    Capsule()
                        .fill(TTTheme.brandGradient)
                        .frame(width: max(barGeo.size.width * activeProgress, 0), height: isHoveringVideo || isDraggingScrubber ? 5 : 3)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingScrubber = true
                            scrubFraction = min(max(value.location.x / max(barGeo.size.width, 1), 0), 1)
                        }
                        .onEnded { value in
                            let fraction = min(max(value.location.x / max(barGeo.size.width, 1), 0), 1)
                            playerManager.seek(toFraction: fraction)
                            isDraggingScrubber = false
                        }
                )
            }
            .frame(height: 16)

            Text("\(playerManager.currentTime.formattedDuration) / \(playerManager.duration.formattedDuration)")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.45), in: Capsule())
    }

    private func triggerHeartBurst() {
        if !video.isLiked {
            onTapLike()
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            showHeartBurst = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeOut(duration: 0.25)) {
                showHeartBurst = false
            }
        }
    }

    private func flashPlayPauseIndicator() {
        withAnimation(.easeOut(duration: 0.14)) {
            showPlayPausePulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.22)) {
                showPlayPausePulse = false
            }
        }
    }
}
