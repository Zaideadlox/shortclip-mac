import SwiftUI

struct SidebarView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand Header (leaves clean clearance for native macOS traffic-light window controls)
            HStack {
                TikTokLogoView(iconSize: 24, showWordmark: true)
                Spacer()
                Text("MAC")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(TTTheme.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TTTheme.cyan.opacity(0.14), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 38)
            .padding(.bottom, 12)

            // Quick Search Pill (matches desktop reference layout)
            Button {
                appState.triggerSearch()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TTTheme.textSecondary)
                    Text("Search")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TTTheme.textSecondary)
                    Spacer()
                    Text("⌘F")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(TTTheme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(TTTheme.elevatedSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(TTTheme.separator, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(NavigationDestination.sidebarItems) { item in
                        SidebarNavRow(
                            destination: item,
                            isSelected: appState.selectedDestination == item,
                            badgeText: item == .live ? "WEB" : nil
                        ) {
                            appState.navigate(to: item)
                        }
                    }

                    Divider()
                        .overlay(TTTheme.separator)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)

                    // Suggested Creators Section (matches Image #1)
                    Text("Suggested for you")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(TTTheme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)

                    ForEach(appState.container.feedRepository.suggestedCreators) { creator in
                        Button {
                            appState.openCreatorProfile(creatorID: creator.id)
                        } label: {
                            HStack(spacing: 10) {
                                CreatorAvatarView(
                                    symbol: creator.avatarSymbol,
                                    primaryHex: creator.avatarAccentHex,
                                    secondaryHex: creator.avatarSecondaryHex,
                                    size: 30
                                )

                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(creator.username)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(TTTheme.textPrimary)
                                            .lineLimit(1)

                                        if creator.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(TTTheme.cyan)
                                        }
                                    }

                                    Text(creator.displayName)
                                        .font(.system(size: 11))
                                        .foregroundStyle(TTTheme.textTertiary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(appState.selectedCreatorID == creator.id ? Color.white.opacity(0.08) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                    }
                }
                .padding(.bottom, 16)
            }

            Divider().overlay(TTTheme.separator)

            // Account Session Footer
            Button {
                appState.isShowingAuthSheet = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(appState.container.authService.session.isSignedIn ? TTTheme.cyan.opacity(0.18) : TTTheme.pink.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: appState.container.authService.session.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.badge.key.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(appState.container.authService.session.isSignedIn ? TTTheme.cyan : TTTheme.pink)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.container.authService.session.statusLabel)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TTTheme.textPrimary)
                            .lineLimit(1)
                        Text(appState.container.authService.session.isSignedIn ? "Manage Session" : "Sign in to TikTok")
                            .font(.system(size: 10.5))
                            .foregroundStyle(TTTheme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TTTheme.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: TTTheme.sidebarWidth)
        .background(TTTheme.sidebarBackground)
    }
}

private struct SidebarNavRow: View {
    let destination: NavigationDestination
    let isSelected: Bool
    let badgeText: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? TTTheme.pink : TTTheme.textPrimary.opacity(0.88))
                    .frame(width: 22)

                Text(destination.title)
                    .font(TTTypography.sidebarItem)
                    .foregroundStyle(isSelected ? TTTheme.pink : TTTheme.textPrimary.opacity(0.92))

                Spacer()

                if let badgeText {
                    Text(badgeText)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(TTTheme.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(TTTheme.cyan.opacity(0.14), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? TTTheme.pink.opacity(0.14)
                            : (isHovered ? Color.white.opacity(0.06) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }
}
