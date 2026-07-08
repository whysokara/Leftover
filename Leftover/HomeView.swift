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

struct HomeView: View {
    let freedBytes: Int64
    let streakCount: Int
    let streakPop: Bool

    let burstCount: Int
    let burstIsFallback: Bool
    let burstDone: Bool

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
                sortGrid
                browseAlbumsRow
                recentStrip
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.paper)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.pencil)
            }
            .accessibilityLabel("Settings")

            Spacer()

            if freedBytes > 0 {
                Text(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundColor(Theme.pencil)
                    .accessibilityLabel("Freed \(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)) so far")
            }

            if streakCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Theme.safelight)
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
                .foregroundColor(burstDone ? Theme.pencil : Theme.amberInk.opacity(0.7))

            if burstDone {
                Label("Done for today", systemImage: "checkmark.circle.fill")
                    .font(Theme.title)
                    .foregroundColor(Theme.keep)
                Text("You’ve kept what matters. Come back tomorrow.")
                    .font(.subheadline)
                    .foregroundColor(Theme.pencil)
            } else if burstCount == 0 {
                Text("Nothing to sort today")
                    .font(Theme.title)
                    .foregroundColor(Theme.amberInk)
                Text("No old memories or screenshots this week — enjoy the quiet.")
                    .font(.subheadline)
                    .foregroundColor(Theme.amberInk.opacity(0.75))
            } else {
                Text(burstIsFallback ? "Screenshot sweep" : "This week, years ago")
                    .font(Theme.display(30))
                    .foregroundColor(Theme.amberInk)
                Text(burstIsFallback
                     ? "No memories this week — sweep \(burstCount) screenshots instead."
                     : "\(burstCount) photo\(burstCount == 1 ? "" : "s") from your past.")
                    .font(.subheadline)
                    .foregroundColor(Theme.amberInk.opacity(0.75))

                Button("Start today’s burst", action: onStartBurst)
                    .buttonStyle(BurstButtonStyle())
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            Group {
                if burstDone {
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(Theme.print)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Theme.amberFill, Theme.amberFill.opacity(0.82)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
        )
    }

    private var sortGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sort your leftovers")
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                CategoryTile(icon: "camera.viewfinder",
                             title: "Screenshot Sweep",
                             subtitle: countLabel(screenshotCount, "screenshot"),
                             enabled: screenshotCount > 0,
                             action: onScreenshots)
                CategoryTile(icon: "clock.arrow.circlepath",
                             title: "Time Capsule",
                             subtitle: countLabel(timeCapsuleCount, "photo"),
                             enabled: timeCapsuleCount > 0,
                             action: onTimeCapsule)
                CategoryTile(icon: "square.stack",
                             title: "Duplicates",
                             subtitle: "Coming soon",
                             enabled: true) {
                    onComingSoon("Duplicate finding is coming soon.")
                }
                CategoryTile(icon: "film",
                             title: "Large Videos",
                             subtitle: videoCount > 0 ? "\(videoCount) videos · soon" : "Coming soon",
                             enabled: true) {
                    onComingSoon("Video review is coming soon.")
                }
            }
        }
    }

    private func countLabel(_ count: Int, _ noun: String) -> String {
        if isLoading && count == 0 { return "Counting…" }
        return "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    private var browseAlbumsRow: some View {
        Button(action: onAlbums) {
            HStack {
                Image(systemName: "rectangle.stack")
                    .foregroundColor(Theme.safelight)
                Text("Browse albums")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Theme.pencil)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                    .fill(Theme.print)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Browse albums")
    }

    private var recentStrip: some View {
        Group {
            if !recentAssets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent photos")
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

// Cream CTA on the amber card — PrimaryButtonStyle would be amber-on-amber.
struct BurstButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.button)
            .foregroundColor(Theme.amberInk)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.photoPaper)
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CategoryTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Theme.safelight)
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Theme.pencil)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                    .fill(Theme.print)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}
