import AppKit
import SwiftUI

struct ProfileView: View {
    @Bindable var appState: AppState
    @State private var selectedTab: ProfileVideoTab = .videos
    @State private var showWebProfile = false

    private var viewModel: ProfileViewModel {
        ProfileViewModel(appState: appState)
    }

    var body: some View {
        if showWebProfile {
            TikTokWebContainerView(
                controller: appState.container.webController,
                destination: .profile,
                bannerMessage: "Viewing live profile on TikTok Web.",
                onSwitchToNative: {
                    showWebProfile = false
                }
            )
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 26) {
                    // Back button when inspecting another creator
                    if !viewModel.isOwnProfile {
                        Button {
                            appState.selectedCreatorID = nil
                        } label: {
                            Label("Back to My Profile", systemImage: "chevron.left")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(TTTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Profile Header Card
                    HStack(alignment: .top, spacing: 22) {
                        profileAvatar

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text(viewModel.displayName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(TTTheme.textPrimary)

                                if viewModel.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(TTTheme.cyan)
                                }
                            }

                            Text("@\(viewModel.username)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(TTTheme.textSecondary)

                            // Stats Row
                            HStack(spacing: 24) {
                                statItem(value: viewModel.followingCount.compactFormatted, label: "Following")
                                statItem(value: viewModel.followersCount.compactFormatted, label: "Followers")
                                statItem(value: viewModel.likesCount.compactFormatted, label: "Likes")
                            }
                            .padding(.vertical, 2)

                            Text(viewModel.bio)
                                .font(TTTypography.body)
                                .foregroundStyle(TTTheme.textSecondary)
                                .frame(maxWidth: 560, alignment: .leading)

                            HStack(spacing: 10) {
                                if let creator = viewModel.viewingCreator {
                                    Button {
                                        viewModel.toggleFollow()
                                    } label: {
                                        Text(creator.isFollowed ? "Following" : "Follow")
                                            .font(.system(size: 13, weight: .bold))
                                            .frame(minWidth: 112)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(creator.isFollowed ? TTTheme.controlSurface : TTTheme.pink)

                                    if let url = creator.webURL {
                                        Button {
                                            appState.container.webController.load(url: url)
                                            showWebProfile = true
                                        } label: {
                                            Label("Open on TikTok Web", systemImage: "globe")
                                                .font(.system(size: 12.5, weight: .semibold))
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                } else {
                                    Button {
                                        appState.isShowingAuthSheet = true
                                    } label: {
                                        Label(
                                            appState.container.authService.session.isSignedIn ? "Manage Account" : "Sign In to TikTok",
                                            systemImage: "person.badge.key.fill"
                                        )
                                        .font(.system(size: 13, weight: .bold))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(TTTheme.pink)

                                    Button {
                                        appState.container.webController.load(destination: .profile)
                                        showWebProfile = true
                                    } label: {
                                        Label("Open Live TikTok Profile", systemImage: "globe")
                                            .font(.system(size: 12.5, weight: .semibold))
                                    }
                                    .buttonStyle(.bordered)

                                    Button {
                                        appState.isShowingAddURLSheet = true
                                    } label: {
                                        Label("Add Video URL", systemImage: "plus")
                                            .font(.system(size: 12.5, weight: .semibold))
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.top, 4)
                        }

                        Spacer()
                    }
                    .padding(22)
                    .background(TTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(TTTheme.separator, lineWidth: 1))

                    // Segmented Tabs
                    HStack(spacing: 8) {
                        ForEach(ProfileVideoTab.allCases) { tab in
                            let selected = selectedTab == tab
                            Button {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    selectedTab = tab
                                }
                            } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(selected ? .white : TTTheme.textSecondary)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(selected ? TTTheme.pink : TTTheme.elevatedSurface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    // 3-Column 9:16 Video Grid
                    let gridVideos = viewModel.videos(for: selectedTab)
                    if gridVideos.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: selectedTab == .liked ? "heart.slash" : "bookmark.slash")
                                .font(.system(size: 30))
                                .foregroundStyle(TTTheme.textTertiary)
                            Text("No \(selectedTab.rawValue.lowercased()) videos yet")
                                .font(TTTypography.sectionTitle)
                                .foregroundStyle(TTTheme.textSecondary)
                            Text("Like or bookmark videos in the For You feed and they will appear right here.")
                                .font(TTTypography.caption)
                                .foregroundStyle(TTTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(48)
                        .background(TTTheme.elevatedSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 190, maximum: 245), spacing: 16)],
                            spacing: 18
                        ) {
                            ForEach(gridVideos) { video in
                                VideoGridThumbnailCard(video: video) {
                                    appState.openVideoInFeed(video)
                                }
                            }
                        }
                    }
                }
                .padding(26)
            }
            .background(TTTheme.canvas)
        }
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let creator = viewModel.viewingCreator {
            CreatorAvatarView(
                symbol: creator.avatarSymbol,
                primaryHex: creator.avatarAccentHex,
                secondaryHex: creator.avatarSecondaryHex,
                size: 92,
                showRing: true
            )
        } else if let avatarStr = viewModel.oauthUser?.avatarURL, let url = URL(string: avatarStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    CreatorAvatarView(symbol: "person.fill", primaryHex: 0xFE2C55, secondaryHex: 0x25F4EE, size: 92, showRing: true)
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(Circle())
        } else {
            CreatorAvatarView(
                symbol: "person.fill",
                primaryHex: 0xFE2C55,
                secondaryHex: 0x25F4EE,
                size: 92,
                showRing: true
            )
        }
    }

    private func statItem(value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(TTTheme.textPrimary)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(TTTheme.textSecondary)
        }
    }
}
