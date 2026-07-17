//
//  OnboardingView.swift
//  Leftover
//
//  First-run flow, replayable from Settings ("How Leftover Works"):
//  practice the swipe on demo cards, hear the safety story, then get
//  primed before the system photo-permission dialog fires. Three
//  steps, forward-only, skippable. The practice card is a scaled-down
//  copy of the real swipe screen's physics so the first real swipe
//  feels familiar.
//

import SwiftUI
import Photos
import UIKit

struct OnboardingView: View {
    var initialStep: Int = 0
    let onFinished: () -> Void

    @State private var step: Int
    @State private var appeared = false

    // Practice-card state — mirrors the swipe screen's model in miniature.
    @State private var practiceOffset: CGSize = .zero
    @State private var practiceThrown = 0
    @State private var isThrowing = false

    @State private var authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    init(initialStep: Int = 0, onFinished: @escaping () -> Void) {
        self.initialStep = initialStep
        self.onFinished = onFinished
        _step = State(initialValue: initialStep)
    }

    private var pushTransition: AnyTransition {
        UIAccessibility.isReduceMotionEnabled
            ? .opacity
            : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                          removal: .move(edge: .leading).combined(with: .opacity))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 12)

            Group {
                switch step {
                case 0: practiceStep
                case 1: trustStep
                default: permissionStep
                }
            }
            .id(step)
            .transition(pushTransition)

            Spacer(minLength: 16)

            progressDots
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage)
        .onAppear { appeared = true }
    }

    private var header: some View {
        HStack {
            Spacer()
            if step < 2 {
                Button("Skip") { onFinished() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.dim)
                    .frame(height: 44)
                    .accessibilityHint("Skips the introduction")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(height: 52)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == step ? Theme.cream : Theme.dim.opacity(0.35))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(Theme.settle, value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step + 1) of 3")
    }

    // MARK: - Step 1: practice the swipe

    private var practiceStep: some View {
        VStack(spacing: 14) {
            Text("Swipe to Decide")
                .font(Theme.display(30))
                .foregroundColor(Theme.ink)
                .cascadeIn(appeared, slot: 0)

            Text("Left deletes. Right keeps.\nNothing happens until you confirm.")
                .font(.subheadline)
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)
                .cascadeIn(appeared, slot: 1)

            practiceStack
                .cascadeIn(appeared, slot: 2)
                .padding(.vertical, 6)

            Text(practiceThrown == 0 ? "Try it — swipe left to delete" : "Now swipe right to keep")
                .font(.footnote.weight(.semibold))
                .foregroundColor(practiceThrown == 0 ? Theme.toss : Theme.keep)
                .animation(Theme.settle, value: practiceThrown)

            // Tap-first / VoiceOver path — same code path as the gesture.
            HStack(spacing: 14) {
                practiceDockButton("trash.fill", chip: Theme.chipCoral, label: "Delete") {
                    throwPractice(toss: true)
                }
                practiceDockButton("checkmark", chip: Theme.chipTeal, label: "Keep") {
                    throwPractice(toss: false)
                }
            }
            .cascadeIn(appeared, slot: 3)
        }
        .padding(.horizontal, 24)
    }

    private var practiceStack: some View {
        ZStack {
            // The real screen's edge glows, in miniature.
            HStack(spacing: 0) {
                LinearGradient(colors: [Theme.toss.opacity(0.5), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 70)
                    .opacity(glowProgress(-practiceOffset.width))
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, Theme.keep.opacity(0.5)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 70)
                    .opacity(glowProgress(practiceOffset.width))
            }
            .allowsHitTesting(false)

            ForEach(Array((practiceThrown..<2).reversed()), id: \.self) { index in
                practiceCard(index, isTop: index == practiceThrown)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 310)
    }

    private func practiceCard(_ index: Int, isTop: Bool) -> some View {
        let faces: [(chip: Color, icon: String)] = [(Theme.chipOrange, "sparkles"),
                                                    (Theme.chipPink, "heart")]
        let face = faces[min(index, faces.count - 1)]

        return ZStack {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(face.chip)
            LinearGradient(colors: [.white.opacity(0.30), .clear, .black.opacity(0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 10) {
                Image(systemName: face.icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundColor(Theme.onChip.opacity(0.9))
                Text("Practice card")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Theme.onChip.opacity(0.75))
            }
        }
        .frame(width: 232, height: 296)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.38), .white.opacity(0.03)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1)
        )
        .scaleEffect(isTop ? 1 : 0.94)
        .offset(y: isTop ? 0 : -14)
        .opacity(isTop ? 1 : 0.7)
        .offset(x: isTop ? practiceOffset.width : 0,
                y: isTop ? practiceOffset.height * 0.35 : 0)
        .rotationEffect(.degrees(isTop ? Double(practiceOffset.width / 18) : 0),
                        anchor: .bottom)
        .zIndex(isTop ? 1 : 0)
        .gesture(practiceDrag, including: isTop && !isThrowing ? .all : .none)
        .accessibilityElement()
        .accessibilityLabel(isTop ? "Practice card" : "Next practice card")
        .accessibilityHint(isTop ? "Use the Delete or Keep buttons below to try a decision" : "")
        .accessibilityHidden(!isTop)
    }

    private var practiceDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                practiceOffset = value.translation
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                if value.translation.width < -80 || projected < -220 {
                    throwPractice(toss: true)
                } else if value.translation.width > 80 || projected > 220 {
                    throwPractice(toss: false)
                } else {
                    withAnimation(Theme.settle) { practiceOffset = .zero }
                }
            }
    }

    private func practiceDockButton(_ icon: String, chip: Color, label: String,
                                    action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.onChip)
                .frame(width: 46, height: 46)
                .background(Circle().fill(chip))
        }
        .buttonStyle(DockButtonStyle())
        .accessibilityLabel(label)
    }

    private func glowProgress(_ distance: CGFloat) -> Double {
        Double(min(max(distance - 24, 0) / 160, 1))
    }

    private func throwPractice(toss: Bool) {
        guard !isThrowing, practiceThrown < 2 else { return }
        Haptics.impact(toss ? .rigid : .soft)

        if UIAccessibility.isReduceMotionEnabled {
            commitPractice()
            return
        }

        isThrowing = true
        withAnimation(Theme.throwOut) {
            practiceOffset = CGSize(width: (toss ? -1 : 1) * 520, height: -20)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            commitPractice()
            isThrowing = false
        }
    }

    private func commitPractice() {
        withAnimation(Theme.stackAdvance) { practiceThrown += 1 }
        practiceOffset = .zero
        if practiceThrown >= 2 {
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(Theme.settle) { step = 1 }
            }
        }
    }

    // MARK: - Step 2: trust

    private var trustStep: some View {
        VStack(spacing: 24) {
            Text("Your Photos Are Safe")
                .font(Theme.display(30))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 18) {
                trustRow("checkmark.shield", "Nothing is deleted until you confirm.")
                trustRow("clock.arrow.circlepath", "Deleted photos stay in Recently Deleted for 30 days.")
                trustRow("iphone", "Everything stays on this iPhone — no cloud, no accounts.")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
            )

            Button("Continue") {
                withAnimation(Theme.settle) { step = 2 }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
        .padding(.horizontal, 24)
    }

    private func trustRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            IconBadge(icon: icon, chip: Theme.chipTeal, size: 32)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Step 3: permission primer

    private var permissionStep: some View {
        VStack(spacing: 16) {
            IconBadge(icon: "photo.on.rectangle.angled", chip: Theme.chipBlue, size: 72)

            Text("One Permission")
                .font(Theme.display(30))
                .foregroundColor(Theme.ink)

            Text("Leftover needs full photo access to find duplicates, screenshots, and blurry shots. Photos never leave your phone.")
                .font(.subheadline)
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Group {
                switch authStatus {
                case .notDetermined:
                    Button("Allow Photo Access") { requestAccess() }
                        .buttonStyle(PrimaryButtonStyle())
                case .authorized, .limited:
                    // Replay path — access already granted.
                    Button("Done") { onFinished() }
                        .buttonStyle(PrimaryButtonStyle())
                default:
                    VStack(spacing: 10) {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button("Done") { onFinished() }
                            .buttonStyle(QuietButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    private func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            // Whatever they chose, onboarding is done — Home's own
            // request resolves instantly now that status is determined.
            DispatchQueue.main.async { onFinished() }
        }
    }
}
