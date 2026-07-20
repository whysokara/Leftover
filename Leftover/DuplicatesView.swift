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
import UIKit

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
                VStack(spacing: Theme.Space.md) {
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
                // A short result (one or two groups) used to strand at the
                // top with a screen of void below. Centering the stack in
                // the available height frames it instead; a taller result
                // outgrows the min-height and scrolls from the top as
                // before. The bottom inset clears the floating delete pill.
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: Theme.Space.lg) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                groupCard(group)
                                    .cascadeIn(appeared, slot: Double(index))
                            }
                        }
                        .padding(.horizontal, Theme.screenMargin)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height - 96, alignment: .center)
                        .padding(.bottom, 96)
                    }
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
                .padding(.horizontal, Theme.screenMargin)
                .padding(.bottom, Theme.Space.md)
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
        // Wait for a restore in flight — the stored results usually make a
        // scan unnecessary. If none came back, scan once it settles.
        .onAppear { scanIfNeeded() }
        .onChange(of: scanner.isRestoring) { _ in scanIfNeeded() }
        .onChange(of: groups.count) { _ in
            // After a delete, drop marks that no longer exist.
            let alive = Set(groups.flatMap(\.assets).map(\.localIdentifier))
            marked = marked.intersection(alive)
        }
    }

    private func scanIfNeeded() {
        guard !scanner.hasScanned, !scanner.isRestoring, !scanner.isScanning else { return }
        scanner.scan()
    }

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            BackButton(action: onClose)

            Text(mode.title)
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            Spacer()

            if !scanner.isScanning && !groups.isEmpty {
                Text("\(groups.count.formatted()) \(groups.count == 1 ? "group" : "groups")")
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(Theme.dim)
            }
        }
        .padding(.horizontal, Theme.screenMargin)
        .padding(.top, Theme.Space.sm)
        .padding(.bottom, Theme.Space.lg)
    }

    private func groupCard(_ group: DuplicateGroup) -> some View {
        let groupIDs = group.assets.map(\.localIdentifier)
        let tossCount = groupIDs.filter { marked.contains($0) }.count

        return VStack(alignment: .leading, spacing: Theme.Space.md) {
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
                .font(.footnote.weight(.semibold))
                .foregroundColor(tossCount == 0 ? Theme.toss : Theme.cream)
            }
            // Only the header is inset — the photo row runs to the card's
            // edges so scrolling passes under them instead of chopping the
            // last thumbnail in half.
            .padding(.horizontal, Theme.Space.lg)

            groupThumbRow(group)
        }
        .padding(.vertical, Theme.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface)
        )
        // Same surface + hairline as every other card in the app. The
        // feature's color lives where it means something — the keeper's
        // badge and border — not as a glow around the whole card.
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    /// Every photo in the group at the same size, in a normal scrolling
    /// row — the keeper is first and marked with a star badge, but isn't
    /// enlarged or overlapped by the others. A fanned/overlapping layout
    /// was tried here and repeatedly made it impossible to actually see
    /// enough of each photo to judge it, especially on a phone-width
    /// card; scrolling guarantees every photo is fully visible instead
    /// of hidden behind the next one or a "+N" count.
    /// Sized so exactly four tiles fill the card's visible width (leading
    /// inset + 3 gaps, the fourth kissing the card edge). Computed once
    /// from the screen width rather than a fixed constant, so the count
    /// holds on every device width.
    private static let tileSize: CGFloat = {
        let cardWidth = UIScreen.main.bounds.width - Theme.screenMargin * 2
        return (cardWidth - Theme.Space.lg - Theme.Space.md * 3) / 4
    }()

    private func groupThumbRow(_ group: DuplicateGroup) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.md) {
                // group.assets is keeper-first (see makeGroups in
                // DuplicateFinder.swift), so no re-sorting needed here.
                ForEach(group.assets, id: \.localIdentifier) { asset in
                    groupThumb(asset, isKeeper: asset.localIdentifier == group.keeperID)
                        .frame(width: Self.tileSize, height: Self.tileSize)
                }
            }
            // Rest position matches the header's inset; scrolled content
            // runs out under the card edge rather than stopping short.
            .padding(.horizontal, Theme.Space.lg)
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
                // Sized explicitly so the fill crop is exact, and fed a
                // ~3x pixel request — the default 240px grid thumb is a
                // soft upscale at this tile size.
                PhotoThumbnailView(asset: asset,
                                   pixelSize: CGSize(width: Self.tileSize * 3,
                                                     height: Self.tileSize * 3))
                    .frame(width: Self.tileSize, height: Self.tileSize)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
                    .opacity(isMarked ? 0.5 : 1)
                    // Plain tiles get a hairline like every other surface
                    // in the app; only a decision (keeper / marked) earns
                    // a colored 2pt edge. The old white `ink` shadow put a
                    // halo on every tile, which made neighbours smear into
                    // each other and read as overlapping.
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                            .strokeBorder(isMarked ? Theme.toss : (isKeeper ? accent : Theme.hairline),
                                          lineWidth: isMarked || isKeeper ? 2 : 1)
                    )

                // White backing — the SF `.circle.fill` glyphs render
                // their symbol as a cutout, so a dark backing made the
                // star/trash read as black holes on the dark canvas.
                if isMarked {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.toss)
                        .background(Circle().fill(.white))
                        .padding(6)
                } else if isKeeper {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(accent)
                        .background(Circle().fill(.white))
                        .padding(6)
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
