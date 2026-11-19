import AppKit
import SwiftUI

struct SearchView: View {
    @Bindable var appState: AppState
    @State private var selectedTab: SearchFilterTab = .top
    @State private var isResolvingURL = false
    @State private var resolveError: String?

    private var viewModel: SearchViewModel {
        SearchViewModel(appState: appState)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Subheader & Filter Tabs
            HStack(spacing: 12) {
                ForEach(SearchFilterTab.allCases) { tab in
                    let active = selectedTab == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selectedTab = tab
                        }
                        if tab == .webSearch {
                            appState.container.webController.loadSearch(query: appState.searchQuery)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if tab == .webSearch {
                                Image(systemName: "globe")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(active ? .white : TTTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(active ? TTTheme.pink : TTTheme.elevatedSurface, in: Capsule())
                        .overlay(Capsule().strokeBorder(active ? Color.clear : TTTheme.separator, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if selectedTab != .webSearch {
                    Button {
                        selectedTab = .webSearch
                        appState.container.webController.loadSearch(query: appState.searchQuery)
                    } label: {
                        Label("Search Live on TikTok Web", systemImage: "arrow.up.right.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TTTheme.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(TTTheme.canvas)

            Divider().overlay(TTTheme.separator)

            if selectedTab == .webSearch {
                TikTokWebContainerView(
                    controller: appState.container.webController,
                    destination: .search,
                    bannerMessage: "Searching live public results on TikTok Web (TikTok's public Display API does not provide a global search endpoint).",
                    onSwitchToNative: {
                        selectedTab = .top
                    }
                )
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 24) {
                        if viewModel.isTikTokURLQuery {
                            HStack(spacing: 14) {
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 20))
                                    .foregroundStyle(TTTheme.cyan)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Public TikTok Video URL Detected")
                                        .font(TTTypography.sectionTitle)
                                    Text("Fetch metadata via TikTok's official oEmbed API and open directly in the vertical player.")
                                        .font(TTTypography.caption)
                                        .foregroundStyle(TTTheme.textSecondary)
                                }
                                Spacer()
                                Button {
                                    Task { await resolveURL() }
                                } label: {
                                    if isResolvingURL {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text("Open Video")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(TTTheme.pink)
                            }
                            .padding(16)
                            .background(TTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(TTTheme.cyan.opacity(0.35), lineWidth: 1))
                        }

                        if let resolveError {
                            Text(resolveError)
                                .font(TTTypography.caption)
                                .foregroundStyle(TTTheme.pink)
                        }

                        if (selectedTab == .top || selectedTab == .creators), !viewModel.matchingCreators.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Creators")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(TTTheme.textPrimary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 340), spacing: 14)], spacing: 14) {
                                    ForEach(viewModel.matchingCreators) { creator in
                                        creatorCard(creator)
                                    }
                                }
                            }
                        }

                        if (selectedTab == .top || selectedTab == .hashtags), !viewModel.matchingHashtags.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Hashtags")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(TTTheme.textPrimary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 12)], spacing: 12) {
                                    ForEach(viewModel.matchingHashtags) { summary in
                                        Button {
                                            appState.searchQuery = "#\(summary.tag)"
                                            selectedTab = .videos
                                        } label: {
                                            HStack(spacing: 10) {
                                                ZStack {
                                                    Circle()
                                                        .fill(TTTheme.pink.opacity(0.16))
                                                        .frame(width: 34, height: 34)
                                                    Text("#")
                                                        .font(.system(size: 16, weight: .black))
                                                        .foregroundStyle(TTTheme.pink)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("#\(summary.tag)")
                                                        .font(.system(size: 13.5, weight: .bold))
                                                        .foregroundStyle(TTTheme.textPrimary)
                                                    Text("\(summary.totalViews.compactFormatted) views")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(TTTheme.textTertiary)
                                                }
                                                Spacer()
                                            }
                                            .padding(10)
                                            .background(TTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(TTTheme.separator, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        if selectedTab == .top || selectedTab == .videos {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(appState.searchQuery.isEmpty ? "Trending & Native Catalog" : "Matching Videos")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(TTTheme.textPrimary)
                                    Spacer()
                                    Text("\(viewModel.matchingVideos.count) videos")
                                        .font(TTTypography.caption)
                                        .foregroundStyle(TTTheme.textTertiary)
                                }

                                if viewModel.matchingVideos.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 32))
                                            .foregroundStyle(TTTheme.textTertiary)
                                        Text("No local matches for \"\(appState.searchQuery)\"")
                                            .font(TTTypography.sectionTitle)
                                        Button("Search Live on TikTok Web") {
                                            selectedTab = .webSearch
                                            appState.container.webController.loadSearch(query: appState.searchQuery)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(TTTheme.pink)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(40)
                                } else {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190, maximum: 240), spacing: 16)], spacing: 16) {
                                        ForEach(viewModel.matchingVideos) { video in
                                            VideoGridThumbnailCard(video: video) {
                                                appState.openVideoInFeed(video)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .background(TTTheme.canvas)
            }
        }
        .onChange(of: appState.searchQuery) { _, newValue in
            if selectedTab == .webSearch {
                appState.container.webController.loadSearch(query: newValue)
            }
        }
    }

    private func creatorCard(_ creator: CreatorProfile) -> some View {
        Button {
            appState.openCreatorProfile(creatorID: creator.id)
        } label: {
            HStack(spacing: 12) {
                CreatorAvatarView(
                    symbol: creator.avatarSymbol,
                    primaryHex: creator.avatarAccentHex,
                    secondaryHex: creator.avatarSecondaryHex,
                    size: 46
                )
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(creator.displayName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(TTTheme.textPrimary)
                        if creator.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(TTTheme.cyan)
                        }
                    }
                    Text("@\(creator.username) • \(creator.followersCount.compactFormatted) followers")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TTTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(12)
            .background(TTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(TTTheme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func resolveURL() async {
        isResolvingURL = true
        resolveError = nil
        defer { isResolvingURL = false }
        do {
            let item = try await appState.container.oEmbedService.resolveVideoItem(from: appState.searchQuery)
            appState.container.feedRepository.prependCustomVideo(item)
            appState.openVideoInFeed(item)
            appState.showToast("Loaded via Official TikTok oEmbed")
        } catch {
            resolveError = error.localizedDescription
        }
    }
}

struct VideoGridThumbnailCard: View {
    let video: VideoItem
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    thumbnailImage
                        .aspectRatio(9.0 / 16.0, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text(video.viewsCount > 0 ? video.viewsCount.compactFormatted : "Play")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(10)

                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: video.source.isNativeAVPlayer ? "play.circle.fill" : "globe")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(6)
                                .background(.black.opacity(0.45), in: Circle())
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isHovered ? TTTheme.pink.opacity(0.8) : TTTheme.separator, lineWidth: isHovered ? 1.5 : 1)
                )
                .scaleEffect(isHovered ? 1.015 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(video.description)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(TTTheme.textPrimary)
                        .lineLimit(2)

                    Text("@\(video.creatorUsername)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TTTheme.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let localURL = video.source.resolvedLocalThumbnailURL,
           let nsImage = NSImage(contentsOf: localURL) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else if let remoteURL = video.source.remoteThumbnailURL {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackGradient
                }
            }
        } else {
            fallbackGradient
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [Color(hex: video.creatorAvatarHex), Color(hex: video.creatorAvatarSecondaryHex), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: video.creatorAvatarSymbol)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}
