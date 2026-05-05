import Foundation

@MainActor
final class WaveService: ObservableObject {
    static let shared = WaveService()

    // For You
    @Published var waveTracks:    [Track]  = []
    @Published var isGenerating:  Bool     = false
    @Published var sourceArtists: [String] = []
    @Published var lastGenerated: Date?

    // Discover
    @Published var discoverTracks:    [Track]  = []
    @Published var isDiscovering:     Bool     = false
    @Published var seedLabel:         String?  = nil

    private let sc      = SoundCloudService.shared
    private let spotify = SpotifyService.shared
    private let waveKey      = "mp_wave_cache"
    private let discoverKey  = "mp_discover_cache"
    private let seedLabelKey = "mp_discover_label"

    init() {
        loadCached()
        loadDiscoverCached()
    }

    // MARK: - For You

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

    // MARK: - Discover

    func generateFromSeed(query: String, label: String) async {
        guard !isDiscovering else { return }
        isDiscovering = true
        defer { isDiscovering = false }

        seedLabel = label

        var results: [Track] = []
        var seenIDs = Set<Int>()

        // Primary search
        let primary = (try? await sc.search(query: query)) ?? []
        for t in primary { seenIDs.insert(t.id); results.append(t) }

        // Fan out to top artists found in primary results for variety
        let topArtists = Array(Set(primary.prefix(6).map { $0.username })).prefix(3)
        for artist in topArtists {
            guard results.count < 50 else { break }
            let found = (try? await sc.search(query: "\(artist) \(query.components(separatedBy: " ").first ?? "")")) ?? []
            for t in found where !seenIDs.contains(t.id) {
                seenIDs.insert(t.id)
                results.append(t)
            }
        }

        results.shuffle()
        discoverTracks = Array(results.prefix(30))
        saveDiscoverCached()
    }

    // MARK: - Clear

    func clear() {
        waveTracks    = []
        sourceArtists = []
        lastGenerated = nil
        UserDefaults.standard.removeObject(forKey: waveKey)
    }

    func clearDiscover() {
        discoverTracks = []
        seedLabel      = nil
        UserDefaults.standard.removeObject(forKey: discoverKey)
        UserDefaults.standard.removeObject(forKey: seedLabelKey)
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

    private func saveDiscoverCached() {
        if let data = try? JSONEncoder().encode(discoverTracks) {
            UserDefaults.standard.set(data, forKey: discoverKey)
        }
        UserDefaults.standard.set(seedLabel, forKey: seedLabelKey)
    }

    private func loadDiscoverCached() {
        if let data   = UserDefaults.standard.data(forKey: discoverKey),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            discoverTracks = tracks
        }
        seedLabel = UserDefaults.standard.string(forKey: seedLabelKey)
    }
}
