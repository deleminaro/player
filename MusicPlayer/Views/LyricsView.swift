import SwiftUI
import WebKit

struct LyricsView: View {
    let track: Track
    @Environment(\.dismiss) var dismiss

    @State private var lyricsURL:  URL?
    @State private var isLoading = true
    @State private var errorMsg:   String?

    var body: some View {
        NavigationStack {
            Group {
                if let url = lyricsURL {
                    GeniusWebView(url: url, isLoading: $isLoading)
                        .ignoresSafeArea(edges: .bottom)
                        .overlay(alignment: .center) {
                            if isLoading {
                                ProgressView("Loading lyrics…")
                                    .padding(20)
                                    .background(.regularMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                } else if errorMsg != nil {
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
                        if let searchURL = URL(string: "https://genius.com/search?q=\(track.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                            Link(destination: searchURL) {
                                Text("Search on Genius")
                                    .font(.system(size: 12, weight: .black)).kerning(1)
                                    .foregroundStyle(Color(red: 0.063, green: 0, blue: 0.663))
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(Color(red: 0.753, green: 0.757, blue: 1.0), in: Capsule())
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView("Searching for lyrics…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if let url = lyricsURL {
                        Link(destination: url) {
                            Image(systemName: "safari")
                        }
                    }
                }
            }
        }
        .task { await fetchLyrics() }
    }

    private func fetchLyrics() async {
        do {
            if let url = try await GeniusService.shared.searchLyricsURL(
                title: track.title, artist: track.username
            ) {
                lyricsURL = url
            } else {
                errorMsg = "No lyrics found for \"\(track.title)\"."
            }
        } catch {
            errorMsg = "Could not load lyrics. Check your Genius token."
        }
    }
}

// MARK: - WKWebView wrapper

struct GeniusWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(isLoading: $isLoading) }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        init(isLoading: Binding<Bool>) { _isLoading = isLoading }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) { isLoading = false }
        func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError _: Error) { isLoading = false }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) { isLoading = false }
    }
}
