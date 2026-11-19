import AppKit
import SwiftUI
import WebKit

struct TikTokWebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct TikTokWebContainerView: View {
    let controller: TikTokWebController
    let destination: NavigationDestination
    var bannerMessage: String? = nil
    var onSwitchToNative: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Native macOS Web Control Ribbon
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    webIconButton(systemImage: "chevron.left", disabled: !controller.canGoBack) {
                        controller.goBack()
                    }
                    webIconButton(systemImage: "chevron.right", disabled: !controller.canGoForward) {
                        controller.goForward()
                    }
                    webIconButton(systemImage: "arrow.clockwise", disabled: false) {
                        controller.reload()
                    }
                }

                // URL / Session Status Pill
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TTTheme.cyan)

                    Text(controller.currentURL?.absoluteString ?? destination.tikTokWebURL.absoluteString)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(TTTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 4)

                    if controller.hasSessionCookies {
                        Label("Signed In", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TTTheme.cyan)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TTTheme.cardSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(TTTheme.separator, lineWidth: 1))

                if let onSwitchToNative {
                    Button {
                        onSwitchToNative()
                    } label: {
                        Label("Native Player", systemImage: "play.rectangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(TTTheme.pink)
                }

                Button {
                    if let url = controller.currentURL ?? Optional(destination.tikTokWebURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TTTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Open in Default Browser")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(TTTheme.elevatedSurface)

            if let bannerMessage {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(TTTheme.cyan)
                    Text(bannerMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TTTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(TTTheme.cyan.opacity(0.08))
            }

            if controller.isLoading {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(TTTheme.brandGradient)
                        .frame(width: max(proxy.size.width * controller.estimatedProgress, 12), height: 2)
                        .animation(.easeOut(duration: 0.2), value: controller.estimatedProgress)
                }
                .frame(height: 2)
            } else {
                Divider().overlay(TTTheme.separator)
            }

            ZStack {
                TikTokWebViewRepresentable(webView: controller.webView)
                    .background(TTTheme.canvas)

                if let errorText = controller.lastError {
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 36))
                            .foregroundStyle(TTTheme.pink)
                        Text("Unable to Load TikTok Web")
                            .font(TTTypography.pageTitle)
                            .foregroundStyle(TTTheme.textPrimary)
                        Text(errorText)
                            .font(TTTypography.body)
                            .foregroundStyle(TTTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)
                        HStack(spacing: 12) {
                            Button("Try Again") {
                                controller.reload()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(TTTheme.pink)

                            if let onSwitchToNative {
                                Button("Switch to Native Player") {
                                    onSwitchToNative()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(32)
                    .background(TTTheme.elevatedSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(TTTheme.subtleBorder, lineWidth: 1))
                }
            }
        }
    }

    private func webIconButton(systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(disabled ? TTTheme.textTertiary : TTTheme.textPrimary)
                .frame(width: 28, height: 28)
                .background(TTTheme.cardSurface, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
