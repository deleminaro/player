import SwiftUI

struct LyricsView: View {
    let track: Track
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var lyrics:    String?
    @State private var isLoading = true
    @State private var notFound  = false

    private var bg:     Color { themeManager.current.background }
    private var card:   Color { themeManager.current.card }
    private var accent: Color { themeManager.current.primary }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                bg.ignoresSafeArea()

                // Blurred artwork background
                if let url = track.highResArtworkURL ?? track.thumbnailArtworkURL {
                    AsyncImage(url: URL(string: url)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .clipped()
                    .blur(radius: 18)
                    .overlay(
                        LinearGradient(
                            colors: [bg.opacity(0.55), bg],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea(edges: .top)
                }

                VStack(spacing: 0) {
                    // Track header card
                    trackHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    Divider().background(Color.white.opacity(0.08))

                    // Content
                    if isLoading {
                        loadingView
                    } else if notFound {
                        notFoundView
                    } else if let text = lyrics {
                        ScrollView(showsIndicators: false) {
                            lyricsBody(text)
                                .padding(.horizontal, 24)
                                .padding(.top, 28)
                                .padding(.bottom, 80)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg.opacity(0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("LYRICS")
                        .font(.app(12, .black))
                        .kerning(2.5)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.app(13, .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(8)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = geniusSearchURL {
                        Link(destination: url) {
                            Image(systemName: "safari")
                                .font(.app(14, .semibold))
                                .foregroundStyle(accent)
                        }
                    }
                }
            }
        }
        .task { await loadLyrics() }
    }

    // MARK: - Track header

    private var trackHeader: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: track.thumbnailArtworkURL ?? "")) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                card.overlay(
                    Image(systemName: "music.note")
                        .font(.app(18))
                        .foregroundStyle(.white.opacity(0.2))
                )
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(themeManager.font(15, .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.username)
                    .font(themeManager.font(13))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer()

            Image(systemName: "quote.opening")
                .font(.app(18, .bold))
                .foregroundStyle(accent.opacity(0.6))
        }
    }

    // MARK: - Lyrics renderer

    private func lyricsBody(_ text: String) -> some View {
        let blocks = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks.indices, id: \.self) { i in
                let trimmed = blocks[i]
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    Text(trimmed.dropFirst().dropLast().uppercased())
                        .font(.app(10, .black))
                        .kerning(2)
                        .foregroundStyle(accent.opacity(0.8))
                        .padding(.top, 32)
                        .padding(.bottom, 10)
                } else {
                    Text(trimmed)
                        .font(themeManager.font(20, .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 28)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading state

    private var loadingView: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 80, height: 80)
                ProgressView()
                    .tint(accent)
                    .scaleEffect(1.3)
            }
            Text("SEARCHING LYRICS")
                .font(.app(10, .black))
                .kerning(2)
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Not found state

    private var notFoundView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                Image(systemName: "quote.bubble")
                    .font(.app(40))
                    .foregroundStyle(.white.opacity(0.15))
            }

            VStack(spacing: 8) {
                Text("NO LYRICS FOUND")
                    .font(.app(13, .black))
                    .kerning(2)
                    .foregroundStyle(.white.opacity(0.5))
                Text("Couldn't find lyrics for this track.\nTry searching on Genius.")
                    .font(themeManager.font(13))
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }

            if let url = geniusSearchURL {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari")
                            .font(.app(13, .semibold))
                        Text("Open Genius")
                            .font(themeManager.font(14, .semibold))
                    }
                    .foregroundStyle(themeManager.current.onPrimary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(accent, in: Capsule())
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private var geniusSearchURL: URL? {
        let q = "\(track.title) \(track.username)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://genius.com/search?q=\(q)")
    }

    private func loadLyrics() async {
        do {
            guard let pageURL = try await GeniusService.shared.searchLyricsURL(
                title: track.title, artist: track.username
            ) else {
                notFound = true; isLoading = false; return
            }
            let text = await GeniusService.shared.fetchLyricsText(from: pageURL)
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lyrics = text
            } else {
                notFound = true
            }
        } catch {
            notFound = true
        }
        isLoading = false
    }
}
