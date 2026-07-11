//
//  LeftoverBuddy.swift
//  Leftover
//
//  A tiny procedurally-drawn face — a circle, two eyes, one mouth
//  curve, all plain SwiftUI shapes. No hand-drawn line art (the
//  "Doodle" redesign was rejected for looking sketchy/cheap); this
//  stays deliberately minimal so it reads as a clean geometric icon,
//  not an illustration that needs real art skill to not look off.
//  Appears only in empty/celebration states that had zero personality
//  before — it never replaces the app's existing feature iconography.
//

import SwiftUI

enum BuddyExpression {
    case happy
    case relieved
    case sleepy
    case surprised
    case wink
}

struct LeftoverBuddy: View {
    var color: Color = Theme.chipOrange
    var expression: BuddyExpression = .happy
    var size: CGFloat = 72

    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .shadow(color: color.opacity(0.35), radius: size * 0.22, y: size * 0.08)

            eyes
            MouthShape(expression: expression)
                .stroke(Color.white, style: StrokeStyle(lineWidth: max(2, size * 0.045), lineCap: .round))
                .frame(width: size * 0.36, height: size * 0.2)
                .offset(y: size * 0.14)
        }
        .frame(width: size, height: size)
        .scaleEffect(appeared ? 1 : 0.4)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            guard !appeared else { return }
            withAnimation(Theme.pop) { appeared = true }
        }
        .accessibilityHidden(true)
    }

    private var eyes: some View {
        HStack(spacing: size * 0.2) {
            eyeShape(isLeft: true)
            eyeShape(isLeft: false)
        }
        .offset(y: -size * 0.08)
    }

    @ViewBuilder
    private func eyeShape(isLeft: Bool) -> some View {
        let eyeSize = size * 0.1
        if expression == .sleepy || (expression == .wink && isLeft) {
            Capsule()
                .fill(Color.white)
                .frame(width: eyeSize, height: max(2, eyeSize * 0.28))
        } else {
            Circle()
                .fill(Color.white)
                .frame(width: eyeSize, height: eyeSize)
        }
    }
}

private struct MouthShape: Shape {
    var expression: BuddyExpression

    func path(in rect: CGRect) -> Path {
        Path { path in
            switch expression {
            case .happy, .relieved:
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                                   control: CGPoint(x: rect.midX, y: rect.maxY))
            case .wink:
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                                   control: CGPoint(x: rect.midX, y: rect.maxY * 1.1))
            case .sleepy:
                path.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.midY))
            case .surprised:
                path.addEllipse(in: CGRect(x: rect.midX - rect.width * 0.15, y: rect.minY,
                                           width: rect.width * 0.3, height: rect.height))
            }
        }
    }
}
