import AppKit
import SwiftUI

struct ShareSheetView: View {
    let video: VideoItem
    let onCopied: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share Video")
                        .font(.system(size: 17, weight: .bold))
                    Text("@\(video.creatorUsername)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(TTTheme.textSecondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(TTTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Text(video.shareURL.absoluteString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(TTTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Copy Link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(video.shareURL.absoluteString, forType: .string)
                    onCopied()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(TTTheme.pink)
            }
            .padding(12)
            .background(TTTheme.cardSurface, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.open(video.shareURL)
                    dismiss()
                } label: {
                    Label("Open on TikTok.com", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                ShareLink(item: video.shareURL, subject: Text("TikTok by @\(video.creatorUsername)"), message: Text(video.description)) {
                    Label("macOS Share...", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(22)
        .frame(width: 440)
        .background(TTTheme.elevatedSurface)
    }
}
