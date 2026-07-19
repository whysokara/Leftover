//
//  HomeView.swift
//  Leftover
//
//  Home dashboard: freed-space stat, a Cover Flow
//  carousel of category cards (Memory Burst + every cleanup engine +
//  Albums — the carousel IS the navigation), and a vertical grid of
//  the whole library, newest first. Dumb view — data and actions come
//  from ContentView.
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

/// Up to four recent assets per category, for the blurred collage card
/// faces. Empty arrays fall back to the solid icon face (e.g. the
/// pre-scan "Scan" state, where no matches exist yet).
struct CardPreviews {
    var burst: [PHAsset] = []
    var duplicates: [PHAsset] = []
    var similar: [PHAsset] = []
    var screenshots: [PHAsset] = []
    var blurry: [PHAsset] = []
    var videos: [PHAsset] = []
    var albums: [PHAsset] = []
}

struct HomeView: View {
    let freedBytes: Int64

    let burstDetail: String
    let burstDimmed: Bool
    let previews: CardPreviews

    let screenshotCount: Int
    let videoCount: Int
    let duplicateBytes: Int64
    let similarBytes: Int64
    let screenshotBytes: Int64
    let blurryBytes: Int64
    let videoBytes: Int64
    let duplicateDetail: String
    let similarDetail: String
    let blurryDetail: String
    let recentAssets: [PHAsset]
    let isLoading: Bool
    let isLimitedAccess: Bool
    let healthScore: HealthScore

    let onHealth: () -> Void
    let onTrophies: () -> Void
    let onSettings: () -> Void
    let onManageLimited: () -> Void
    let onStartBurst: () -> Void
    let onScreenshots: () -> Void
    let onDuplicates: () -> Void
    let onSimilar: () -> Void
    let onBlurry: () -> Void
    let onLargeVideos: () -> Void
    let onAlbums: () -> Void
    let onRecent: (Int) -> Void
    let onComingSoon: (String) -> Void

    @State private var appeared = false
    @State private var healthPulse = false
    @State private var lastHealthScore = 100

    /// Which card faces forward, and the live drag offset in card-widths.
    @State private var selectedIndex = 0
    @State private var dragFraction: CGFloat = 0
    /// Drives the front card's idle watermark breathing.
    @State private var glyphBreath = false

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
                header.cascadeIn(appeared, slot: 0)
                if isLimitedAccess {
                    limitedAccessBanner.cascadeIn(appeared, slot: 1)
                }
                coverFlow.cascadeIn(appeared, slot: 2)
                recentStrip.cascadeIn(appeared, slot: 3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.stage)
        .onAppear {
            appeared = true
            glyphBreath = true
        }
    }

    // Wordmark leads the page; the stats sit on the trailing side,
    // tucked in next to the settings gear.
    private var header: some View {
        HStack(spacing: Theme.Space.sm) {
            // A step below largeTitle so the wordmark and the trailing
            // stats read as one balanced row instead of a giant next to
            // a whisper.
            Text("Leftover")
                .font(Theme.wordmark(28))
                .foregroundColor(Theme.ink)
                // Never wrap — compress slightly instead when Dynamic
                // Type or the stat chips squeeze the row.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                // Same explicit height as the trailing chips so HStack's
                // center alignment lines them up on a shared middle
                // instead of each text's own font-box center.
                .frame(height: 44)

            Spacer(minLength: 8)

            HStack(spacing: Theme.Space.sm) {
                if freedBytes > 0 {
                    statsRow
                }

                trophyChip

                healthChip
            }
            // Small footnote text's own font-box sits higher than its
            // visual glyph center relative to the wordmark's serif title
            // metrics — nudge down so the two read as one baseline.
            .padding(.top, 5)

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface))
                    // Same 36pt visual, HIG-minimum 44pt hit area.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Settings")
        }
    }

    private let healthBarWidth: CGFloat = 22

    /// The headline mechanic: a tiny score bar + number. Tapping opens
    /// the breakdown sheet; the number pops when the score improves.
    private var healthChip: some View {
        Button(action: onHealth) {
            HStack(spacing: 5) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.hairline)
                        .frame(width: healthBarWidth, height: 4)
                    Capsule()
                        .fill(healthScore.color)
                        .frame(width: healthBarWidth * CGFloat(healthScore.score) / 100, height: 4)
                }
                .opacity(healthScore.isProvisional ? 0.6 : 1)

                Text("\(healthScore.score)")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .contentTransition(.numericText())
                    .foregroundColor(Theme.ink)
                    .opacity(healthScore.isProvisional ? 0.6 : 1)
            }
            .scaleEffect(healthPulse ? 1.25 : 1)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(Theme.settle, value: healthScore.score)
        .onChange(of: healthScore.score) { newScore in
            if newScore > lastHealthScore {
                withAnimation(Theme.pop) { healthPulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(Theme.settle) { healthPulse = false }
                }
            }
            lastHealthScore = newScore
        }
        .accessibilityLabel("Library health \(healthScore.score) out of 100\(healthScore.isProvisional ? ", partial score" : "")")
        .accessibilityHint("Shows what's affecting your score")
    }

    /// Bare tap target to the trophy shelf, in the header slot the
    /// streak flame used to occupy — icon only, no count.
    private var trophyChip: some View {
        Button(action: onTrophies) {
            Image(systemName: "trophy.fill")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Theme.chipYellow)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Trophies")
        .accessibilityHint("Opens your trophy shelf")
    }

    // Bare stats beside the gear — no chrome, sized to sit comfortably
    // against the wordmark.
    private var statsRow: some View {
        Text(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))
            .font(.footnote.weight(.semibold).monospacedDigit())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .contentTransition(.numericText())
            .animation(Theme.settle, value: freedBytes)
            .foregroundColor(Theme.dim)
            .frame(height: 44)
            .accessibilityLabel("Freed \(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)) so far")
    }

    // MARK: - Cover Flow

    // Without this, a limited-access user just sees mysteriously small
    // counts with no explanation — the album picker has the same banner.
    private var limitedAccessBanner: some View {
        HStack(spacing: 8) {
            Text("Showing only the photos you've shared.")
                .font(.footnote)
                .foregroundColor(Theme.dim)
            Spacer(minLength: 8)
            Button("Manage") { onManageLimited() }
                .font(.footnote.weight(.semibold))
                .foregroundColor(Theme.cream)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surface)
        )
    }

    private struct CoverCard: Identifiable {
        let id: String
        let icon: String
        let chip: Color
        let title: String
        let detail: String
        let sizeLabel: String
        let dimmed: Bool
        let previewAssets: [PHAsset]
        let action: () -> Void
    }

    // Categories with nothing to review drop out of the carousel —
    // "None" only appears after a real load/scan says so, while the
    // pre-scan "Scan" and loading "…" states stay visible. Albums is
    // navigation and Memory Burst dims when done today; both stay.
    private var cards: [CoverCard] {
        let all = [
            CoverCard(id: "burst", icon: "sparkles", chip: Theme.chipOrange,
                      title: "Memory Burst", detail: burstDetail, sizeLabel: "",
                      dimmed: burstDimmed, previewAssets: previews.burst, action: onStartBurst),
            CoverCard(id: "duplicates", icon: "square.on.square", chip: Theme.chipTeal,
                      title: "Duplicates", detail: duplicateDetail, sizeLabel: sizeLabel(duplicateBytes),
                      dimmed: false, previewAssets: previews.duplicates, action: onDuplicates),
            CoverCard(id: "similar", icon: "square.stack.3d.down.right", chip: Theme.chipPink,
                      title: "Similar Shots", detail: similarDetail, sizeLabel: sizeLabel(similarBytes),
                      dimmed: false, previewAssets: previews.similar, action: onSimilar),
            CoverCard(id: "screenshots", icon: "camera.viewfinder", chip: Theme.chipBlue,
                      title: "Screenshots", detail: countLabel(screenshotCount), sizeLabel: sizeLabel(screenshotBytes),
                      dimmed: false, previewAssets: previews.screenshots,
                      action: screenshotCount > 0 ? onScreenshots : { onComingSoon("No screenshots.") }),
            CoverCard(id: "blurry", icon: "wand.and.rays", chip: Theme.chipYellow,
                      title: "Blurry", detail: blurryDetail, sizeLabel: sizeLabel(blurryBytes),
                      dimmed: false, previewAssets: previews.blurry, action: onBlurry),
            CoverCard(id: "videos", icon: "film", chip: Theme.chipCoral,
                      title: "Large Videos", detail: countLabel(videoCount), sizeLabel: sizeLabel(videoBytes),
                      dimmed: false, previewAssets: previews.videos,
                      action: videoCount > 0 ? onLargeVideos : { onComingSoon("No videos in your library.") }),
            CoverCard(id: "albums", icon: "folder", chip: Theme.chipNavy,
                      title: "Albums", detail: "", sizeLabel: "",
                      dimmed: false, previewAssets: previews.albums, action: onAlbums),
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
        // Seats the carousel near the vertical middle and leaves only
        // about a row and a half of the Recent grid above the fold. The
        // top gap is smaller than the bottom because the floor reflection
        // already weights the carousel visually downward — an even split
        // read as a dead band under the header.
        .padding(.top, 48)
        .padding(.bottom, 56)
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
        // Content parallax: the watermark drifts against the drag so the
        // card reads as a window; the front card's watermark breathes.
        let parallax = reduceMotion ? 0 : clamped
        let breathing = absD < 0.5 && !reduceMotion

        return VStack(spacing: 4) {
            cardFace(card, labelOpacity: labelOpacity, parallax: parallax, breathing: breathing)

            // Glossy-floor reflection: the same face flipped, cropped to
            // its top edge (the card's bottom), fading out fast.
            cardFace(card, labelOpacity: labelOpacity, parallax: parallax)
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
        .accessibilityLabel({
            var label = card.detail.isEmpty ? card.title : "\(card.title), \(card.detail)"
            if !card.sizeLabel.isEmpty { label += ", frees \(card.sizeLabel)" }
            return label
        }())
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(index == selectedIndex ? "Opens \(card.title)" : "Brings \(card.title) to the front")
    }

    private func cardFace(_ card: CoverCard, labelOpacity: Double = 1,
                          parallax: CGFloat = 0, breathing: Bool = false) -> some View {
        // Photo-backed: a dimmed, frosted collage of the category's own
        // content — context at a glance. No content yet (pre-scan) →
        // solid chip face.
        let photoBacked = !card.previewAssets.isEmpty

        return ZStack(alignment: .bottomLeading) {
            Group {
                if photoBacked {
                    // Photos stay recognizable: a light soft-focus blur
                    // and a thin unifying tint, with the real darkness
                    // concentrated in a bottom gradient under the label —
                    // the full-card frost hid the content entirely.
                    previewCollage(card.previewAssets)
                        .blur(radius: 2.5, opaque: true)
                        .saturation(card.dimmed ? 0.4 : 1)
                        .overlay(Color.black.opacity(card.dimmed ? 0.45 : 0.18))
                        .overlay(
                            LinearGradient(colors: [.black.opacity(0.75), .clear],
                                           startPoint: .bottom,
                                           endPoint: UnitPoint(x: 0.5, y: 0.45))
                        )
                } else {
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(card.dimmed ? Theme.raised : card.chip)
                    if !card.dimmed {
                        LinearGradient(colors: [.white.opacity(0.30), .clear, .black.opacity(0.22)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(card.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(card.dimmed ? Theme.dim : (photoBacked ? .white : Theme.onChip))
                    .lineLimit(1)
                if !card.detail.isEmpty {
                    Text(card.detail)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(card.dimmed
                                         ? Theme.dim
                                         : (photoBacked ? .white.opacity(0.85) : Theme.onChip.opacity(0.8)))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .opacity(labelOpacity)
        }
        .frame(width: cardSize, height: cardSize)
        // Watermark: one huge copy of the glyph bleeding off the
        // top-right corner — soft white ghost over collages, dark ink
        // over solid chips. It parallaxes gently against the drag and
        // breathes on the front card. As an overlay it can never
        // disturb the card's own layout.
        .overlay(alignment: .topTrailing) {
            Image(systemName: card.icon)
                .font(.system(size: 190, weight: .bold))
                .foregroundColor(photoBacked
                                 ? .white.opacity(card.dimmed ? 0.10 : 0.22)
                                 : Theme.onChip.opacity(card.dimmed ? 0.06 : 0.12))
                .rotationEffect(.degrees(-8))
                .scaleEffect(breathing && glyphBreath ? 1.05 : 1, anchor: .center)
                .animation(breathing
                           ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                           : .default,
                           value: glyphBreath)
                .offset(x: cardSize * 0.36 - parallax * 16, y: -cardSize * 0.26)
        }
        .overlay(alignment: .bottomTrailing) {
            if !card.sizeLabel.isEmpty {
                Text(card.sizeLabel)
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundColor(card.dimmed
                                     ? Theme.dim
                                     : (photoBacked ? .white.opacity(0.85) : Theme.onChip.opacity(0.8)))
                    .padding(14)
                    .opacity(labelOpacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            // A lit top-leading edge instead of a flat hairline.
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(card.dimmed ? 0.10 : 0.38),
                                            .white.opacity(0.03)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1)
        )
    }

    /// 2×2 collage for four-plus assets; fewer fall back to one
    /// full-bleed asset (PRD fallback state).
    @ViewBuilder
    private func previewCollage(_ assets: [PHAsset]) -> some View {
        if assets.count >= 4 {
            let cell = (cardSize - 2) / 2
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    collageCell(assets[0], cell)
                    collageCell(assets[1], cell)
                }
                HStack(spacing: 2) {
                    collageCell(assets[2], cell)
                    collageCell(assets[3], cell)
                }
            }
        } else {
            PhotoThumbnailView(asset: assets[0])
                .frame(width: cardSize, height: cardSize)
                .clipped()
        }
    }

    private func collageCell(_ asset: PHAsset, _ size: CGFloat) -> some View {
        PhotoThumbnailView(asset: asset)
            .frame(width: size, height: size)
            .clipped()
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

    /// The clearing scope for a card's bottom-right corner — just the
    /// size, once a real one is known. Empty hides the label entirely.
    private func sizeLabel(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var recentStrip: some View {
        Group {
            if !recentAssets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent")
                        .font(Theme.title)
                        .foregroundColor(Theme.ink)

                    // The whole library, newest first, as a vertical grid
                    // that scrolls with the page — every photo reachable,
                    // not just the first strip-full. LazyVGrid only
                    // materializes visible cells, and the shared caching
                    // manager keeps scroll decoding cheap.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3),
                              spacing: 4) {
                        ForEach(Array(recentAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(PhotoThumbnailView(asset: asset))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
