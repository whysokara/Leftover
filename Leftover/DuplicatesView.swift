//
//  DuplicatesView.swift
//  Leftover
//
//  Phase 3c: group review. The best-guess keeper is preselected and
//  the rest are marked to toss; tap any photo to flip it. One batch
//  delete across all groups.
//

import SwiftUI
import Photos

struct DuplicatesView: View {
    @ObservedObject var finder: DuplicateFinder
    let onClose: () -> Void
    let onToss: ([PHAsset], Int64) -> Void

    /// localIdentifiers currently marked to toss, across all groups.
    @State private var marked: Set<String> = []
    @State private var seededFromGroups = false

    private var markedAssets: [PHAsset] {
        finder.groups.flatMap(\.assets).filter { marked.contains($0.localIdentifier) }
    }
    private var markedBytes: Int64 {
        markedAssets.reduce(0) { $0 + DuplicateFinder.fileSize($1) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if finder.isScanning {
                Spacer()
                VStack(spacing: 14) {
                    ProgressView(value: finder.total == 0 ? 0 : Double(finder.scanned) / Double(finder.total))
                        .tint(Theme.cream)
                        .frame(width: 200)
                    Text("Scanned \(finder.scanned.formatted()) / \(finder.total.formatted())")
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(Theme.dim)
                }
                Spacer()
            } else if finder.groups.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.keep)
                    Text("No duplicates.")
                        .font(Theme.title)
                        .foregroundColor(Theme.ink)
                    Text("Every photo here is one of a kind.")
                        .font(.subheadline)
                        .foregroundColor(Theme.dim)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(finder.groups) { group in
                            groupCard(group)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage)
        .overlay(alignment: .bottom) {
            if !marked.isEmpty {
                Button("Toss \(marked.count) · frees \(ByteCountFormatter.string(fromByteCount: markedBytes, countStyle: .file))") {
                    onToss(markedAssets, markedBytes)
                }
                .buttonStyle(TossButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.settle, value: marked.isEmpty)
        .onAppear {
            if finder.hasScanned {
                seedMarks()
            } else {
                finder.scan()
            }
        }
        .onChange(of: finder.hasScanned) { done in
            if done { seedMarks() }
        }
        .onChange(of: finder.groups.count) { _ in
            // After a delete, drop marks that no longer exist.
            let alive = Set(finder.groups.flatMap(\.assets).map(\.localIdentifier))
            marked = marked.intersection(alive)
        }
    }

    /// Preselect everything except each group's keeper.
    private func seedMarks() {
        guard !seededFromGroups else { return }
        seededFromGroups = true
        marked = Set(finder.groups.flatMap { group in
            group.assets
                .map(\.localIdentifier)
                .filter { $0 != group.keeperID }
        })
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Back to home")

            Text("Duplicates")
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            Spacer()

            if !finder.isScanning && !finder.groups.isEmpty {
                Text("\(finder.groups.count.formatted()) groups")
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(Theme.dim)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func groupCard(_ group: DuplicateGroup) -> some View {
        let groupIDs = group.assets.map(\.localIdentifier)
        let tossCount = groupIDs.filter { marked.contains($0) }.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(group.assets.count) copies · \(ByteCountFormatter.string(fromByteCount: group.wastedBytes, countStyle: .file)) wasted")
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(Theme.dim)
                Spacer()
                Button(tossCount == 0 ? "Kept" : "Keep all") {
                    Haptics.impact(.soft)
                    marked.subtract(groupIDs)
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(tossCount == 0 ? Theme.dim : Theme.cream)
                .disabled(tossCount == 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.assets, id: \.localIdentifier) { asset in
                        duplicateThumb(asset, isKeeper: asset.localIdentifier == group.keeperID)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private func duplicateThumb(_ asset: PHAsset, isKeeper: Bool) -> some View {
        let id = asset.localIdentifier
        let isMarked = marked.contains(id)

        return Button {
            Haptics.impact(.light)
            if isMarked { marked.remove(id) } else { marked.insert(id) }
        } label: {
            ZStack(alignment: .topTrailing) {
                PhotoThumbnailView(asset: asset)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .opacity(isMarked ? 0.55 : 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isMarked ? Theme.toss : (isKeeper ? Theme.cream : Theme.hairline),
                                          lineWidth: isMarked || isKeeper ? 2 : 1)
                    )

                Image(systemName: isMarked ? "trash.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isMarked ? Theme.toss : Theme.keep)
                    .background(Circle().fill(Theme.stage))
                    .padding(5)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isMarked ? "Marked to toss" : (isKeeper ? "Keeping, best quality" : "Keeping"))
        .accessibilityHint("Tap to \(isMarked ? "keep" : "toss") this copy")
    }
}
