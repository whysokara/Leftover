//
//  DuplicatesView.swift
//  Leftover
//
//  GroupReviewView: group review for both Duplicates and Similar
//  Shots. The best-guess keeper is preselected and the rest are marked
//  to toss; tap any photo to flip it. One batch delete across groups.
//

import SwiftUI
import Photos

enum GroupReviewMode {
    case duplicates
    case similar

    var title: String {
        switch self {
        case .duplicates: return "Duplicates"
        case .similar:    return "Similar Shots"
        }
    }
    var emptyIcon: String {
        switch self {
        case .duplicates: return "checkmark.seal"
        case .similar:    return "sparkles"
        }
    }
    var emptyTitle: String {
        switch self {
        case .duplicates: return "No Duplicates"
        case .similar:    return "No Similar Photos"
        }
    }
    var emptySubtitle: String {
        switch self {
        case .duplicates: return "No duplicate photos found."
        case .similar:    return "No similar photos found."
        }
    }
}

struct GroupReviewView: View {
    @ObservedObject var scanner: LibraryScanner
    let mode: GroupReviewMode
    let onClose: () -> Void
    let onToss: ([PHAsset], Int64) -> Void

    /// localIdentifiers currently marked to toss, across all groups.
    /// Nothing is marked by default — tossing is always the user's call.
    @State private var marked: Set<String> = []

    private var groups: [DuplicateGroup] {
        switch mode {
        case .duplicates: return scanner.duplicateGroups
        case .similar:    return scanner.similarGroups
        }
    }
    private var markedAssets: [PHAsset] {
        groups.flatMap(\.assets).filter { marked.contains($0.localIdentifier) }
    }
    private var markedBytes: Int64 {
        markedAssets.reduce(0) { $0 + LibraryScanner.fileSize($1) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if scanner.isScanning {
                Spacer()
                ScanProgress(scanner: scanner)
                Spacer()
            } else if groups.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: mode.emptyIcon)
                        .font(.system(size: 36))
                        .foregroundColor(Theme.keep)
                    Text(mode.emptyTitle)
                        .font(Theme.title)
                        .foregroundColor(Theme.ink)
                    Text(mode.emptySubtitle)
                        .font(.subheadline)
                        .foregroundColor(Theme.dim)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(groups) { group in
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
                Button("Delete \(marked.count) · \(ByteCountFormatter.string(fromByteCount: markedBytes, countStyle: .file))") {
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
            if !scanner.hasScanned {
                scanner.scan()
            }
        }
        .onChange(of: groups.count) { _ in
            // After a delete, drop marks that no longer exist.
            let alive = Set(groups.flatMap(\.assets).map(\.localIdentifier))
            marked = marked.intersection(alive)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            BackButton(action: onClose)

            Text(mode.title)
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            Spacer()

            if !scanner.isScanning && !groups.isEmpty {
                Text("\(groups.count.formatted()) groups")
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
                Text("\(group.assets.count) \(mode == .duplicates ? "copies" : "shots") · \(ByteCountFormatter.string(fromByteCount: group.wastedBytes, countStyle: .file)) wasted")
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(Theme.dim)
                Spacer()
                // Nothing is marked by default; "Delete Rest" marks every
                // copy except the keeper in one tap.
                Button(tossCount == 0 ? "Delete Rest" : "Keep All") {
                    Haptics.impact(.soft)
                    if tossCount == 0 {
                        marked.formUnion(groupIDs.filter { $0 != group.keeperID })
                    } else {
                        marked.subtract(groupIDs)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(tossCount == 0 ? Theme.toss : Theme.cream)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.assets, id: \.localIdentifier) { asset in
                        groupThumb(asset, isKeeper: asset.localIdentifier == group.keeperID)
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

    private func groupThumb(_ asset: PHAsset, isKeeper: Bool) -> some View {
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
                            .strokeBorder(isMarked ? Theme.toss : Theme.hairline,
                                          lineWidth: isMarked ? 2 : 1)
                    )

                if isMarked {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.toss)
                        .background(Circle().fill(Theme.stage))
                        .padding(5)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isMarked ? "Selected to delete" : (isKeeper ? "Best quality copy" : "Copy"))
        .accessibilityHint("Tap to \(isMarked ? "keep" : "delete") this copy")
    }
}

/// Shared scan-progress block, also used while preparing a blurry session.
struct ScanProgress: View {
    @ObservedObject var scanner: LibraryScanner

    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: scanner.total == 0 ? 0 : Double(scanner.scanned) / Double(scanner.total))
                .tint(Theme.cream)
                .frame(width: 200)
            Text("Scanned \(scanner.scanned.formatted()) / \(scanner.total.formatted())")
                .font(.footnote.monospacedDigit())
                .foregroundColor(Theme.dim)
        }
    }
}
