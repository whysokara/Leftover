//
//  LargeVideosView.swift
//  Leftover
//
//  Phase 3b: a list, not a swipe deck. Thumbnail + duration + mono
//  file size per row, checkbox marking, tap-to-preview, one batch toss.
//

import SwiftUI
import Photos
import AVKit

struct VideoItem: Identifiable {
    let asset: PHAsset
    let size: Int64
    var id: String { asset.localIdentifier }
}

struct LargeVideosView: View {
    let videos: [VideoItem]
    let showingAllSizes: Bool
    let onClose: () -> Void
    let onToss: ([PHAsset], Int64) -> Void

    @State private var marked: Set<String> = []
    @State private var previewItem: VideoItem?
    @State private var appeared = false

    private var markedItems: [VideoItem] {
        videos.filter { marked.contains($0.id) }
    }
    private var markedBytes: Int64 {
        markedItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if videos.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    LeftoverBuddy(color: Theme.chipCoral, expression: .relieved)
                    Text("No Videos")
                        .font(Theme.title)
                        .foregroundColor(Theme.ink)
                }
                Spacer()
            } else {
                if showingAllSizes {
                    Text("Nothing over 50 MB — showing every video.")
                        .font(.footnote)
                        .foregroundColor(Theme.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(videos.enumerated()), id: \.element.id) { index, item in
                            videoRow(item)
                                .cascadeIn(appeared, slot: Double(index))
                            if item.id != videos.last?.id {
                                Rectangle()
                                    .fill(Theme.hairline)
                                    .frame(height: 1)
                                    .padding(.leading, 92)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage)
        .overlay(alignment: .bottom) {
            if !marked.isEmpty {
                Button("Delete \(marked.count) · \(ByteCountFormatter.string(fromByteCount: markedBytes, countStyle: .file))") {
                    onToss(markedItems.map(\.asset), markedBytes)
                    marked = []
                }
                .buttonStyle(TossButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.settle, value: marked.isEmpty)
        .onAppear { appeared = true }
        .sheet(item: $previewItem) { item in
            VideoPreview(asset: item.asset)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            BackButton(action: onClose)

            Text("Large Videos")
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func videoRow(_ item: VideoItem) -> some View {
        let isMarked = marked.contains(item.id)
        return Button {
            Haptics.impact(.light)
            withAnimation(Theme.pop) {
                if isMarked { marked.remove(item.id) } else { marked.insert(item.id) }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    PhotoThumbnailView(asset: item.asset)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 3)

                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.black.opacity(0.4)))

                    Text(durationLabel(item.asset.duration))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.65), in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(4)
                }
                .frame(width: 64, height: 64)
                .onTapGesture {
                    previewItem = item
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(dateLabel(item.asset.creationDate))
                        .font(.system(.body).weight(.semibold))
                        .foregroundColor(Theme.ink)
                    Text("Tap thumbnail to play")
                        .font(.caption)
                        .foregroundColor(Theme.dim)
                }

                Spacer(minLength: 8)

                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    .font(.footnote.monospacedDigit().weight(.semibold))
                    .foregroundColor(Theme.dim)

                Image(systemName: isMarked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isMarked ? Theme.toss : Theme.dim.opacity(0.5))
                    .scaleEffect(isMarked ? 1.1 : 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Video from \(dateLabel(item.asset.creationDate)), \(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))\(isMarked ? ", selected to delete" : "")")
        .accessibilityHint("Tap to \(isMarked ? "deselect" : "select") for deletion")
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return "Video" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct VideoPreview: View {
    let asset: PHAsset
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Theme.stage.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                ProgressView()
                    .tint(Theme.ink)
            }
        }
        .onAppear {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                DispatchQueue.main.async {
                    if let item {
                        player = AVPlayer(playerItem: item)
                    }
                }
            }
        }
    }
}
