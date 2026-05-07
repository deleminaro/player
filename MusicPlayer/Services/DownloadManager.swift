import AVFoundation
import Foundation

// Wraps AVAssetExportSession (not Sendable) for Swift concurrency.
// Safe: AVAssetExportSession's completion handler and status are thread-safe.
private struct SendableExportSession: @unchecked Sendable {
    let value: AVAssetExportSession
}

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var cachedIDs:   Set<Int> = []
    @Published var offlineIDs:  Set<Int> = []
    @Published var downloading: Set<Int> = []

    private let kCached  = "dm_cached_ids"
    private let kOffline = "dm_offline_ids"

    private var cacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioCache", isDirectory: true)
    }
    var offlineDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OfflineTracks", isDirectory: true)
    }
    private var artworkDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Artwork", isDirectory: true)
    }

    private init() {
        try? FileManager.default.createDirectory(at: cacheDir,   withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: offlineDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: artworkDir, withIntermediateDirectories: true)
        loadPersistedIDs()
    }

    // MARK: - Query

    func localURL(for trackID: Int) -> URL? {
        localOfflineURL(for: trackID) ?? localCacheURL(for: trackID)
    }

    func localCacheURL(for trackID: Int) -> URL? {
        for ext in ["mp3", "m4a"] {
            let u = cacheDir.appendingPathComponent("\(trackID).\(ext)")
            if isValidAudioFile(at: u) { return u }
        }
        return nil
    }

    func localOfflineURL(for trackID: Int) -> URL? {
        for ext in ["mp3", "m4a"] {
            let u = offlineDir.appendingPathComponent("\(trackID).\(ext)")
            if isValidAudioFile(at: u) { return u }
        }
        return nil
    }

    // MARK: - Save to cache (Caches dir — OS may evict)

    func saveToCache(track: Track, streamURL: URL) async {
        guard !cachedIDs.contains(track.id), !downloading.contains(track.id) else { return }
        downloading.insert(track.id)
        defer { downloading.remove(track.id) }
        if await store(from: streamURL, trackID: track.id, in: cacheDir) {
            cachedIDs.insert(track.id)
            UserDefaults.standard.set(Array(cachedIDs), forKey: kCached)
        }
    }

    // MARK: - Artwork (disk-backed)

    func localArtworkURL(for trackID: Int) -> URL? {
        let u = artworkDir.appendingPathComponent("\(trackID).jpg")
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    func saveArtwork(trackID: Int, from urlStr: String) async {
        let dest = artworkDir.appendingPathComponent("\(trackID).jpg")
        guard !FileManager.default.fileExists(atPath: dest.path),
              let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              !data.isEmpty else { return }
        try? data.write(to: dest)
    }

    // MARK: - Download offline (Documents dir — persists)

    func downloadOffline(track: Track, streamURL: URL) async {
        guard !offlineIDs.contains(track.id), !downloading.contains(track.id) else { return }
        downloading.insert(track.id)
        defer { downloading.remove(track.id) }
        if await store(from: streamURL, trackID: track.id, in: offlineDir) {
            offlineIDs.insert(track.id)
            UserDefaults.standard.set(Array(offlineIDs), forKey: kOffline)
            if let artURL = track.thumbnailArtworkURL ?? track.artworkURL {
                await saveArtwork(trackID: track.id, from: artURL)
            }
        }
    }

    // MARK: - Delete

    func deleteDownload(trackID: Int) {
        for ext in ["mp3", "m4a"] {
            let u = offlineDir.appendingPathComponent("\(trackID).\(ext)")
            try? FileManager.default.removeItem(at: u)
        }
        let artworkFile = artworkDir.appendingPathComponent("\(trackID).jpg")
        try? FileManager.default.removeItem(at: artworkFile)
        offlineIDs.remove(trackID)
        UserDefaults.standard.set(Array(offlineIDs), forKey: kOffline)
    }

    // MARK: - Prepare export (Save to folder)

    func prepareExport(track: Track, streamURL: URL) async -> URL? {
        let safe = track.title
            .components(separatedBy: CharacterSet(charactersIn: "/:*?\"<>|\\"))
            .joined(separator: "_")
        let ext  = isHLSURL(streamURL) ? "m4a" : "mp3"
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).\(ext)")
        return await fetch(from: streamURL, to: dest) ? dest : nil
    }

    // MARK: - Core

    private func store(from url: URL, trackID: Int, in dir: URL) async -> Bool {
        let ext  = isHLSURL(url) ? "m4a" : "mp3"
        let dest = dir.appendingPathComponent("\(trackID).\(ext)")
        return await fetch(from: url, to: dest)
    }

    private func fetch(from url: URL, to dest: URL) async -> Bool {
        if isValidAudioFile(at: dest) { return true }
        try? FileManager.default.removeItem(at: dest)
        return isHLSURL(url) ? await exportHLS(from: url, to: dest)
                              : await directDownload(from: url, to: dest)
    }

    // MARK: - Helpers

    private func isHLSURL(_ url: URL) -> Bool {
        let s = url.absoluteString
        return url.pathExtension.lowercased() == "m3u8"
            || s.contains(".m3u8")
            || (url.host?.contains("hls") == true && !s.contains("progressive"))
    }

    /// Guards against saving an M3U8 manifest (a few KB) as "cached audio".
    private func isValidAudioFile(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        return size > 50_000
    }

    private func directDownload(from url: URL, to dest: URL) async -> Bool {
        await withCheckedContinuation { cont in
            URLSession.shared.downloadTask(with: url) { local, _, err in
                guard let local, err == nil else { cont.resume(returning: false); return }
                do {
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.moveItem(at: local, to: dest)
                    cont.resume(returning: true)
                } catch {
                    cont.resume(returning: false)
                }
            }.resume()
        }
    }

    private func exportHLS(from url: URL, to dest: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPresetAppleM4A) else {
            return false
        }
        session.outputURL      = dest
        session.outputFileType = .m4a
        let box = SendableExportSession(value: session)
        return await withCheckedContinuation { cont in
            box.value.exportAsynchronously {
                cont.resume(returning: box.value.status == .completed)
            }
        }
    }

    // MARK: - Persistence

    private func loadPersistedIDs() {
        let cached  = Set(UserDefaults.standard.array(forKey: kCached)  as? [Int] ?? [])
        let offline = Set(UserDefaults.standard.array(forKey: kOffline) as? [Int] ?? [])
        // Only keep IDs where a valid audio file actually exists on disk
        cachedIDs  = cached.filter  { localCacheURL(for: $0) != nil }
        offlineIDs = offline.filter { localOfflineURL(for: $0) != nil }
    }
}
