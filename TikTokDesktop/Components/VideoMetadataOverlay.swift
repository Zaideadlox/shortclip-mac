import SwiftUI

struct VideoMetadataOverlay: View {
    let video: VideoItem
    let onTapCreator: () -> Void
    let onTapHashtag: (String) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Optional Location Pill (matches Image #1)
            if let location = video.locationTag, !location.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TTTheme.cyan)
                    Text(location)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            // Creator Username + Verified + Relative Timestamp
            Button(action: onTapCreator) {
                HStack(spacing: 6) {
                    Text(video.creatorDisplayName)
                        .font(TTTypography.creatorHandle)
                        .foregroundStyle(.white)

                    if video.creatorVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(TTTheme.cyan)
                    }

                    Text("•")
                        .foregroundStyle(.white.opacity(0.55))

                    Text(video.postedRelativeTime)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .buttonStyle(.plain)

            // Description
            Text(video.description)
                .font(TTTypography.body)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(isExpanded ? 6 : 2)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                }

            // Clickable Hashtag Chips
            if !video.hashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(video.hashtags, id: \.self) { tag in
                            Button {
                                onTapHashtag("#\(tag)")
                            } label: {
                                Text("#\(tag)")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(TTTheme.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.38), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Music Track Info
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.white)
                Text(video.musicCredit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.42), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: TTTheme.panelCornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.34))
                .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: TTTheme.panelCornerRadius, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TTTheme.panelCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
        )
    }
}
