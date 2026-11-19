import SwiftUI

struct TopBarView: View {
    @Bindable var appState: AppState
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Destination Title
            HStack(spacing: 8) {
                Image(systemName: appState.selectedDestination.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TTTheme.pink)
                Text(appState.selectedDestination.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TTTheme.textPrimary)
            }
            .frame(minWidth: 100, alignment: .leading)

            Spacer(minLength: 8)

            // Search Bar (Command + F)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TTTheme.textSecondary)

                TextField("Search creators, videos, #hashtags, or paste TikTok URL...", text: $appState.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(TTTheme.textPrimary)
                    .focused($searchFieldFocused)
                    .onSubmit {
                        appState.selectedDestination = .search
                        appState.container.videoPlayerManager.pause()
                    }

                if !appState.searchQuery.isEmpty {
                    Button {
                        appState.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(TTTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: 360)
            .background(TTTheme.elevatedSurface, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(searchFieldFocused ? TTTheme.cyan.opacity(0.7) : TTTheme.separator, lineWidth: 1)
            )

            Spacer(minLength: 8)

            // Engine Switcher (Native Player vs Authentic TikTok Web)
            if appState.selectedDestination.supportsFeedView {
                HStack(spacing: 2) {
                    ForEach(BrowsingEngine.allCases) { engine in
                        let selected = appState.activeEngine == engine
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                appState.setEngine(engine)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: engine.systemImage)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(engine.rawValue)
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .foregroundStyle(selected ? .white : TTTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(selected ? TTTheme.pink : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .help(engine.subtitle)
                    }
                }
                .padding(3)
                .background(TTTheme.elevatedSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(TTTheme.separator, lineWidth: 1))
            }

            // Add Official TikTok URL button
            Button {
                appState.isShowingAddURLSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 11.5, weight: .bold))
                    Text("Add URL")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(TTTheme.textPrimary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(TTTheme.elevatedSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(TTTheme.subtleBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Add a public TikTok video URL (oEmbed) or direct MP4/HLS stream")

            // Account Button
            Button {
                appState.isShowingAuthSheet = true
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.container.authService.session.isSignedIn ? TTTheme.cyan : TTTheme.pink)
                        .frame(width: 7, height: 7)
                    Text(appState.container.authService.session.isSignedIn ? "Account" : "Log in")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(
                    appState.container.authService.session.isSignedIn ? TTTheme.controlSurface : TTTheme.pink,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .frame(height: TTTheme.topBarHeight)
        .background(TTTheme.canvas)
        .overlay(alignment: .bottom) {
            Divider().overlay(TTTheme.separator)
        }
        .onChange(of: appState.isSearchFocused) { _, focused in
            if focused {
                searchFieldFocused = true
                appState.isSearchFocused = false
            }
        }
    }
}
