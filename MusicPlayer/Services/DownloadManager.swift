import Foundation

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

    private init() {
        try? FileManager.default.createDirectory(at: cacheDir,   withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: offlineDir, withIntermediateDirectories: true)
        loadPersistedIDs()
    }

    // MARK: - Query

    func localURL(for trackID: Int) -> URL? {
        localOfflineURL(for: trackID) ?? localCacheURL(for: trackID)
    }

    func localCacheURL(for trackID: Int) -> URL? {
        let u = cacheDir.appendingPathComponent("\(trackID).mp3")
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    func localOfflineURL(for trackID: Int) -> URL? {
        let u = offlineDir.appendingPathComponent("\(trackID).mp3")
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    // MARK: - Save to cache

    func saveToCache(track: Track, streamURL: URL) async {
        guard !cachedIDs.contains(track.id), !downloading.contains(track.id) else { return }
        downloading.insert(track.id)
        let dest = cacheDir.appendingPathComponent("\(track.id).mp3")
        if await rawDownload(from: streamURL, to: dest) {
            cachedIDs.insert(track.id)
            UserDefaults.standard.set(Array(cachedIDs), forKey: kCached)
        }
        downloading.remove(track.id)
    }

    // MARK: - Download offline

    func downloadOffline(track: Track, streamURL: URL) async {
        guard !offlineIDs.contains(track.id), !downloading.contains(track.id) else { return }
        downloading.insert(track.id)
        let dest = offlineDir.appendingPathComponent("\(track.id).mp3")
        if await rawDownload(from: streamURL, to: dest) {
            offlineIDs.insert(track.id)
            UserDefaults.standard.set(Array(offlineIDs), forKey: kOffline)
        }
        downloading.remove(track.id)
    }

    // MARK: - Prepare export (Save to folder)

    func prepareExport(track: Track, streamURL: URL) async -> URL? {
        let safe = track.title
            .components(separatedBy: CharacterSet(charactersIn: "/:*?\"<>|\\"))
            .joined(separator: "_")
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).mp3")
        return await rawDownload(from: streamURL, to: dest) ? dest : nil
    }

    // MARK: - Internal

    @discardableResult
    private func rawDownload(from url: URL, to dest: URL) async -> Bool {
        if FileManager.default.fileExists(atPath: dest.path) { return true }
        return await withCheckedContinuation { cont in
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

    private func loadPersistedIDs() {
        let cached  = Set(UserDefaults.standard.array(forKey: kCached)  as? [Int] ?? [])
        let offline = Set(UserDefaults.standard.array(forKey: kOffline) as? [Int] ?? [])
        cachedIDs  = cached.filter  { FileManager.default.fileExists(atPath: cacheDir.appendingPathComponent("\($0).mp3").path) }
        offlineIDs = offline.filter { FileManager.default.fileExists(atPath: offlineDir.appendingPathComponent("\($0).mp3").path) }
    }
}
