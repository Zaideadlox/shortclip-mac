import SwiftUI

struct TikTokLogoView: View {
    var iconSize: CGFloat = 24
    var showWordmark: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Image(systemName: "music.note")
                    .font(.system(size: iconSize * 0.85, weight: .black))
                    .foregroundStyle(TTTheme.cyan)
                    .offset(x: -1.4, y: -1.1)

                Image(systemName: "music.note")
                    .font(.system(size: iconSize * 0.85, weight: .black))
                    .foregroundStyle(TTTheme.pink)
                    .offset(x: 1.4, y: 1.1)

                Image(systemName: "music.note")
                    .font(.system(size: iconSize * 0.85, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: iconSize, height: iconSize)

            if showWordmark {
                Text("TikTok")
                    .font(TTTypography.brandTitle)
                    .foregroundStyle(TTTheme.textPrimary)
                    .tracking(-0.4)
            }
        }
    }
}

struct CreatorAvatarView: View {
    let symbol: String
    let primaryHex: UInt32
    let secondaryHex: UInt32
    var size: CGFloat = 44
    var showRing: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: primaryHex), Color(hex: secondaryHex)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay {
            if showRing {
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 1.8)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
    }
}
