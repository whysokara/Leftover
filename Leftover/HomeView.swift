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

    let burstPreview: PHAsset?
    let duplicatePreview: PHAsset?
    let similarPreview: PHAsset?
    let screenshotPreview: PHAsset?
    let blurryPreview: PHAsset?
    let videoPreview: PHAsset?
    let albumPreview: PHAsset?

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
    /// Where the ±1 neighbor's center sits — far enough that a wide,
    /// even slice of it shows beside the front card.
    private let sidePush: CGFloat = 155
    /// Cards beyond ±1 stack like spines at this fixed interval — an
    /// even ridge of edges, not a messy cascade of overlapping faces.
    private let spineSpacing: CGFloat = 34
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
        let previewAsset: PHAsset?
        let action: () -> Void
    }

    // Every category is always present — empty ones just dim, so the
    // carousel's length and order never change under the user's thumb.
    private var cards: [CoverCard] {
        [
            CoverCard(id: "burst", icon: "sparkles", chip: Theme.chipOrange,
                      title: "Memory Burst", detail: burstDetail,
                      dimmed: burstDimmed, previewAsset: burstPreview, action: onStartBurst),
            CoverCard(id: "duplicates", icon: "square.on.square", chip: Theme.chipTeal,
                      title: "Duplicates", detail: duplicateDetail,
                      dimmed: duplicateDetail == "None", previewAsset: duplicatePreview, action: onDuplicates),
            CoverCard(id: "similar", icon: "square.stack.3d.down.right", chip: Theme.chipPink,
                      title: "Similar Shots", detail: similarDetail,
                      dimmed: similarDetail == "None", previewAsset: similarPreview, action: onSimilar),
            CoverCard(id: "screenshots", icon: "camera.viewfinder", chip: Theme.chipBlue,
                      title: "Screenshots", detail: countLabel(screenshotCount),
                      dimmed: screenshotCount == 0 && !isLoading, previewAsset: screenshotPreview,
                      action: screenshotCount > 0 ? onScreenshots : { onComingSoon("No screenshots.") }),
            CoverCard(id: "blurry", icon: "wand.and.rays", chip: Theme.chipYellow,
                      title: "Blurry", detail: blurryDetail,
                      dimmed: blurryDetail == "None", previewAsset: blurryPreview, action: onBlurry),
            CoverCard(id: "videos", icon: "film", chip: Theme.chipCoral,
                      title: "Large Videos", detail: countLabel(videoCount),
                      dimmed: videoCount == 0 && !isLoading, previewAsset: videoPreview,
                      action: videoCount > 0 ? onLargeVideos : { onComingSoon("No videos in your library.") }),
            CoverCard(id: "albums", icon: "folder", chip: Theme.chipNavy,
                      title: "Albums", detail: "",
                      dimmed: false, previewAsset: albumPreview, action: onAlbums),
        ]
    }

    private var coverFlow: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    coverCardView(card, at: index)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardSize + reflectionHeight + 4)
            .contentShape(Rectangle())
            .gesture(carouselDrag)

            // The centered card's name under the flow, like the song
            // title readout in the old Music app.
            VStack(spacing: 2) {
                Text(cards[selectedIndex].title)
                    .font(.system(.headline).weight(.semibold))
                    .foregroundColor(Theme.ink)
                    .contentTransition(.opacity)
                Text(cards[selectedIndex].detail.isEmpty ? " " : cards[selectedIndex].detail)
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(Theme.dim)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)
            .animation(Theme.settle, value: selectedIndex)
            .accessibilityHidden(true) // the cards themselves carry the labels
        }
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
        // Signed distance from the front position, in card slots.
        let d = CGFloat(index - selectedIndex) - dragFraction
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
        .scaleEffect(1 - min(absD, 1) * 0.12)
        .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(-clamped) * 42),
                          axis: (x: 0, y: 1, z: 0),
                          perspective: 0.55)
        .offset(x: xOffset(for: d))
        .zIndex(-Double(absD))
        .opacity(1 - Double(min(absD, 4)) * 0.08)
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
            if let asset = card.previewAsset {
                PhotoThumbnailView(asset: asset)
                    .frame(width: cardSize, height: cardSize)
                    .clipped()
                    .saturation(card.dimmed ? 0.3 : 1)
                    .opacity(card.dimmed ? 0.55 : 1)
                // Scrim so the label reads over any photo.
                LinearGradient(colors: [.black.opacity(0.65), .clear],
                               startPoint: .bottom, endPoint: .center)
            } else {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(card.chip.opacity(card.dimmed ? 0.10 : 0.2))
                Image(systemName: card.icon)
                    .font(.system(size: 54, weight: .medium))
                    .foregroundColor(card.dimmed ? Theme.dim : card.chip)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 8) {
                IconBadge(icon: card.icon, chip: card.chip, size: 30, dimmed: card.dimmed)
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.title)
                        .font(.system(.subheadline).weight(.semibold))
                        .foregroundColor(card.dimmed ? Theme.dim : .white)
                        .lineLimit(1)
                    if !card.detail.isEmpty {
                        Text(card.detail)
                            .font(.caption.monospacedDigit())
                            .foregroundColor(card.dimmed ? Theme.dim : .white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
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
                let raw = -value.translation.width / dragUnit
                let target = CGFloat(selectedIndex) + raw
                // Rubber-band past the ends instead of scrolling into nothing.
                if target < 0 {
                    dragFraction = raw - target * 2 / 3
                } else if target > CGFloat(cards.count - 1) {
                    dragFraction = raw - (target - CGFloat(cards.count - 1)) * 2 / 3
                } else {
                    dragFraction = raw
                }
            }
            .onEnded { value in
                // Snap by where the flick was headed, not where it stopped.
                let projected = -value.predictedEndTranslation.width / dragUnit
                let target = (CGFloat(selectedIndex) + projected).rounded()
                let landing = Int(max(0, min(CGFloat(cards.count - 1), target)))
                if landing != selectedIndex { Haptics.impact(.light) }
                withAnimation(Theme.settle) {
                    selectedIndex = landing
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
