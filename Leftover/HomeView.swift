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
                cascade(topBar, slot: 0)
                cascade(
                    Text("Leftover")
                        .font(Theme.wordmark(34))
                        .foregroundColor(Theme.ink),
                    slot: 1
                )
                cascade(cleanupList, slot: 2)
                cascade(recentStrip, slot: 3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.stage)
        .onAppear { appeared = true }
    }

    /// Sections fade-slide in with a small stagger.
    private func cascade<V: View>(_ view: V, slot: Double) -> some View {
        view
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : (UIAccessibility.isReduceMotionEnabled ? 0 : 14))
            .animation(Theme.settle.delay(slot * 0.05), value: appeared)
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

    // One continuous surface of rows — replaces the old 2×2 tile grid.
    private var cleanupList: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                SortRow(icon: "sparkles", chip: Theme.chipOrange,
                        title: "Memory Burst",
                        detail: burstDetail,
                        dimmed: burstDimmed,
                        action: onStartBurst)
                rowDivider
                SortRow(icon: "camera.viewfinder", chip: Theme.chipBlue,
                        title: "Screenshots",
                        detail: countLabel(screenshotCount),
                        dimmed: screenshotCount == 0,
                        action: screenshotCount > 0 ? onScreenshots : { onComingSoon("No screenshots.") })
                rowDivider
                SortRow(icon: "clock.fill", chip: Theme.chipPurple,
                        title: "Time Capsule",
                        detail: countLabel(timeCapsuleCount),
                        dimmed: timeCapsuleCount == 0,
                        action: timeCapsuleCount > 0 ? onTimeCapsule : { onComingSoon("No old photos this week.") })
                rowDivider
                SortRow(icon: "square.stack.3d.down.right.fill", chip: Theme.chipPink,
                        title: "Similar Shots",
                        detail: similarDetail,
                        dimmed: similarDetail == "None",
                        action: onSimilar)
                rowDivider
                SortRow(icon: "square.on.square", chip: Theme.chipTeal,
                        title: "Duplicates",
                        detail: duplicateDetail,
                        dimmed: duplicateDetail == "None",
                        action: onDuplicates)
                rowDivider
                SortRow(icon: "wand.and.rays", chip: Theme.chipYellow,
                        title: "Blurry",
                        detail: blurryDetail,
                        dimmed: blurryDetail == "None",
                        action: onBlurry)
                rowDivider
                SortRow(icon: "film.fill", chip: Theme.chipCoral,
                        title: "Large Videos",
                        detail: countLabel(videoCount),
                        dimmed: videoCount == 0,
                        action: videoCount > 0 ? onLargeVideos : { onComingSoon("No videos in your library.") })
                rowDivider
                SortRow(icon: "folder.fill", chip: Theme.chipNavy,
                        title: "Albums",
                        detail: "",
                        dimmed: false,
                        action: onAlbums)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Theme.ink.opacity(0.08), radius: 16, y: 6)
            )
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.leading, 68)
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
                        HStack(spacing: 8) {
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
