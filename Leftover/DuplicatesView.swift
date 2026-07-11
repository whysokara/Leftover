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
    @State private var appeared = false

    /// Each screen gets its own color identity — teal for Duplicates,
    /// pink for Similar Shots — matching their Home dashboard tiles.
    private var accent: Color {
        mode == .duplicates ? Theme.chipTeal : Theme.chipPink
    }

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
                    LeftoverBuddy(color: accent, expression: .relieved)
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
                        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                            groupCard(group)
                                .cascadeIn(appeared, slot: Double(index))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage)
        .onAppear { appeared = true }
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

            groupThumbFan(group)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: accent.opacity(0.12), radius: 12, y: 4)
    }

    /// A fanned "hand of photos" instead of a flat scrolling row — the
    /// keeper sits largest and frontmost, the rest spread out behind it
    /// with a slight rotation and drop shadow (same kind of transform
    /// math as the swipe screen's card-stack peek).
    private func groupThumbFan(_ group: DuplicateGroup) -> some View {
        let others = group.assets.filter { $0.localIdentifier != group.keeperID }
        let displayedOthers = Array(others.prefix(4))
        let overflow = others.count - displayedOthers.count
        let keeperAsset = group.assets.first { $0.localIdentifier == group.keeperID }

        return HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                ForEach(Array(displayedOthers.enumerated()), id: \.element.localIdentifier) { index, asset in
                    let step = Double(index + 1)
                    fannedThumb(asset, isKeeper: false)
                        .frame(width: 78, height: 78)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? step * 6 : step * -6))
                        .offset(x: step * 22, y: 6 + step * 3)
                        .zIndex(-step)
                }
                if let keeperAsset {
                    fannedThumb(keeperAsset, isKeeper: true)
                        .frame(width: 92, height: 92)
                        .zIndex(10)
                }
            }
            .frame(width: 92 + CGFloat(displayedOthers.count) * 22, height: 112, alignment: .leading)

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Theme.dim)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.raised))
            }
            Spacer(minLength: 0)
        }
    }

    private func fannedThumb(_ asset: PHAsset, isKeeper: Bool) -> some View {
        let id = asset.localIdentifier
        let isMarked = marked.contains(id)

        return Button {
            Haptics.impact(.light)
            withAnimation(Theme.flick) {
                if isMarked { marked.remove(id) } else { marked.insert(id) }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                PhotoThumbnailView(asset: asset)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(isMarked ? 0.5 : 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isMarked ? Theme.toss : (isKeeper ? accent : Theme.surface),
                                          lineWidth: isMarked || isKeeper ? 2.5 : 2)
                    )
                    .shadow(color: Theme.ink.opacity(0.18), radius: 8, y: 4)

                if isMarked {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.toss)
                        .background(Circle().fill(Theme.stage))
                        .padding(4)
                } else if isKeeper {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(accent)
                        .background(Circle().fill(Theme.stage))
                        .padding(4)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isMarked ? "Selected to delete" : (isKeeper ? "Best quality copy" : "Copy"))
        .accessibilityHint("Tap to \(isMarked ? "keep" : "delete") this copy")
    }
}

/// Shared scan-progress block, also used while preparing a blurry session.
/// A breathing ring instead of a flat system progress bar — this was the
/// single flattest screen in the app before.
struct ScanProgress: View {
    @ObservedObject var scanner: LibraryScanner
    @State private var pulse = false

    private var progress: Double {
        scanner.total == 0 ? 0 : Double(scanner.scanned) / Double(scanner.total)
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.cream.opacity(0.12))
                    .scaleEffect(pulse ? 1.1 : 0.92)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .stroke(Theme.hairline, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.cream, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(Theme.settle, value: progress)

                Text("\(Int(progress * 100))%")
                    .font(Theme.display(28))
                    .foregroundColor(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(Theme.settle, value: progress)
            }
            .frame(width: 140, height: 140)
            .onAppear { pulse = true }

            Text("Scanned \(scanner.scanned.formatted()) of \(scanner.total.formatted())")
                .font(.footnote.monospacedDigit())
                .foregroundColor(Theme.dim)
        }
    }
}
