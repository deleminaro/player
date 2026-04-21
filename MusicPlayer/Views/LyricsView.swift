import SwiftUI

struct LyricsView: View {
    let track: Track
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var lyrics:     String?
    @State private var isLoading = true
    @State private var notFound  = false

    private let bg      = Color(red: 0.075, green: 0.075, blue: 0.075)

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(themeManager.current.primary)
                        Text("SEARCHING LYRICS…")
                            .font(.system(size: 10, weight: .black)).kerning(2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                } else if notFound {
                    notFoundView
                } else if let text = lyrics {
                    ScrollView(showsIndicators: false) {
                        lyricsContent(text)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                            .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("LYRICS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(themeManager.current.primary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if let url = geniusSearchURL {
                        Link(destination: url) {
                            Image(systemName: "safari")
                                .foregroundStyle(themeManager.current.primary)
                        }
                    }
                }
            }
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .task { await loadLyrics() }
    }

    // MARK: - Lyrics renderer

    @ViewBuilder
    private func lyricsContent(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(track.title.uppercased())
                .font(.system(size: 11, weight: .black)).kerning(2)
                .foregroundStyle(themeManager.current.primary.opacity(0.7))
                .padding(.bottom, 4)
            Text(track.username.uppercased())
                .font(.system(size: 10, weight: .bold)).kerning(1.5)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, 28)

            ForEach(Array(text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, block in
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    Text(trimmed.uppercased())
                        .font(.system(size: 11, weight: .black)).kerning(1.5)
                        .foregroundStyle(themeManager.current.primary)
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                } else {
                    Text(trimmed)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineSpacing(6)
                        .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Not found

    private var notFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.2))
            Text("LYRICS NOT FOUND")
                .font(.system(size: 13, weight: .black)).kerning(2)
                .foregroundStyle(.white.opacity(0.5))
            Text("Genius couldn't match this track.\nTry opening in Safari to search manually.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            if let url = geniusSearchURL {
                Link(destination: url) {
                    Text("Search on Genius")
                        .font(.system(size: 12, weight: .black)).kerning(1)
                        .foregroundStyle(themeManager.current.onPrimary)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(themeManager.current.primary, in: Capsule())
                }
                .padding(.top, 4)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var geniusSearchURL: URL? {
        let q = track.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
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
