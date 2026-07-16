//
//  HomeView.swift
//  Leftover
//
//  Home dashboard: freed-space stat, streak flame, a Cover Flow
//  carousel of category cards (Memory Burst + every cleanup engine +
//  Albums — the carousel IS the navigation), and the recent-photos
//  strip. Dumb view — data and actions come from ContentView.
//
//  The carousel is a custom ZStack + drag, not a ScrollView: the
//  iOS 17 scroll-transition APIs are unavailable at our iOS 16 target,
//  and with only 7 cards a hand-rolled transform stack is simpler and
//  gives exact control over snapping, tap-to-center, and z-order —
//  the same state+drag+spring pattern as the swipe screen.
//

import SwiftUI
import Photos
import UIKit

struct HomeView: View {
    let freedBytes: Int64
    let streakCount: Int
    let streakPop: Bool

    let burstDetail: String
    let burstDimmed: Bool

    let screenshotCount: Int
    let videoCount: Int
    let duplicateDetail: String
    let similarDetail: String
    let blurryDetail: String
    let recentAssets: [PHAsset]
    let isLoading: Bool

    let onSettings: () -> Void
    let onStartBurst: () -> Void
    let onScreenshots: () -> Void
    let onDuplicates: () -> Void
    let onSimilar: () -> Void
    let onBlurry: () -> Void
    let onLargeVideos: () -> Void
    let onAlbums: () -> Void
    let onRecent: (Int) -> Void
    let onComingSoon: (String) -> Void

    @State private var flameScale: CGFloat = 1.0
    @State private var appeared = false

    /// Which card faces forward, and the live drag offset in card-widths.
    @State private var selectedIndex = 0
    @State private var dragFraction: CGFloat = 0

    private let cardSize: CGFloat = 210
    /// Where the ±1 neighbor's center sits — past the enlarged front
    /// card's edge plus the neighbor's projected half-width with margin
    /// to spare (perspective widens the near edge beyond plain cos θ),
    /// so no two cards ever touch.
    private let sidePush: CGFloat = 216
    /// Interval between cards beyond ±1 — a full tilted card width plus
    /// a gap, keeping every card separate (on a phone that runs them
    /// offscreen, so effectively one clean neighbor shows per side).
    private let spineSpacing: CGFloat = 145
    /// Finger travel that equals one card of movement.
    private let dragUnit: CGFloat = 140
    private let reflectionHeight: CGFloat = 80

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar.cascadeIn(appeared, slot: 0)
                Text("Leftover")
                    .font(Theme.wordmark(34))
                    .foregroundColor(Theme.ink)
                    .cascadeIn(appeared, slot: 1)
                coverFlow.cascadeIn(appeared, slot: 2)
                recentStrip.cascadeIn(appeared, slot: 3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.stage)
        .onAppear { appeared = true }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            if freedBytes > 0 {
                Text(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(Theme.settle, value: freedBytes)
                    .foregroundColor(Theme.dim)
                    .accessibilityLabel("Freed \(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)) so far")
            }

            if streakCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame")
                        .foregroundColor(Theme.cream)
                        .scaleEffect(flameScale)
                    Text("\(streakCount)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundColor(Theme.ink)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(streakCount) day streak")
                .onAppear {
                    guard streakPop else { return }
                    withAnimation(Theme.pop) { flameScale = 1.35 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(Theme.settle) { flameScale = 1.0 }
                    }
                }
            }

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Cover Flow

    private struct CoverCard: Identifiable {
        let id: String
        let icon: String
        let chip: Color
        let title: String
        let detail: String
        let dimmed: Bool
        let action: () -> Void
    }

    // Categories with nothing to review drop out of the carousel —
    // "None" only appears after a real load/scan says so, while the
    // pre-scan "Scan" and loading "…" states stay visible. Albums is
    // navigation and Memory Burst dims when done today; both stay.
    private var cards: [CoverCard] {
        let all = [
            CoverCard(id: "burst", icon: "sparkles", chip: Theme.chipOrange,
                      title: "Memory Burst", detail: burstDetail,
                      dimmed: burstDimmed, action: onStartBurst),
            CoverCard(id: "duplicates", icon: "square.on.square", chip: Theme.chipTeal,
                      title: "Duplicates", detail: duplicateDetail,
                      dimmed: false, action: onDuplicates),
            CoverCard(id: "similar", icon: "square.stack.3d.down.right", chip: Theme.chipPink,
                      title: "Similar Shots", detail: similarDetail,
                      dimmed: false, action: onSimilar),
            CoverCard(id: "screenshots", icon: "camera.viewfinder", chip: Theme.chipBlue,
                      title: "Screenshots", detail: countLabel(screenshotCount),
                      dimmed: false,
                      action: screenshotCount > 0 ? onScreenshots : { onComingSoon("No screenshots.") }),
            CoverCard(id: "blurry", icon: "wand.and.rays", chip: Theme.chipYellow,
                      title: "Blurry", detail: blurryDetail,
                      dimmed: false, action: onBlurry),
            CoverCard(id: "videos", icon: "film", chip: Theme.chipCoral,
                      title: "Large Videos", detail: countLabel(videoCount),
                      dimmed: false,
                      action: videoCount > 0 ? onLargeVideos : { onComingSoon("No videos in your library.") }),
            CoverCard(id: "albums", icon: "folder", chip: Theme.chipNavy,
                      title: "Albums", detail: "",
                      dimmed: false, action: onAlbums),
        ]
        return all.filter { $0.detail != "None" }
    }

    private var coverFlow: some View {
        // No name readout below — the front card's own label carries it.
        // The extra vertical padding seats the carousel closer to the
        // middle of the gap between the wordmark and the Recent strip.
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                coverCardView(card, at: index)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardSize + reflectionHeight + 4)
        .contentShape(Rectangle())
        .gesture(carouselDrag)
        .padding(.top, 34)
        .padding(.bottom, 10)
        // The card set can shrink when a scan/load reports "None" —
        // snap back to the front so selectedIndex always names a real
        // card (the tap handler and wrap math both depend on it).
        .onChange(of: cards.count) { _ in
            selectedIndex = 0
            dragFraction = 0
        }
    }

    /// Gentle fade across the visible spine ridge, then a fast fade to
    /// zero just before the wrap-around distance (cards.count / 2), so
    /// a card teleporting from one side to the other is never visible.
    private func cardOpacity(_ absD: CGFloat) -> Double {
        let base = 1 - Double(min(absD, 3)) * 0.13
        guard absD > 3 else { return base }
        return max(0, base - Double(absD - 3) * 1.8)
    }

    private func wrappedIndex(_ i: Int) -> Int {
        ((i % cards.count) + cards.count) % cards.count
    }

    /// Classic Cover Flow placement: the ±1 neighbors clear the front
    /// card, and everything further packs into an even spine stack —
    /// piecewise but continuous at |d| == 1, so dragging stays smooth.
    private func xOffset(for d: CGFloat) -> CGFloat {
        let absD = abs(d)
        let sign: CGFloat = d < 0 ? -1 : 1
        if absD <= 1 { return d * sidePush }
        return sign * (sidePush + (absD - 1) * spineSpacing)
    }

    private func coverCardView(_ card: CoverCard, at index: Int) -> some View {
        // Signed distance from the front position in card slots, wrapped
        // to the nearest equivalent so the carousel is endless — the last
        // card sits one slot left of the first, and spinning past either
        // end just keeps going. Cards fade out before |d| reaches the
        // wrap point (count/2), so the side-swap never shows.
        let count = CGFloat(cards.count)
        let raw = CGFloat(index - selectedIndex) - dragFraction
        let d = raw - (raw / count).rounded() * count
        let clamped = max(-1, min(1, d))
        let absD = abs(d)
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        // Labels only belong on the front card — side cards show a thin
        // sliver, so their labels would pile into unreadable overlap.
        let labelOpacity = Double(1 - min(absD / 0.5, 1))

        return VStack(spacing: 4) {
            cardFace(card, labelOpacity: labelOpacity)

            // Glossy-floor reflection: the same face flipped, cropped to
            // its top edge (the card's bottom), fading out fast.
            cardFace(card, labelOpacity: labelOpacity)
                .scaleEffect(x: 1, y: -1)
                .frame(width: cardSize, height: cardSize)
                .frame(height: reflectionHeight, alignment: .top)
                .clipped()
                .mask(
                    LinearGradient(colors: [.white.opacity(0.35), .clear],
                                   startPoint: .top, endPoint: .bottom)
                )
                .accessibilityHidden(true)
        }
        // The spotlight card runs slightly over natural size; sides
        // drop to 0.88 so the front one clearly leads.
        .scaleEffect(1.06 - min(absD, 1) * 0.18)
        // Gentler tilt than classic Cover Flow — the flatter, more
        // tile-like side cards keep their projected width narrow, which
        // is what guarantees the clean gaps between cards.
        .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(-clamped) * 28),
                          axis: (x: 0, y: 1, z: 0),
                          perspective: 0.55)
        .offset(x: xOffset(for: d))
        .zIndex(-Double(absD))
        .opacity(cardOpacity(absD))
        .onTapGesture {
            if index == selectedIndex {
                card.action()
            } else {
                Haptics.impact(.light)
                withAnimation(Theme.settle) { selectedIndex = index }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.detail.isEmpty ? card.title : "\(card.title), \(card.detail)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(index == selectedIndex ? "Opens \(card.title)" : "Brings \(card.title) to the front")
    }

    private func cardFace(_ card: CoverCard, labelOpacity: Double = 1) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Solid chip color — white glyph and text carry the content,
            // like the app's old filled-icon language. Dimmed cards go
            // solid raised-gray instead.
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(card.dimmed ? Theme.raised : card.chip)
            Image(systemName: card.icon)
                .font(.system(size: 54, weight: .medium))
                .foregroundColor(card.dimmed ? Theme.dim : .white.opacity(0.95))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 1) {
                Text(card.title)
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundColor(card.dimmed ? Theme.dim : .white)
                    .lineLimit(1)
                if !card.detail.isEmpty {
                    Text(card.detail)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(card.dimmed ? Theme.dim : .white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .opacity(labelOpacity)
        }
        .frame(width: cardSize, height: cardSize)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var carouselDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Endless — no rubber-banding, there are no ends.
                dragFraction = -value.translation.width / dragUnit
            }
            .onEnded { value in
                // Snap by where the flick was headed, not where it
                // stopped — capped so one flick can't spin the wheel
                // several full laps.
                let projected = max(-4, min(4, -value.predictedEndTranslation.width / dragUnit))
                let steps = Int((CGFloat(selectedIndex) + projected).rounded()) - selectedIndex
                if steps != 0 { Haptics.impact(.light) }
                withAnimation(Theme.settle) {
                    selectedIndex = wrappedIndex(selectedIndex + steps)
                    dragFraction = 0
                }
            }
    }

    // Bare values on the trailing edge, like the system Settings app.
    private func countLabel(_ count: Int) -> String {
        if isLoading && count == 0 { return "…" }
        if count == 0 { return "None" }
        return count.formatted()
    }

    private var recentStrip: some View {
        Group {
            if !recentAssets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent")
                        .font(Theme.title)
                        .foregroundColor(Theme.ink)

                    ScrollView(.horizontal, showsIndicators: false) {
                        // Lazy — this strip can hold the whole library now,
                        // not just the last few, so only visible thumbnails
                        // should ever materialize.
                        LazyHStack(spacing: 8) {
                            ForEach(Array(recentAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                PhotoThumbnailView(asset: asset)
                                    .frame(width: 96, height: 128)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
                                    .onTapGesture { onRecent(index) }
                                    .accessibilityElement()
                                    .accessibilityLabel("Recent photo \(index + 1)")
                                    .accessibilityAddTraits(.isButton)
                            }
                        }
                    }
                }
            }
        }
    }
}
