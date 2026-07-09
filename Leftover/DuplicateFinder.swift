//
//  DuplicateFinder.swift
//  Leftover
//
//  LibraryScanner: one pass over the library computes a 64-bit dHash
//  and a Laplacian sharpness score per photo, cached as JSON in
//  Application Support (rescans only analyze photos the cache hasn't
//  seen). Three products fall out of the scan:
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
    @Published var hasScanned = false

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

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("leftover-scan.json")
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
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

            let sharpnessByID = Dictionary(uniqueKeysWithValues: items.map { ($0.0.localIdentifier, $0.1.s) })
            let duplicates = Self.groupDuplicates(items, sharpness: sharpnessByID)
            let similar = Self.groupSimilar(items, sharpness: sharpnessByID)
            let blurry = items
                .filter { $0.1.s < Self.blurThreshold }
                .sorted { $0.1.s < $1.1.s }
                .map(\.0)

            DispatchQueue.main.async {
                self.duplicateGroups = duplicates
                self.similarGroups = similar
                self.blurryAssets = blurry
                self.isScanning = false
                self.hasScanned = true
            }
        }
    }

    /// Drop deleted assets from every product; groups left with one
    /// photo aren't groups anymore.
    func removeAssets(withIdentifiers ids: Set<String>) {
        duplicateGroups = Self.pruning(duplicateGroups, removing: ids)
        similarGroups = Self.pruning(similarGroups, removing: ids)
        blurryAssets.removeAll { ids.contains($0.localIdentifier) }
        for id in ids { cache.removeValue(forKey: id) }
        saveCache()
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

    // Union-find over pairwise Hamming distance. O(n²) on cheap UInt64
    // ops — fine into the tens of thousands of photos; the cache keeps
    // the expensive part (image loads) incremental.
    private static func groupDuplicates(_ items: [(PHAsset, CacheEntry)],
                                        sharpness: [String: Float]) -> [DuplicateGroup] {
        let n = items.count
        var parent = Array(0..<n)
        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }

        for i in 0..<n {
            let hi = items[i].1.h
            for j in (i + 1)..<n {
                if (hi ^ items[j].1.h).nonzeroBitCount <= duplicateThreshold {
                    let ri = find(i), rj = find(j)
                    if ri != rj { parent[ri] = rj }
                }
            }
        }

        var buckets: [Int: [PHAsset]] = [:]
        for i in 0..<n {
            buckets[find(i), default: []].append(items[i].0)
        }
        return makeGroups(from: Array(buckets.values), sharpness: sharpness)
    }

    /// Rapid-fire series: cluster by shot time first, then group loosely
    /// by hash within each cluster.
    private static func groupSimilar(_ items: [(PHAsset, CacheEntry)],
                                     sharpness: [String: Float]) -> [DuplicateGroup] {
        let sorted = items.sorted {
            ($0.0.creationDate ?? .distantPast) < ($1.0.creationDate ?? .distantPast)
        }

        var clusters: [[(PHAsset, UInt64)]] = []
        var current: [(PHAsset, UInt64)] = []
        var lastDate: Date?
        for (asset, entry) in sorted {
            let date = asset.creationDate ?? .distantPast
            if let last = lastDate,
               date.timeIntervalSince(last) <= similarGapSeconds,
               current.count < similarClusterCap {
                current.append((asset, entry.h))
            } else {
                if current.count > 1 { clusters.append(current) }
                current = [(asset, entry.h)]
            }
            lastDate = date
        }
        if current.count > 1 { clusters.append(current) }

        var memberSets: [[PHAsset]] = []
        for cluster in clusters {
            let n = cluster.count
            var parent = Array(0..<n)
            func find(_ x: Int) -> Int {
                var x = x
                while parent[x] != x {
                    parent[x] = parent[parent[x]]
                    x = parent[x]
                }
                return x
            }
            for i in 0..<n {
                for j in (i + 1)..<n {
                    if (cluster[i].1 ^ cluster[j].1).nonzeroBitCount <= similarThreshold {
                        let ri = find(i), rj = find(j)
                        if ri != rj { parent[ri] = rj }
                    }
                }
            }
            var buckets: [Int: [PHAsset]] = [:]
            for i in 0..<n {
                buckets[find(i), default: []].append(cluster[i].0)
            }
            memberSets.append(contentsOf: buckets.values.filter { $0.count > 1 })
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

    static func fileSize(_ asset: PHAsset) -> Int64 {
        PHAssetResource.assetResources(for: asset)
            .compactMap { $0.value(forKey: "fileSize") as? Int64 }
            .first ?? 0
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
