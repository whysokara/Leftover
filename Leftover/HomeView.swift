//
//  HomeView.swift
//  Leftover
//
//  Phase 1 home dashboard: freed-space stat, streak flame, Today's Burst
//  card, "Sort your leftovers" grid, and the recent-photos strip.
//  Dumb view — all data and actions come from ContentView.
//

import SwiftUI
import Photos
import UIKit

struct HomeView: View {
    let freedBytes: Int64
    let streakCount: Int
    let streakPop: Bool

    let burstCount: Int
    let burstIsFallback: Bool
    let burstDone: Bool
    let burstBackdrop: UIImage?

    let screenshotCount: Int
    let videoCount: Int
    let timeCapsuleCount: Int
    let recentAssets: [PHAsset]
    let isLoading: Bool

    let onSettings: () -> Void
    let onStartBurst: () -> Void
    let onScreenshots: () -> Void
    let onTimeCapsule: () -> Void
    let onAlbums: () -> Void
    let onRecent: (Int) -> Void
    let onComingSoon: (String) -> Void

    @State private var flameScale: CGFloat = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar
                Text("Leftover")
                    .font(Theme.display(40))
                    .foregroundColor(Theme.ink)
                burstCard
                cleanupList
                recentStrip
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.stage)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.dim)
            }
            .accessibilityLabel("Settings")

            Spacer()

            if freedBytes > 0 {
                Text(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundColor(Theme.dim)
                    .accessibilityLabel("Freed \(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)) so far")
            }

            if streakCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Theme.cream)
                        .scaleEffect(flameScale)
                    Text("\(streakCount)")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
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

    private var burstCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY’S MEMORY BURST")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(burstDone ? Theme.dim : Theme.cream.opacity(0.85))

            if burstDone {
                Label("Done for today.", systemImage: "checkmark.circle.fill")
                    .font(Theme.title)
                    .foregroundColor(Theme.keep)
                Text("Come back tomorrow.")
                    .font(.subheadline)
                    .foregroundColor(Theme.dim)
            } else if burstCount == 0 {
                Text("Nothing today.")
                    .font(Theme.title)
                    .foregroundColor(Theme.ink)
                Text("No memories this week. Enjoy the quiet.")
                    .font(.subheadline)
                    .foregroundColor(Theme.dim)
            } else {
                Text(burstIsFallback ? "Screenshot sweep" : "This week, years ago")
                    .font(Theme.display(30))
                    .foregroundColor(Theme.ink)
                    .shadow(color: .black.opacity(0.5), radius: 6)
                Text(burstIsFallback
                     ? "No memories this week — \(burstCount) screenshots instead."
                     : "\(burstCount) photo\(burstCount == 1 ? "" : "s") from your past.")
                    .font(.subheadline)
                    .foregroundColor(Theme.ink.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 4)

                Button("Start today’s burst", action: onStartBurst)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.surface)

                // The card is a still from your own past, dimmed to a
                // scrim — the theater screen before the show starts.
                if !burstDone, burstCount > 0, let backdrop = burstBackdrop {
                    Image(uiImage: backdrop)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 14)
                        .overlay(
                            LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0.72)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        )
    }

    // One continuous surface of rows — replaces the old 2×2 tile grid.
    private var cleanupList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clean up")
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            VStack(spacing: 0) {
                SortRow(icon: "camera.viewfinder",
                        title: "Screenshot Sweep",
                        detail: countLabel(screenshotCount, "screenshot"),
                        dimmed: screenshotCount == 0,
                        action: screenshotCount > 0 ? onScreenshots : { onComingSoon("No screenshots to sweep.") })
                rowDivider
                SortRow(icon: "clock.arrow.circlepath",
                        title: "Time Capsule",
                        detail: countLabel(timeCapsuleCount, "photo"),
                        dimmed: timeCapsuleCount == 0,
                        action: timeCapsuleCount > 0 ? onTimeCapsule : { onComingSoon("No old photos this week.") })
                rowDivider
                SortRow(icon: "square.on.square",
                        title: "Duplicates",
                        detail: "Soon",
                        dimmed: true) {
                    onComingSoon("Duplicates are coming soon.")
                }
                rowDivider
                SortRow(icon: "film",
                        title: "Large Videos",
                        detail: "Soon",
                        dimmed: true) {
                    onComingSoon("Video review is coming soon.")
                }
                rowDivider
                SortRow(icon: "rectangle.stack",
                        title: "Albums",
                        detail: "",
                        dimmed: false,
                        action: onAlbums)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.leading, 66)
    }

    private func countLabel(_ count: Int, _ noun: String) -> String {
        if isLoading && count == 0 { return "Counting…" }
        if count == 0 { return "None" }
        return "\(count.formatted()) \(noun)\(count == 1 ? "" : "s")"
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
    let title: String
    let detail: String
    let dimmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(dimmed ? Theme.dim : Theme.cream)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Theme.raised)
                    )

                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(dimmed ? Theme.dim : Theme.ink)

                Spacer(minLength: 8)

                if !detail.isEmpty {
                    Text(detail)
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(Theme.dim)
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
