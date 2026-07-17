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
    @State private var showDeleteConfirm = false

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
        .edgeSwipeBack(action: onClose)
        .onAppear { appeared = true }
        .overlay(alignment: .bottom) {
            if !marked.isEmpty {
                Button("Delete \(marked.count) · \(ByteCountFormatter.string(fromByteCount: markedBytes, countStyle: .file))") {
                    showDeleteConfirm = true
                }
                .buttonStyle(TossButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Same confirm step as the swipe screen — every delete in the
        // app asks once, shows the size, and notes the 30-day safety net.
        .alert("Delete \(marked.count) Photos?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onToss(markedAssets, markedBytes)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This frees \(ByteCountFormatter.string(fromByteCount: markedBytes, countStyle: .file)). They'll stay in Recently Deleted for 30 days, so you can still restore them from Photos.")
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

            groupThumbRow(group)
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

    /// Every photo in the group at the same size, in a normal scrolling
    /// row — the keeper is first and marked with a star badge, but isn't
    /// enlarged or overlapped by the others. A fanned/overlapping layout
    /// was tried here and repeatedly made it impossible to actually see
    /// enough of each photo to judge it, especially on a phone-width
    /// card; scrolling guarantees every photo is fully visible instead
    /// of hidden behind the next one or a "+N" count.
    private func groupThumbRow(_ group: DuplicateGroup) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // group.assets is keeper-first (see makeGroups in
                // DuplicateFinder.swift), so no re-sorting needed here.
                ForEach(group.assets, id: \.localIdentifier) { asset in
                    groupThumb(asset, isKeeper: asset.localIdentifier == group.keeperID)
                        .frame(width: 84, height: 84)
                }
            }
        }
    }

    private func groupThumb(_ asset: PHAsset, isKeeper: Bool) -> some View {
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

                // White backing — the SF `.circle.fill` glyphs render
                // their symbol as a cutout, so a dark backing made the
                // star/trash read as black holes on the dark canvas.
                if isMarked {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.toss)
                        .background(Circle().fill(.white))
                        .padding(4)
                } else if isKeeper {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(accent)
                        .background(Circle().fill(.white))
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

    // The hash pass (scanned/total) and the grouping pass (groupingProgress)
    // are two real, separately-tracked phases of the same scan — split the
    // ring evenly between them instead of hitting 100% once hashing
    // finishes and sitting frozen while grouping (often the slower half
    // for a large library) runs invisibly afterward.
    private var progress: Double {
        guard scanner.total > 0 else { return 0 }
        let hashProgress = Double(scanner.scanned) / Double(scanner.total)
        guard scanner.isGrouping else { return hashProgress / 2 }
        return 0.5 + scanner.groupingProgress / 2
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
                    // The icon's neon gradient, carried into the arc —
                    // the same brand mark language as NeonCardMark.
                    .stroke(AngularGradient(colors: [Theme.chipOrange, Theme.chipPink, Theme.chipPurple],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
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

            Text(scanner.isGrouping
                 ? "Finding matches…"
                 : "Scanned \(scanner.scanned.formatted()) of \(scanner.total.formatted())")
                .font(.footnote.monospacedDigit())
                .foregroundColor(Theme.dim)
        }
    }
}
