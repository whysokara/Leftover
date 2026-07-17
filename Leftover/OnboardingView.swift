//
//  OnboardingView.swift
//  Leftover
//
//  First-run flow, replayable from Settings ("How Leftover Works"):
//  practice the swipe on demo cards, then get primed for full photo
//  access with the trust story folded in right under the ask. Two
//  steps, value first (a real gesture, a micro-win) then permission —
//  forward-only, skippable on the practice step. The practice card is a
//  scaled-down copy of the real swipe screen's physics so the first
//  real swipe feels familiar. On a genuine first run, finishing drops
//  the user straight into their first cleanup (see ContentView).
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

    private let stepCount = 2

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
                default: permissionStep
                }
            }
            .id(step)
            .transition(pushTransition)

            Spacer(minLength: 16)

            progressDots
                .padding(.bottom, Theme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage)
        .onAppear { appeared = true }
    }

    private var header: some View {
        HStack {
            // Carries the splash wordmark into onboarding — brand
            // continuity, and it anchors the leading edge so "Skip"
            // isn't an orphan floating in an empty bar.
            Text("Leftover")
                .font(Theme.wordmark(20))
                .foregroundColor(Theme.ink)

            Spacer()

            // Skip only before the permission ask — the last step is the
            // one thing onboarding actually needs.
            if step < 1 {
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
            ForEach(0..<stepCount, id: \.self) { index in
                Circle()
                    .fill(index == step ? Theme.cream : Theme.dim.opacity(0.35))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(Theme.settle, value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(min(step, stepCount - 1) + 1) of \(stepCount)")
    }

    // MARK: - Step 1: practice the swipe

    private var practiceStep: some View {
        VStack(spacing: Theme.Space.lg) {
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

            Text(hintText)
                .font(.footnote.weight(.semibold))
                .foregroundColor(hintColor)
                .multilineTextAlignment(.center)
                .animation(Theme.settle, value: practiceThrown)

            // Tap-first / VoiceOver path — same code path as the gesture.
            // Fades out once both cards are done so there's nothing to tap
            // into, without collapsing the layout.
            HStack(spacing: 14) {
                practiceDockButton("trash.fill", chip: Theme.chipCoral, label: "Delete") {
                    throwPractice(toss: true)
                }
                practiceDockButton("checkmark", chip: Theme.chipTeal, label: "Keep") {
                    throwPractice(toss: false)
                }
            }
            .opacity(practiceThrown >= 2 ? 0 : 1)
            .disabled(practiceThrown >= 2)
            .animation(Theme.settle, value: practiceThrown)
            .cascadeIn(appeared, slot: 3)
        }
        .padding(.horizontal, 24)
        .onAppear(perform: scheduleHintNudge)
    }

    private var hintText: String {
        switch practiceThrown {
        case 0: return "Try it — swipe left to delete"
        case 1: return "Now swipe right to keep"
        default: return "That's the whole app — nothing's gone until you confirm."
        }
    }

    private var hintColor: Color {
        practiceThrown == 0 ? Theme.toss : Theme.keep
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

            if practiceThrown >= 2 {
                // The micro-win: they made both calls, nothing broke.
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundColor(Theme.keep)
                    .shadow(color: Theme.keep.opacity(0.4), radius: 18)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .accessibilityHidden(true)
            } else {
                ForEach(Array((practiceThrown..<2).reversed()), id: \.self) { index in
                    practiceCard(index, isTop: index == practiceThrown)
                }
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

    /// If the user just sits on the practice card, nudge it toward the
    /// delete edge so the gesture teaches itself. Repeats once more while
    /// still idle, then leaves them alone. Off under Reduce Motion.
    private func scheduleHintNudge() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { nudgeIfIdle(repeatAgain: true) }
    }

    private func nudgeIfIdle(repeatAgain: Bool) {
        guard step == 0, practiceThrown == 0, !isThrowing, practiceOffset == .zero else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.5)) {
            practiceOffset = CGSize(width: -54, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard practiceThrown == 0, !isThrowing else { return }
            withAnimation(Theme.settle) { practiceOffset = .zero }
            if repeatAgain {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { nudgeIfIdle(repeatAgain: false) }
            }
        }
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
            // Let the success mark and copy land before moving on.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(Theme.settle) { step = 1 }
            }
        }
    }

    // MARK: - Step 2: permission, with the trust story folded in

    private var permissionStep: some View {
        VStack(spacing: Theme.Space.lg) {
            IconBadge(icon: "photo.on.rectangle.angled", chip: Theme.chipBlue, size: 72)
                .cascadeIn(appeared, slot: 0)

            Text("Let's find your clutter")
                .font(Theme.display(30))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)
                .cascadeIn(appeared, slot: 1)

            Text("Full access lets Leftover surface duplicates, screenshots, and blurry shots — found and cleared right here, never uploaded.")
                .font(.subheadline)
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .cascadeIn(appeared, slot: 2)

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
            .padding(.top, Theme.Space.xs)
            .cascadeIn(appeared, slot: 3)

            // The old standalone "trust" step, condensed to badges and
            // parked right under the button — reassurance where the
            // finger hovers, not a screen earlier.
            trustStrip
                .padding(.top, Theme.Space.sm)
                .cascadeIn(appeared, slot: 4)
        }
        .padding(.horizontal, 24)
    }

    private var trustStrip: some View {
        HStack(alignment: .top, spacing: 0) {
            trustBadge("lock.fill", "On device")
            trustBadge("icloud.slash.fill", "Never uploaded")
            trustBadge("clock.arrow.circlepath", "30-day undo")
        }
    }

    private func trustBadge(_ icon: String, _ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.chipTeal)
            Text(text)
                .font(.caption2)
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            // Whatever they chose, onboarding is done — Home's own
            // request resolves instantly now that status is determined.
            DispatchQueue.main.async { onFinished() }
        }
    }
}
