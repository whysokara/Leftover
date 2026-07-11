//
//  HomeView.swift
//  Leftover
//
//  Home dashboard: freed-space stat, streak flame, the "Clean up"
//  grouped list (Memory Burst + all cleanup engines + Albums), and the
//  recent-photos strip. Dumb view — data and actions come from
//  ContentView.
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
    let burstPreviewAsset: PHAsset?

    let screenshotCount: Int
    let videoCount: Int
    let timeCapsuleCount: Int
    let duplicateDetail: String
    let similarDetail: String
    let blurryDetail: String
    let recentAssets: [PHAsset]
    let isLoading: Bool

    let onSettings: () -> Void
    let onStartBurst: () -> Void
    let onScreenshots: () -> Void
    let onTimeCapsule: () -> Void
    let onDuplicates: () -> Void
    let onSimilar: () -> Void
    let onBlurry: () -> Void
    let onLargeVideos: () -> Void
    let onAlbums: () -> Void
    let onRecent: (Int) -> Void
    let onComingSoon: (String) -> Void

    @State private var flameScale: CGFloat = 1.0
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar.cascadeIn(appeared, slot: 0)
                Text("Leftover")
                    .font(Theme.wordmark(34))
                    .foregroundColor(Theme.ink)
                    .cascadeIn(appeared, slot: 1)
                bentoGrid.cascadeIn(appeared, slot: 2)
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
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.ink)
            }
            .accessibilityLabel("Settings")

            Spacer()

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
                    Image(systemName: "flame.fill")
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
        }
    }

    // A Bento grid: one hero tile (Memory Burst, photo-backed) and
    // uniform small tiles for every other engine — the hero alone
    // carries the size hierarchy, the rest stay equal.
    private var bentoGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                heroBurstTile
                    .gridCellColumns(2)
            }
            GridRow {
                smallTile(icon: "square.on.square", chip: Theme.chipTeal,
                          title: "Duplicates", detail: duplicateDetail,
                          dimmed: duplicateDetail == "None", action: onDuplicates)
                smallTile(icon: "square.stack.3d.down.right.fill", chip: Theme.chipPink,
                          title: "Similar Shots", detail: similarDetail,
                          dimmed: similarDetail == "None", action: onSimilar)
            }
            GridRow {
                smallTile(icon: "camera.viewfinder", chip: Theme.chipBlue,
                          title: "Screenshots", detail: countLabel(screenshotCount),
                          dimmed: screenshotCount == 0,
                          action: screenshotCount > 0 ? onScreenshots : { onComingSoon("No screenshots.") })
                smallTile(icon: "clock.fill", chip: Theme.chipPurple,
                          title: "Time Capsule", detail: countLabel(timeCapsuleCount),
                          dimmed: timeCapsuleCount == 0,
                          action: timeCapsuleCount > 0 ? onTimeCapsule : { onComingSoon("No old photos from this day.") })
            }
            GridRow {
                smallTile(icon: "wand.and.rays", chip: Theme.chipYellow,
                          title: "Blurry", detail: blurryDetail,
                          dimmed: blurryDetail == "None", action: onBlurry)
                smallTile(icon: "film.fill", chip: Theme.chipCoral,
                          title: "Large Videos", detail: countLabel(videoCount),
                          dimmed: videoCount == 0,
                          action: videoCount > 0 ? onLargeVideos : { onComingSoon("No videos in your library.") })
            }
            GridRow {
                smallTile(icon: "folder.fill", chip: Theme.chipNavy,
                          title: "Albums", detail: "", dimmed: false, action: onAlbums)
                    .gridCellColumns(2)
            }
        }
    }

    private var heroBurstTile: some View {
        Button(action: onStartBurst) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(burstDimmed ? Theme.raised : Theme.chipOrange)

                // Always show a photo when one exists — even "done for
                // today"/dimmed still gets a picture, just muted, instead
                // of going blank.
                if let burstPreviewAsset {
                    PhotoThumbnailView(asset: burstPreviewAsset)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .opacity(burstDimmed ? 0.5 : 1)
                        .saturation(burstDimmed ? 0.4 : 1)
                    LinearGradient(colors: [.black.opacity(burstDimmed ? 0.4 : 0.55), .clear],
                                   startPoint: .bottom, endPoint: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Spacer(minLength: 0)
                    Text("Memory Burst")
                        .font(.system(.title3).weight(.bold))
                    Text(burstDetail)
                        .font(.footnote.monospacedDigit())
                        .opacity(0.85)
                }
                .foregroundColor(burstPreviewAsset != nil ? .white : (burstDimmed ? Theme.dim : .white))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)

                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(burstPreviewAsset != nil ? .white : (burstDimmed ? Theme.dim : .white))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(burstDimmed ? 0.12 : 0.22)))
                    .padding(14)
            }
            .frame(height: 156)
            .shadow(color: Theme.ink.opacity(0.1), radius: 16, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memory Burst, \(burstDetail)")
    }

    private func smallTile(icon: String, chip: Color, title: String, detail: String,
                            dimmed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(dimmed ? Theme.dim.opacity(0.4) : chip))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(.footnote).weight(.semibold))
                        .foregroundColor(dimmed ? Theme.dim : Theme.ink)
                        .lineLimit(1)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(Theme.dim)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Theme.ink.opacity(0.05), radius: 8, y: 3)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.isEmpty ? title : "\(title), \(detail)")
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

struct SortRow: View {
    let icon: String
    let chip: Color
    let title: String
    let detail: String
    let dimmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(dimmed ? Theme.dim.opacity(0.45) : chip))

                Text(title)
                    .font(.system(.body).weight(.semibold))
                    .foregroundColor(dimmed ? Theme.dim : Theme.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if !detail.isEmpty {
                    Text(detail)
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(Theme.dim)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Theme.dim.opacity(dimmed ? 0.4 : 1))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.isEmpty ? title : "\(title), \(detail)")
    }
}
