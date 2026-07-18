//
//  DuplicateFinder.swift
//  Leftover
//
//  LibraryScanner: one pass over the library computes a 64-bit dHash
//  and a Laplacian sharpness score per photo, cached as JSON in
//  Application Support (rescans only analyze photos the cache hasn't
//  seen). The grouped products are persisted too (leftover-results.json)
//  with a cheap library fingerprint, so a relaunch restores them
//  instantly instead of redoing the O(n²) grouping — see
//  `restoreThenRefreshIfStale`. Three products fall out of the scan:
//    - duplicateGroups: near-identical photos (Hamming ≤ 5, global)
//    - similarGroups:   rapid-fire series (≤ 10 s apart, Hamming ≤ 16)
//    - blurryAssets:    sharpness below threshold, blurriest first
//

import Foundation
import Photos
import UIKit
import CoreGraphics

struct DuplicateGroup: Identifiable {
    let id = UUID()
    /// Keeper first, then the suggested tosses.
    var assets: [PHAsset]
    var keeperID: String
    var wastedBytes: Int64
}

final class LibraryScanner: ObservableObject {
    @Published var isScanning = false
    @Published var scanned = 0
    @Published var total = 0
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var similarGroups: [DuplicateGroup] = []
    @Published var blurryAssets: [PHAsset] = []
    /// Total bytes the blurry set would free — computed with the scan so
    /// Home can show the clearing scope without touching PHAssetResource
    /// on the main thread.
    @Published var blurryBytes: Int64 = 0
    @Published var hasScanned = false
    /// True while the stored results are being read back. Screens wait on
    /// this instead of racing ahead into a fresh scan they may not need.
    @Published private(set) var isRestoring = false
    /// True while grouping runs after the per-photo hash pass finishes —
    /// lets the UI say something other than a frozen 100%.
    @Published var isGrouping = false
    /// Real fraction complete (0...1) through the O(n²) duplicate-grouping
    /// pass — the only part of a scan whose duration isn't already tracked
    /// by scanned/total, and the one that can visibly run long after the
    /// hash pass hits 100%.
    @Published var groupingProgress: Double = 0

    /// Hamming distance at or below which two hashes are the same photo.
    private static let duplicateThreshold = 5
    /// Looser distance for shots of the same moment.
    private static let similarThreshold = 16
    /// Consecutive photos this close in time form a candidate series.
    private static let similarGapSeconds: TimeInterval = 10
    private static let similarClusterCap = 30
    /// Laplacian variance below this reads as blurry. Conservative on
    /// purpose — false positives erode trust. Tune against a real
    /// library on device.
    static let blurThreshold: Float = 60

    private struct CacheEntry: Codable {
        let h: UInt64   // dHash
        let s: Float    // sharpness (Laplacian variance)
    }
    private struct CacheFile: Codable {
        var version: Int
        var entries: [String: CacheEntry]
    }
    private static let cacheVersion = 2

    private var cache: [String: CacheEntry] = [:]
    private var cacheLoaded = false
    /// Guards a background refresh so it can't overlap a visible scan.
    private var isSilentScanning = false

    /// Cheap stand-in for "has the library changed?". If neither the photo
    /// count nor the newest creation date has moved, nothing worth
    /// regrouping has happened, so the stored results are still true.
    struct LibraryFingerprint: Codable, Equatable {
        var count: Int
        var newest: Double   // timeIntervalSince1970
    }

    /// A group flattened to identifiers — the assets themselves are
    /// re-fetched on restore (PHAssets can't be persisted).
    private struct GroupRecord: Codable {
        var keeper: String
        var members: [String]
    }
    private struct ResultsFile: Codable {
        var version: Int
        var fingerprint: LibraryFingerprint
        var duplicates: [GroupRecord]
        var similar: [GroupRecord]
        var blurry: [String]
    }
    private static let resultsVersion = 1

    private static var cacheURL: URL {
        supportDirectory.appendingPathComponent("leftover-scan.json")
    }
    /// The grouped products, so a relaunch doesn't have to redo the O(n²)
    /// grouping just to show what it already knew.
    private static var resultsURL: URL {
        supportDirectory.appendingPathComponent("leftover-results.json")
    }
    private static var supportDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func currentFingerprint() -> LibraryFingerprint {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetch = PHAsset.fetchAssets(with: .image, options: options)
        return LibraryFingerprint(
            count: fetch.count,
            newest: fetch.firstObject?.creationDate?.timeIntervalSince1970 ?? 0)
    }

    /// `silent` runs the same pass without touching `isScanning`, so a
    /// background refresh never replaces already-restored results with a
    /// progress ring — the old numbers stay on screen until the new ones land.
    func scan(silent: Bool = false) {
        guard !isScanning, !isSilentScanning else { return }
        if silent { isSilentScanning = true } else { isScanning = true }
        loadCache()

        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let fetch = PHAsset.fetchAssets(with: .image, options: options)
            var assets: [PHAsset] = []
            fetch.enumerateObjects { asset, _, _ in assets.append(asset) }

            DispatchQueue.main.async {
                self.total = assets.count
                self.scanned = 0
                self.groupingProgress = 0
            }

            let manager = PHImageManager.default()
            let request = PHImageRequestOptions()
            // .fastFormat returns nil (error 3303) for assets without a
            // materialized small thumbnail; quality doesn't matter here.
            request.deliveryMode = .highQualityFormat
            request.isSynchronous = true
            request.isNetworkAccessAllowed = true
            request.resizeMode = .fast

            var items: [(PHAsset, CacheEntry)] = []
            var newSinceSave = 0
            for (index, asset) in assets.enumerated() {
                if let cached = self.cache[asset.localIdentifier] {
                    items.append((asset, cached))
                } else {
                    var image: UIImage?
                    autoreleasepool {
                        _ = manager.requestImage(for: asset,
                                                 targetSize: CGSize(width: 128, height: 128),
                                                 contentMode: .aspectFill,
                                                 options: request) { result, _ in
                            image = result
                        }
                    }
                    if let image, let analysis = Self.analyze(image) {
                        let entry = CacheEntry(h: analysis.hash, s: analysis.sharpness)
                        items.append((asset, entry))
                        self.cache[asset.localIdentifier] = entry
                        newSinceSave += 1
                        if newSinceSave >= 500 {
                            self.saveCache()
                            newSinceSave = 0
                        }
                    }
                }
                if index % 50 == 0 || index == assets.count - 1 {
                    let done = index + 1
                    DispatchQueue.main.async { self.scanned = done }
                }
            }
            if newSinceSave > 0 { self.saveCache() }

            // Grouping runs after every photo is hashed, so the scanned/total
            // ring is already pinned at 100% for however long this takes —
            // flip a flag so the UI can say so instead of looking hung.
            DispatchQueue.main.async { self.isGrouping = true }

            let sharpnessByID = Dictionary(uniqueKeysWithValues: items.map { ($0.0.localIdentifier, $0.1.s) })
            let duplicates = Self.groupDuplicates(items, sharpness: sharpnessByID) { fraction in
                DispatchQueue.main.async { self.groupingProgress = fraction }
            }
            let similar = Self.groupSimilar(items, sharpness: sharpnessByID)
            let blurry = items
                .filter { $0.1.s < Self.blurThreshold }
                .sorted { $0.1.s < $1.1.s }
                .map(\.0)
            let blurryTotal = blurry.reduce(Int64(0)) { $0 + Self.fileSize($1) }

            // Taken from the very fetch we scanned (sorted newest-first),
            // so the saved fingerprint describes exactly this library state
            // even if photos arrive mid-scan.
            let fingerprint = LibraryFingerprint(
                count: assets.count,
                newest: assets.first?.creationDate?.timeIntervalSince1970 ?? 0)

            DispatchQueue.main.async {
                self.duplicateGroups = duplicates
                self.similarGroups = similar
                self.blurryAssets = blurry
                self.blurryBytes = blurryTotal
                if silent { self.isSilentScanning = false } else { self.isScanning = false }
                self.isGrouping = false
                self.hasScanned = true
                self.persistResults(fingerprint: fingerprint)
            }
        }
    }

    /// Drop deleted assets from every product; groups left with one
    /// photo aren't groups anymore.
    func removeAssets(withIdentifiers ids: Set<String>) {
        duplicateGroups = Self.pruning(duplicateGroups, removing: ids)
        similarGroups = Self.pruning(similarGroups, removing: ids)
        blurryAssets.removeAll { ids.contains($0.localIdentifier) }
        // Sizes are NSCache-cached at this point, so the re-sum is cheap.
        blurryBytes = blurryAssets.reduce(Int64(0)) { $0 + Self.fileSize($1) }
        for id in ids {
            cache.removeValue(forKey: id)
            Self.fileSizeCache.removeObject(forKey: id as NSString)
        }
        saveCache()
        // Deleting moved the library on, so re-measure rather than reuse
        // the fingerprint from the last scan.
        persistResults(fingerprint: nil)
    }

    private static func pruning(_ groups: [DuplicateGroup], removing ids: Set<String>) -> [DuplicateGroup] {
        groups.compactMap { group in
            var group = group
            group.assets.removeAll { ids.contains($0.localIdentifier) }
            guard group.assets.count > 1 else { return nil }
            if !group.assets.contains(where: { $0.localIdentifier == group.keeperID }) {
                group.keeperID = group.assets[0].localIdentifier
            }
            group.wastedBytes = group.assets
                .filter { $0.localIdentifier != group.keeperID }
                .reduce(Int64(0)) { $0 + fileSize($1) }
            return group
        }
    }

    // MARK: - Per-photo analysis

    private static let analysisSize = 128

    /// One grayscale render feeds both metrics: a 9×8 block-averaged
    /// dHash and the variance of a 3×3 Laplacian (sharpness).
    static func analyze(_ image: UIImage) -> (hash: UInt64, sharpness: Float)? {
        guard let cg = image.cgImage else { return nil }
        let n = analysisSize
        var gray = [UInt8](repeating: 0, count: n * n)
        guard let context = CGContext(data: &gray,
                                      width: n, height: n,
                                      bitsPerComponent: 8, bytesPerRow: n,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))

        // dHash on a 9×8 reduction
        let hw = 9, hh = 8
        let bx = n / hw, by = n / hh
        var reduced = [Float](repeating: 0, count: hw * hh)
        for gy in 0..<hh {
            for gx in 0..<hw {
                var sum = 0
                for y in (gy * by)..<((gy + 1) * by) {
                    for x in (gx * bx)..<((gx + 1) * bx) {
                        sum += Int(gray[y * n + x])
                    }
                }
                reduced[gy * hw + gx] = Float(sum) / Float(bx * by)
            }
        }
        var hash: UInt64 = 0
        var bit: UInt64 = 0
        for y in 0..<hh {
            for x in 0..<(hw - 1) {
                if reduced[y * hw + x] > reduced[y * hw + x + 1] {
                    hash |= (1 << bit)
                }
                bit += 1
            }
        }

        // Sharpness: variance of the 3×3 Laplacian response
        var sum = 0.0, sumSq = 0.0
        let count = Double((n - 2) * (n - 2))
        for y in 1..<(n - 1) {
            for x in 1..<(n - 1) {
                let lap = 4 * Int(gray[y * n + x])
                    - Int(gray[(y - 1) * n + x]) - Int(gray[(y + 1) * n + x])
                    - Int(gray[y * n + x - 1]) - Int(gray[y * n + x + 1])
                let d = Double(lap)
                sum += d
                sumSq += d * d
            }
        }
        let mean = sum / count
        let variance = sumSq / count - mean * mean
        return (hash, Float(variance))
    }

    // MARK: - Grouping

    /// Path-halving union-find: partitions `0..<count` into clusters
    /// wherever `shouldMerge` says two indices belong together. O(n²)
    /// on cheap comparisons — fine into the tens of thousands of photos;
    /// the cache keeps the expensive part (image loads) incremental.
    private static func unionFindClusters(count: Int, onProgress: ((Double) -> Void)? = nil,
                                          shouldMerge: (Int, Int) -> Bool) -> [[Int]] {
        var parent = Array(0..<count)
        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }

        for i in 0..<count {
            for j in (i + 1)..<count where shouldMerge(i, j) {
                let ri = find(i), rj = find(j)
                if ri != rj { parent[ri] = rj }
            }
            // Reporting every iteration would flood the main queue with
            // Dispatch work for a progress bar nobody can read that fast.
            if i % 200 == 0 || i == count - 1 {
                onProgress?(Double(i + 1) / Double(count))
            }
        }

        var buckets: [Int: [Int]] = [:]
        for i in 0..<count {
            buckets[find(i), default: []].append(i)
        }
        return Array(buckets.values)
    }

    private static func groupDuplicates(_ items: [(PHAsset, CacheEntry)],
                                        sharpness: [String: Float],
                                        onProgress: ((Double) -> Void)? = nil) -> [DuplicateGroup] {
        let indexClusters = unionFindClusters(count: items.count, onProgress: onProgress) { i, j in
            (items[i].1.h ^ items[j].1.h).nonzeroBitCount <= duplicateThreshold
        }
        let memberSets = indexClusters.map { indices in indices.map { items[$0].0 } }
        return makeGroups(from: memberSets, sharpness: sharpness)
    }

    /// Rapid-fire series: cluster by shot time first, then group loosely
    /// by hash within each cluster.
    private static func groupSimilar(_ items: [(PHAsset, CacheEntry)],
                                     sharpness: [String: Float]) -> [DuplicateGroup] {
        let sorted = items.sorted {
            ($0.0.creationDate ?? .distantPast) < ($1.0.creationDate ?? .distantPast)
        }

        var timeClusters: [[(PHAsset, UInt64)]] = []
        var current: [(PHAsset, UInt64)] = []
        var lastDate: Date?
        for (asset, entry) in sorted {
            let date = asset.creationDate ?? .distantPast
            if let last = lastDate,
               date.timeIntervalSince(last) <= similarGapSeconds,
               current.count < similarClusterCap {
                current.append((asset, entry.h))
            } else {
                if current.count > 1 { timeClusters.append(current) }
                current = [(asset, entry.h)]
            }
            lastDate = date
        }
        if current.count > 1 { timeClusters.append(current) }

        // Chain consecutive shots rather than clustering all pairs in the
        // time bucket — similarThreshold is loose (25% of the hash), so
        // all-pairs union-find could transitively bridge A→B→C into one
        // group even when A and C don't actually look alike.
        var memberSets: [[PHAsset]] = []
        for cluster in timeClusters {
            var chain: [(PHAsset, UInt64)] = [cluster[0]]
            for item in cluster.dropFirst() {
                if (item.1 ^ chain.last!.1).nonzeroBitCount <= similarThreshold {
                    chain.append(item)
                } else {
                    if chain.count > 1 { memberSets.append(chain.map(\.0)) }
                    chain = [item]
                }
            }
            if chain.count > 1 { memberSets.append(chain.map(\.0)) }
        }
        return makeGroups(from: memberSets, sharpness: sharpness)
    }

    private static func makeGroups(from memberSets: [[PHAsset]],
                                   sharpness: [String: Float]) -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        for members in memberSets where members.count > 1 {
            // Keeper: highest resolution, then sharpest, then favorite,
            // then newest.
            let keeper = members.max { a, b in
                let ra = a.pixelWidth * a.pixelHeight
                let rb = b.pixelWidth * b.pixelHeight
                if ra != rb { return ra < rb }
                let sa = sharpness[a.localIdentifier] ?? 0
                let sb = sharpness[b.localIdentifier] ?? 0
                if sa != sb { return sa < sb }
                if a.isFavorite != b.isFavorite { return b.isFavorite }
                return (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
            }!
            let ordered = [keeper] + members.filter { $0.localIdentifier != keeper.localIdentifier }
            let wasted = ordered.dropFirst().reduce(Int64(0)) { $0 + fileSize($1) }
            groups.append(DuplicateGroup(assets: ordered,
                                         keeperID: keeper.localIdentifier,
                                         wastedBytes: wasted))
        }
        return groups.sorted { $0.wastedBytes > $1.wastedBytes }
    }

    /// NSCache is thread-safe out of the box (unlike a plain Dictionary)
    /// and evicts under memory pressure — this is called from multiple
    /// background queues (scan, home-data load) plus the main thread
    /// (live swipe-session size tracking).
    private static let fileSizeCache = NSCache<NSString, NSNumber>()

    static func fileSize(_ asset: PHAsset) -> Int64 {
        let key = asset.localIdentifier as NSString
        if let cached = fileSizeCache.object(forKey: key) {
            return cached.int64Value
        }
        let size = PHAssetResource.assetResources(for: asset)
            .compactMap { $0.value(forKey: "fileSize") as? Int64 }
            .first ?? 0
        fileSizeCache.setObject(NSNumber(value: size), forKey: key)
        return size
    }

    // MARK: - Persisted results

    /// Call once the library is readable. Rebuilds the last scan's products
    /// from disk so Duplicates/Similar/Blurry open instantly on relaunch,
    /// then — only if the library has actually changed since — refreshes
    /// them quietly in the background. A first-ever run finds nothing and
    /// leaves `hasScanned` false, so the user still scans once, on demand.
    func restoreThenRefreshIfStale() {
        restoreResults { [weak self] restored, isFresh in
            guard let self, restored, !isFresh else { return }
            self.scan(silent: true)
        }
    }

    /// Reads the stored products and re-fetches their assets. `completion`
    /// reports whether anything was restored, and whether the library still
    /// matches the fingerprint those results were computed from.
    private func restoreResults(completion: @escaping (_ restored: Bool, _ isFresh: Bool) -> Void) {
        guard !hasScanned, !isRestoring else { return completion(false, true) }
        isRestoring = true
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: Self.resultsURL),
                  let file = try? JSONDecoder().decode(ResultsFile.self, from: data),
                  file.version == Self.resultsVersion else {
                DispatchQueue.main.async {
                    self.isRestoring = false
                    completion(false, false)
                }
                return
            }

            // One batch fetch for every identifier the file mentions;
            // anything deleted since simply won't come back.
            let ids = Set(file.duplicates.flatMap(\.members)
                          + file.similar.flatMap(\.members)
                          + file.blurry)
            var byID: [String: PHAsset] = [:]
            PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil)
                .enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }

            let duplicates = Self.rebuild(file.duplicates, from: byID)
            let similar = Self.rebuild(file.similar, from: byID)
            let blurry = file.blurry.compactMap { byID[$0] }
            let blurryTotal = blurry.reduce(Int64(0)) { $0 + Self.fileSize($1) }
            let isFresh = Self.currentFingerprint() == file.fingerprint

            DispatchQueue.main.async {
                self.duplicateGroups = duplicates
                self.similarGroups = similar
                self.blurryAssets = blurry
                self.blurryBytes = blurryTotal
                self.hasScanned = true
                self.isRestoring = false
                completion(true, isFresh)
            }
        }
    }

    private static func rebuild(_ records: [GroupRecord],
                                from byID: [String: PHAsset]) -> [DuplicateGroup] {
        records.compactMap { record -> DuplicateGroup? in
            let members = record.members.compactMap { byID[$0] }
            guard members.count > 1 else { return nil }
            // Keeper first, matching how a fresh scan orders a group.
            let keeperID = members.contains { $0.localIdentifier == record.keeper }
                ? record.keeper : members[0].localIdentifier
            let ordered = members.filter { $0.localIdentifier == keeperID }
                + members.filter { $0.localIdentifier != keeperID }
            let wasted = ordered.dropFirst().reduce(Int64(0)) { $0 + fileSize($1) }
            return DuplicateGroup(assets: ordered, keeperID: keeperID, wastedBytes: wasted)
        }
        .sorted { $0.wastedBytes > $1.wastedBytes }
    }

    /// Snapshots the current products to disk. Pass the fingerprint the
    /// products were computed against; omit it to measure the library now
    /// (used after a delete, which changes the count).
    private func persistResults(fingerprint: LibraryFingerprint?) {
        let records: ([GroupRecord], [GroupRecord], [String]) = (
            duplicateGroups.map { GroupRecord(keeper: $0.keeperID, members: $0.assets.map(\.localIdentifier)) },
            similarGroups.map { GroupRecord(keeper: $0.keeperID, members: $0.assets.map(\.localIdentifier)) },
            blurryAssets.map(\.localIdentifier)
        )
        DispatchQueue.global(qos: .utility).async {
            let file = ResultsFile(version: Self.resultsVersion,
                                   fingerprint: fingerprint ?? Self.currentFingerprint(),
                                   duplicates: records.0,
                                   similar: records.1,
                                   blurry: records.2)
            guard let data = try? JSONEncoder().encode(file) else { return }
            try? data.write(to: Self.resultsURL, options: .atomic)
        }
    }

    // MARK: - Cache

    private func loadCache() {
        guard !cacheLoaded else { return }
        cacheLoaded = true
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let decoded = try? JSONDecoder().decode(CacheFile.self, from: data),
              decoded.version == Self.cacheVersion else { return }
        cache = decoded.entries
    }

    private func saveCache() {
        let file = CacheFile(version: Self.cacheVersion, entries: cache)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
    }
}
