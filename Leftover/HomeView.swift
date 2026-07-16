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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar.cascadeIn(appeared, slot: 0)
                Text("Leftover")
                    .font(Theme.wordmark(34))
                    .foregroundColor(Theme.ink)
                    .cascadeIn(appeared, slot: 1)
                cleanupList.cascadeIn(appeared, slot: 2)
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

    private struct CleanupRow: Identifiable {
        let id: String
        let icon: String
        let chip: Color
        let title: String
        let detail: String
        let dimmed: Bool
        let action: () -> Void
    }

    // Memory Burst and Albums always show — one's the daily habit
    // anchor, the other is plain navigation. Everything else only shows
    // up when there's something to review (or its status is still
    // unknown), so a clean library shows a short list, not a busy one.
    private var middleRows: [CleanupRow] {
        var rows: [CleanupRow] = []
        if duplicateDetail != "None" {
            rows.append(CleanupRow(id: "duplicates", icon: "square.on.square", chip: Theme.chipTeal,
                                    title: "Duplicates", detail: duplicateDetail, dimmed: false, action: onDuplicates))
        }
        if similarDetail != "None" {
            rows.append(CleanupRow(id: "similar", icon: "square.stack.3d.down.right", chip: Theme.chipPink,
                                    title: "Similar Shots", detail: similarDetail, dimmed: false, action: onSimilar))
        }
        if isLoading || screenshotCount > 0 {
            rows.append(CleanupRow(id: "screenshots", icon: "camera.viewfinder", chip: Theme.chipBlue,
                                    title: "Screenshots", detail: countLabel(screenshotCount), dimmed: false,
                                    action: screenshotCount > 0 ? onScreenshots : { onComingSoon("No screenshots.") }))
        }
        if blurryDetail != "None" {
            rows.append(CleanupRow(id: "blurry", icon: "wand.and.rays", chip: Theme.chipYellow,
                                    title: "Blurry", detail: blurryDetail, dimmed: false, action: onBlurry))
        }
        if isLoading || videoCount > 0 {
            rows.append(CleanupRow(id: "videos", icon: "film", chip: Theme.chipCoral,
                                    title: "Large Videos", detail: countLabel(videoCount), dimmed: false,
                                    action: videoCount > 0 ? onLargeVideos : { onComingSoon("No videos in your library.") }))
        }
        return rows
    }

    // A flat list of equal-weight rows — Memory Burst first, then
    // whichever engines have something to do, then Albums.
    private var cleanupList: some View {
        VStack(spacing: 10) {
            SortRow(icon: "sparkles", chip: Theme.chipOrange,
                    title: "Memory Burst", detail: burstDetail,
                    dimmed: burstDimmed, action: onStartBurst)

            if middleRows.isEmpty {
                allCaughtUpBanner
            } else {
                ForEach(middleRows) { row in
                    SortRow(icon: row.icon, chip: row.chip, title: row.title,
                            detail: row.detail, dimmed: row.dimmed, action: row.action)
                }
            }

            SortRow(icon: "folder", chip: Theme.chipNavy,
                    title: "Albums", detail: "", dimmed: false, action: onAlbums)
        }
    }

    private var allCaughtUpBanner: some View {
        HStack(spacing: 14) {
            LeftoverBuddy(color: Theme.chipTeal, expression: .relieved, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("All Caught Up")
                    .font(.system(.footnote).weight(.semibold))
                    .foregroundColor(Theme.ink)
                Text("Nothing to clean up right now.")
                    .font(.caption2)
                    .foregroundColor(Theme.dim)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
        )
        .accessibilityElement(children: .combine)
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
                IconBadge(icon: icon, chip: chip, size: 40, dimmed: dimmed)

                Text(title)
                    .font(.system(.body).weight(.medium))
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
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.dim.opacity(dimmed ? 0.4 : 1))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.isEmpty ? title : "\(title), \(detail)")
    }
}
