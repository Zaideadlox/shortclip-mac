import SwiftUI

struct CommentsDrawerView: View {
    let video: VideoItem
    let comments: [CommentItem]
    let onClose: () -> Void
    let onPostComment: (String) -> Void
    let onLikeComment: (String) -> Void

    @State private var draftComment = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Comments")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TTTheme.textPrimary)
                    Text("\(video.commentsCount.compactFormatted) comments • Local preview drawer")
                        .font(.system(size: 11))
                        .foregroundStyle(TTTheme.textTertiary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TTTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(TTTheme.controlSurface, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().overlay(TTTheme.separator)

            // Comments List
            if comments.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28))
                        .foregroundStyle(TTTheme.textTertiary)
                    Text("No comments yet")
                        .font(TTTypography.sectionTitle)
                        .foregroundStyle(TTTheme.textSecondary)
                    Text("Be the first to drop a note on this clip.")
                        .font(TTTypography.caption)
                        .foregroundStyle(TTTheme.textTertiary)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color(hex: comment.authorAccentHex).opacity(0.24))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text(String(comment.authorDisplayName.prefix(1)).uppercased())
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color(hex: comment.authorAccentHex))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(comment.authorDisplayName)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(TTTheme.textPrimary)
                                        Text(comment.timestamp)
                                            .font(.system(size: 11))
                                            .foregroundStyle(TTTheme.textTertiary)
                                    }

                                    Text(comment.text)
                                        .font(.system(size: 13))
                                        .foregroundStyle(TTTheme.textPrimary.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 6)

                                Button {
                                    onLikeComment(comment.id)
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                            .font(.system(size: 12))
                                            .foregroundStyle(comment.isLiked ? TTTheme.pink : TTTheme.textTertiary)
                                        Text("\(comment.likesCount)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(TTTheme.textTertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
            }

            Divider().overlay(TTTheme.separator)

            // Composer
            HStack(spacing: 8) {
                TextField("Add a comment...", text: $draftComment)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TTTheme.cardSurface, in: Capsule())
                    .onSubmit {
                        submit()
                    }

                Button("Post") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .tint(TTTheme.pink)
                .disabled(draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 330)
        .background(TTTheme.elevatedSurface)
        .overlay(alignment: .leading) {
            Divider().overlay(TTTheme.separator)
        }
    }

    private func submit() {
        let trimmed = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onPostComment(trimmed)
        draftComment = ""
    }
}
