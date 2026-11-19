import SwiftUI

struct VideoActionRailView: View {
    let video: VideoItem
    let isFollowing: Bool
    let isPlaying: Bool
    let onTapCreator: () -> Void
    let onTapFollow: () -> Void
    let onTapLike: () -> Void
    let onTapComment: () -> Void
    let onTapBookmark: () -> Void
    let onTapShare: () -> Void

    @State private var likeScale: CGFloat = 1.0
    @State private var discRotation: Double = 0

    var body: some View {
        VStack(spacing: 18) {
            // Creator Avatar + Follow Badge (matches Image #1)
            ZStack(alignment: .bottom) {
                Button(action: onTapCreator) {
                    CreatorAvatarView(
                        symbol: video.creatorAvatarSymbol,
                        primaryHex: video.creatorAvatarHex,
                        secondaryHex: video.creatorAvatarSecondaryHex,
                        size: 48,
                        showRing: true
                    )
                }
                .buttonStyle(.plain)
                .help("View @\(video.creatorUsername)")

                Button(action: onTapFollow) {
                    ZStack {
                        Circle()
                            .fill(isFollowing ? TTTheme.cyan : TTTheme.pink)
                            .frame(width: 21, height: 21)
                        Image(systemName: isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(isFollowing ? .black : .white)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .offset(y: 9)
                .help(isFollowing ? "Following" : "Follow creator")
            }
            .padding(.bottom, 8)

            // Like
            ActionRailButton(
                systemImage: "heart.fill",
                countText: video.likesCount.compactFormatted,
                isActive: video.isLiked,
                activeColor: TTTheme.pink,
                scale: likeScale
            ) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.5)) {
                    likeScale = 1.28
                }
                onTapLike()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                        likeScale = 1.0
                    }
                }
            }

            // Comment
            ActionRailButton(
                systemImage: "bubble.right.fill",
                countText: video.commentsCount.compactFormatted,
                isActive: false,
                activeColor: .white,
                action: onTapComment
            )

            // Bookmark / Favorite
            ActionRailButton(
                systemImage: "bookmark.fill",
                countText: video.bookmarksCount.compactFormatted,
                isActive: video.isBookmarked,
                activeColor: TTTheme.gold,
                action: onTapBookmark
            )

            // Share
            ActionRailButton(
                systemImage: "arrowshape.turn.up.right.fill",
                countText: video.sharesCount.compactFormatted,
                isActive: false,
                activeColor: TTTheme.cyan,
                action: onTapShare
            )

            // Spinning Vinyl Sound Disc
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [Color(hex: 0x1A1A1F), Color(hex: 0x3A3A44), Color(hex: 0x1A1A1F), Color(hex: 0x33333C), Color(hex: 0x1A1A1F)],
                            center: .center
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: video.creatorAvatarHex), Color(hex: video.creatorAvatarSecondaryHex)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)

                Circle()
                    .fill(Color.black)
                    .frame(width: 6, height: 6)
            }
            .rotationEffect(.degrees(discRotation))
            .onAppear {
                if isPlaying {
                    startSpin()
                }
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    startSpin()
                }
            }
            .help(video.musicCredit)
        }
        .frame(width: 62)
    }

    private func startSpin() {
        withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
            discRotation += 360
        }
    }
}

private struct ActionRailButton: View {
    let systemImage: String
    let countText: String
    let isActive: Bool
    let activeColor: Color
    var scale: CGFloat = 1.0
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isHovered ? TTTheme.controlSurface : TTTheme.elevatedSurface)
                        .frame(width: 46, height: 46)
                        .overlay(Circle().strokeBorder(TTTheme.separator, lineWidth: 1))

                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isActive ? activeColor : .white)
                        .scaleEffect(scale)
                }

                Text(countText)
                    .font(TTTypography.counter)
                    .foregroundStyle(TTTheme.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
