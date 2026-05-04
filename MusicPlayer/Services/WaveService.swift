import Foundation

@MainActor
final class WaveService: ObservableObject {
    static let shared = WaveService()

    @Published var waveTracks:    [Track]  = []
    @Published var isGenerating:  Bool     = false
    @Published var sourceArtists: [String] = []
    @Published var lastGenerated: Date?

    private let sc      = SoundCloudService.shared
    private let spotify = SpotifyService.shared
    private let waveKey = "mp_wave_cache"

    init() { loadCached() }

    // MARK: - Generate

    func generate(from history: [Track]) async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        guard !history.isEmpty else {
            let fallback = (try? await sc.search(query: "trending mix 2024")) ?? []
            waveTracks = Array(fallback.prefix(20))
            lastGenerated = Date()
            saveCached()
            return
        }

        // Tally artists → most listened first
        var tally: [String: (count: Int, source: TrackSource)] = [:]
        for track in history {
            let key = track.username
            tally[key] = ((tally[key]?.count ?? 0) + 1, track.source)
        }

        let sorted    = tally.sorted { $0.value.count > $1.value.count }
        let top       = Array(sorted.prefix(5))
        let discovery = sorted.dropFirst(5).randomElement().map { [$0] } ?? []
        let artists   = top + discovery

        sourceArtists = artists.prefix(4).map { $0.key }

        let existingIDs = Set(history.map { $0.id })
        var results: [Track] = []

        for (artist, info) in artists {
            guard results.count < 35 else { break }
            let found: [Track]
            if info.source == .spotify && spotify.isAuthenticated {
                found = (try? await spotify.search(query: artist)) ?? []
            } else {
                found = (try? await sc.search(query: artist)) ?? []
            }
            let fresh = found.filter { !existingIDs.contains($0.id) }
            results.append(contentsOf: fresh.prefix(6))
        }

        results.shuffle()
        waveTracks    = Array(results.prefix(30))
        lastGenerated = Date()
        saveCached()
    }

    func clear() {
        waveTracks    = []
        sourceArtists = []
        lastGenerated = nil
        UserDefaults.standard.removeObject(forKey: waveKey)
    }

    // MARK: - Cache

    private func saveCached() {
        if let data = try? JSONEncoder().encode(waveTracks) {
            UserDefaults.standard.set(data, forKey: waveKey)
        }
    }

    private func loadCached() {
        if let data   = UserDefaults.standard.data(forKey: waveKey),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            waveTracks = tracks
        }
    }
}
