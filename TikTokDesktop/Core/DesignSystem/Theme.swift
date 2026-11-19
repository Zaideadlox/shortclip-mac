import SwiftUI

enum TTTheme {
    // Brand Accents
    static let pink = Color(hex: 0xFE2C55)
    static let cyan = Color(hex: 0x25F4EE)
    static let gold = Color(hex: 0xFACE15)

    // Surfaces (Dark-first TikTok Desktop aesthetic)
    static let canvas = Color(hex: 0x09090B)
    static let sidebarBackground = Color(hex: 0x0D0D10)
    static let elevatedSurface = Color(hex: 0x16161B)
    static let cardSurface = Color(hex: 0x1B1B22)
    static let controlSurface = Color(hex: 0x24242D)
    static let separator = Color.white.opacity(0.09)
    static let subtleBorder = Color.white.opacity(0.12)

    // Typography Colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.42)

    // Layout Constants
    static let sidebarWidth: CGFloat = 220
    static let topBarHeight: CGFloat = 56
    static let videoCornerRadius: CGFloat = 18
    static let panelCornerRadius: CGFloat = 14

    // Brand Gradient
    static let brandGradient = LinearGradient(
        colors: [cyan, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleVideoScrim = LinearGradient(
        colors: [
            Color.black.opacity(0.0),
            Color.black.opacity(0.12),
            Color.black.opacity(0.55),
            Color.black.opacity(0.84)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
