//
//  DuplicateFinder.swift
//  Leftover
//
//  Perceptual-hash (dHash) duplicate engine. Hashes are cached as
//  localIdentifier → hash JSON in Application Support so rescans only
//  hash photos the cache hasn't seen.
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

final class DuplicateFinder: ObservableObject {
    @Published var isScanning = false
    @Published var scanned = 0
    @Published var total = 0
    @Published var groups: [DuplicateGroup] = []
    @Published var hasScanned = false

    /// Hamming distance at or below which two hashes count as duplicates.
    private static let threshold = 5

    private var hashCache: [String: UInt64] = [:]

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("leftover-dhash.json")
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
            // materialized small thumbnail — quality is irrelevant for a
            // 9×8 hash, so ask for the real image.
            request.deliveryMode = .highQualityFormat
            request.isSynchronous = true
            request.isNetworkAccessAllowed = true
            request.resizeMode = .fast

            var hashes: [(PHAsset, UInt64)] = []
            var newSinceSave = 0
            for (index, asset) in assets.enumerated() {
                if let cached = self.hashCache[asset.localIdentifier] {
                    hashes.append((asset, cached))
                } else {
                    var image: UIImage?
                    autoreleasepool {
                        _ = manager.requestImage(for: asset,
                                                 targetSize: CGSize(width: 64, height: 64),
                                                 contentMode: .aspectFill,
                                                 options: request) { result, _ in
                            image = result
                        }
                    }
                    if let image, let hash = Self.dHash(image) {
                        hashes.append((asset, hash))
                        self.hashCache[asset.localIdentifier] = hash
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

            let groups = Self.group(hashes)
            DispatchQueue.main.async {
                self.groups = groups
                self.isScanning = false
                self.hasScanned = true
            }
        }
    }

    /// Drop deleted assets from the groups; groups left with one photo
    /// aren't duplicates anymore.
    func removeAssets(withIdentifiers ids: Set<String>) {
        groups = groups.compactMap { group in
            var group = group
            group.assets.removeAll { ids.contains($0.localIdentifier) }
            guard group.assets.count > 1 else { return nil }
            if !group.assets.contains(where: { $0.localIdentifier == group.keeperID }) {
                group.keeperID = group.assets[0].localIdentifier
            }
            group.wastedBytes = group.assets
                .filter { $0.localIdentifier != group.keeperID }
                .reduce(Int64(0)) { $0 + Self.fileSize($1) }
            return group
        }
        for id in ids { hashCache.removeValue(forKey: id) }
        saveCache()
    }

    // MARK: - Hashing

    /// 64-bit dHash: 9×8 grayscale, each bit is "left pixel brighter
    /// than its right neighbor".
    static func dHash(_ image: UIImage) -> UInt64? {
        guard let cg = image.cgImage else { return nil }
        let width = 9, height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &pixels,
                                      width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        var bit: UInt64 = 0
        for y in 0..<height {
            for x in 0..<(width - 1) {
                if pixels[y * width + x] > pixels[y * width + x + 1] {
                    hash |= (1 << bit)
                }
                bit += 1
            }
        }
        return hash
    }

    // MARK: - Grouping

    // Union-find over pairwise Hamming distance. O(n²) on cheap UInt64
    // ops — fine into the tens of thousands of photos; the hash cache
    // keeps the expensive part (image loads) incremental.
    static func group(_ items: [(PHAsset, UInt64)]) -> [DuplicateGroup] {
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
            let hi = items[i].1
            for j in (i + 1)..<n {
                if (hi ^ items[j].1).nonzeroBitCount <= threshold {
                    let ri = find(i), rj = find(j)
                    if ri != rj { parent[ri] = rj }
                }
            }
        }

        var buckets: [Int: [PHAsset]] = [:]
        for i in 0..<n {
            buckets[find(i), default: []].append(items[i].0)
        }

        var groups: [DuplicateGroup] = []
        for members in buckets.values where members.count > 1 {
            // Keeper: highest resolution, then favorite, then newest.
            let keeper = members.max { a, b in
                let ra = a.pixelWidth * a.pixelHeight
                let rb = b.pixelWidth * b.pixelHeight
                if ra != rb { return ra < rb }
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
        guard hashCache.isEmpty,
              let data = try? Data(contentsOf: Self.cacheURL),
              let decoded = try? JSONDecoder().decode([String: UInt64].self, from: data) else { return }
        hashCache = decoded
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(hashCache) else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
    }
}
