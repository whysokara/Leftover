//
//  Gamification.swift
//  Leftover
//
//  The retention layer, all local and all honest:
//  - HealthScore: a 0–100 library score computed from what the
//    scanners actually find — new clutter drops it, cleaning raises
//    it. State maintenance, not chain-breaking.
//  - HealthDetailView: the score's breakdown sheet; every penalty row
//    deep-links into the cleanup screen that fixes it.
//  - TrophyShelfView: the milestone badges, owned and browsable
//    instead of flashing once and vanishing.
//

import SwiftUI

// MARK: - Score

struct HealthScore {
    struct Part: Identifiable {
        let id: String
        let name: String
        let icon: String
        let chip: Color
        let penalty: Int
        let detail: String
    }

    let score: Int
    let grade: String
    let parts: [Part]
    let isProvisional: Bool

    var color: Color {
        if score >= 85 { return Theme.keep }
        if score >= 60 { return Theme.chipYellow }
        return Theme.toss
    }

    /// Penalties are capped and ratio-based so a 30,000-photo library
    /// isn't judged harsher than a 300-photo one: each signal scales
    /// with sqrt(ratio / refRatio), where refRatio is the proportion
    /// considered "fully bad" for that signal. sqrt keeps small messes
    /// visible without letting one signal instantly floor the score.
    static func compute(libraryCount: Int,
                        duplicateCount: Int,
                        similarCount: Int,
                        blurryCount: Int,
                        staleScreenshots: Int,
                        videoBytes: Int64,
                        hasScanned: Bool) -> HealthScore {
        let library = max(libraryCount, 1)

        func penalty(_ count: Int, cap: Double, refRatio: Double) -> Int {
            guard count > 0 else { return 0 }
            let ratio = Double(count) / Double(library)
            return Int((cap * min(1, (ratio / refRatio).squareRoot())).rounded())
        }

        // Videos scale against bytes, not counts — 2 GB of large
        // videos is "fully bad" regardless of library size.
        let videoPenalty: Int = {
            guard videoBytes > 0 else { return 0 }
            let ratio = Double(videoBytes) / 2_000_000_000
            return Int((10 * min(1, ratio.squareRoot())).rounded())
        }()

        var parts: [Part] = []
        func add(_ id: String, _ name: String, _ icon: String, _ chip: Color,
                 _ value: Int, _ detail: String) {
            guard value > 0 else { return }
            parts.append(Part(id: id, name: name, icon: icon, chip: chip,
                              penalty: value, detail: detail))
        }

        if hasScanned {
            add("duplicates", "Duplicates", "square.on.square", Theme.chipTeal,
                penalty(duplicateCount, cap: 30, refRatio: 0.10),
                "\(duplicateCount.formatted()) extra copies")
            add("similar", "Similar Shots", "square.stack.3d.down.right", Theme.chipPink,
                penalty(similarCount, cap: 20, refRatio: 0.15),
                "\(similarCount.formatted()) near-repeats")
            add("blurry", "Blurry", "wand.and.rays", Theme.chipYellow,
                penalty(blurryCount, cap: 15, refRatio: 0.08),
                "\(blurryCount.formatted()) blurry shots")
        }
        add("screenshots", "Old Screenshots", "camera.viewfinder", Theme.chipBlue,
            penalty(staleScreenshots, cap: 25, refRatio: 0.20),
            "\(staleScreenshots.formatted()) older than a month")
        add("videos", "Large Videos", "film", Theme.chipCoral,
            videoPenalty,
            ByteCountFormatter.string(fromByteCount: videoBytes, countStyle: .file))

        parts.sort { $0.penalty > $1.penalty }
        let score = max(0, 100 - parts.reduce(0) { $0 + $1.penalty })
        let grade: String
        switch score {
        case 90...: grade = "A"
        case 75...: grade = "B"
        case 60...: grade = "C"
        case 40...: grade = "D"
        default:    grade = "E"
        }
        return HealthScore(score: score, grade: grade, parts: parts,
                           isProvisional: !hasScanned)
    }
}

// MARK: - Health sheet

struct HealthDetailView: View {
    let health: HealthScore
    /// Part id → navigation into the matching cleanup screen.
    let onFix: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    scoreRing
                        .cascadeIn(appeared, slot: 0)
                        .padding(.top, 12)

                    if health.isProvisional {
                        Text("Run the Duplicates, Similar, or Blurry scan for your full score.")
                            .font(.footnote)
                            .foregroundColor(Theme.dim)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .cascadeIn(appeared, slot: 1)
                    }

                    if health.parts.isEmpty {
                        VStack(spacing: 12) {
                            LeftoverBuddy(color: Theme.keep, expression: .relieved, size: 56)
                            Text("Nothing is dragging your score down.")
                                .font(.subheadline)
                                .foregroundColor(Theme.dim)
                        }
                        .cascadeIn(appeared, slot: 2)
                        .padding(.top, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(health.parts.enumerated()), id: \.element.id) { index, part in
                                partRow(part)
                                if part.id != health.parts.last?.id {
                                    Rectangle()
                                        .fill(Theme.hairline)
                                        .frame(height: 1)
                                        .padding(.leading, 62)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Theme.surface)
                        )
                        .padding(.horizontal, 20)
                        .cascadeIn(appeared, slot: 2)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.stage)
            .navigationTitle("Library Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundColor(Theme.cream)
                }
            }
            .onAppear { appeared = true }
        }
    }

    private var scoreRing: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Theme.hairline, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: Double(health.score) / 100)
                    .stroke(health.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(health.score)")
                        .font(Theme.display(34))
                        .foregroundColor(Theme.ink)
                        .contentTransition(.numericText())
                    Text(health.grade)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(health.color)
                }
            }
            .frame(width: 150, height: 150)

            Text(health.isProvisional ? "Partial score" : "Library health")
                .font(.footnote)
                .foregroundColor(Theme.dim)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Library health \(health.score) out of 100, grade \(health.grade)\(health.isProvisional ? ", partial" : "")")
    }

    private func partRow(_ part: HealthScore.Part) -> some View {
        Button {
            onFix(part.id)
        } label: {
            HStack(spacing: 12) {
                IconBadge(icon: part.icon, chip: part.chip, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(part.name)
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(Theme.ink)
                    Text(part.detail)
                        .font(.footnote)
                        .foregroundColor(Theme.dim)
                }
                Spacer(minLength: 8)
                Text("−\(part.penalty)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(Theme.toss)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.dim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(part.name), \(part.detail), costing \(part.penalty) points")
        .accessibilityHint("Opens \(part.name)")
    }
}

// MARK: - Trophies

struct TrophyShelfView: View {
    let achieved: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    // Mirrors Stats.checkMilestones exactly — names are the join key.
    private static let badges: [(name: String, goal: String, icon: String, chip: Color)] = [
        ("100 photos deleted", "Delete 100 photos", "trash", Theme.chipCoral),
        ("1,000 photos deleted", "Delete 1,000 photos", "trash.fill", Theme.chipCoral),
        ("10,000 photos deleted", "Delete 10,000 photos", "trash.circle.fill", Theme.chipCoral),
        ("1 GB freed", "Free 1 GB", "arrow.down.circle", Theme.chipOrange),
        ("5 GB freed", "Free 5 GB", "arrow.down.circle.fill", Theme.chipOrange),
        ("10 GB freed", "Free 10 GB", "sparkles", Theme.chipOrange),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                          spacing: 14) {
                    ForEach(Array(Self.badges.enumerated()), id: \.element.name) { index, badge in
                        badgeCell(badge, unlocked: achieved.contains(badge.name))
                            .cascadeIn(appeared, slot: Double(index) * 0.5)
                    }
                }
                .padding(20)
            }
            .background(Theme.stage)
            .navigationTitle("Trophies · \(achieved.count) of \(Self.badges.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundColor(Theme.cream)
                }
            }
            .onAppear { appeared = true }
        }
    }

    private func badgeCell(_ badge: (name: String, goal: String, icon: String, chip: Color),
                           unlocked: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(unlocked ? badge.chip.opacity(0.18) : Theme.raised)
                Image(systemName: badge.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(unlocked ? badge.chip : Theme.dim.opacity(0.5))
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.dim)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.surface))
                        .offset(x: 22, y: 22)
                }
            }
            .frame(width: 64, height: 64)

            Text(badge.name)
                .font(.footnote.weight(.semibold))
                .foregroundColor(unlocked ? Theme.ink : Theme.dim)
                .multilineTextAlignment(.center)
            Text(unlocked ? "Earned" : badge.goal)
                .font(.caption2)
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.name), \(unlocked ? "earned" : "locked — \(badge.goal)")")
    }
}
