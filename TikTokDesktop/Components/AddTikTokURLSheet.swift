import SwiftUI

struct AddTikTokURLSheet: View {
    let oEmbedService: TikTokOEmbedService
    let onVideoResolved: (VideoItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var inputURL = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Add Video to Native Feed")
                        .font(.system(size: 17, weight: .bold))
                    Text("Paste any public TikTok video URL (resolved via official oEmbed API) or a direct .mp4 / .m3u8 URL.")
                        .font(.system(size: 12))
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

            TextField("https://www.tiktok.com/@scout2015/video/6718335390845095173", text: $inputURL)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            HStack(spacing: 8) {
                Button("Try Official TikTok Example") {
                    inputURL = "https://www.tiktok.com/@scout2015/video/6718335390845095173"
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
                Spacer()
            }

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(TTTheme.pink)
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(TTTheme.pink)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await resolveAndAdd() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 12)
                    } else {
                        Text("Add & Play")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TTTheme.pink)
                .disabled(inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
        }
        .padding(22)
        .frame(width: 500)
        .background(TTTheme.elevatedSurface)
    }

    private func resolveAndAdd() async {
        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            errorMessage = "Please enter a valid URL."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Direct MP4 / M3U8 native stream support
        let ext = url.pathExtension.lowercased()
        if ext == "mp4" || ext == "mov" || ext == "m3u8" {
            let item = VideoItem(
                id: "custom_\(UUID().uuidString.prefix(8))",
                creatorID: "creator_alvin",
                creatorUsername: "custom.stream",
                creatorDisplayName: "Custom Stream",
                creatorVerified: false,
                creatorAvatarHex: 0x25F4EE,
                creatorAvatarSecondaryHex: 0x0EA5E9,
                creatorAvatarSymbol: "film.fill",
                description: "Direct native AVPlayer stream: \(url.lastPathComponent)",
                hashtags: ["stream", "avplayer"],
                musicTitle: url.lastPathComponent,
                musicArtist: url.host ?? "Direct Media",
                locationTag: "Native Stream",
                postedRelativeTime: "Just added",
                categories: [.forYou, .explore],
                source: .remoteStream(url: url, thumbnailURL: nil),
                shareURL: url,
                likesCount: 1,
                commentsCount: 0,
                bookmarksCount: 0,
                sharesCount: 0,
                viewsCount: 1,
                isLiked: false,
                isBookmarked: false
            )
            onVideoResolved(item)
            dismiss()
            return
        }

        // Official TikTok oEmbed API resolution
        do {
            let item = try await oEmbedService.resolveVideoItem(from: trimmed)
            onVideoResolved(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
