//
//  Theme.swift
//  Leftover
//
//  "Theater" design tokens — dark-only. See DESIGN.md.
//  The app is a private screening room: photos on a near-black warm
//  stage, floating glass chrome, cream light. Keep/Toss stay semantic.
//

import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    // Color — "Headspace" palette (July 2026): warm cream canvas,
    // deep navy ink, vibrant orange accent, colorful chips per feature.
    static let stage    = Color(hex: 0xF7F3EB)   // warm cream canvas
    static let surface  = Color(hex: 0xFFFFFF)   // white cards
    static let raised   = Color(hex: 0xF1EAE0)   // soft fill
    static let ink      = Color(hex: 0x35325E)   // deep navy
    static let dim      = Color(hex: 0x8D89A8)   // muted lavender-gray
    static let cream    = Color(hex: 0xF47D31)   // vibrant orange accent
    static let creamInk = Color.white            // text on accent
    static let keep     = Color(hex: 0x3EB49E)   // teal
    static let toss     = Color(hex: 0xF25C54)   // coral
    static let hairline = Color(hex: 0xE9E2D5)   // sand line

    // Feature chip colors (Headspace-style variety)
    static let chipOrange = Color(hex: 0xF47D31)
    static let chipBlue   = Color(hex: 0x5479F7)
    static let chipPurple = Color(hex: 0x8A6FD1)
    static let chipPink   = Color(hex: 0xEF7BAE)
    static let chipTeal   = Color(hex: 0x3EB49E)
    static let chipYellow = Color(hex: 0xF2B33D)
    static let chipCoral  = Color(hex: 0xF25C54)
    static let chipNavy   = Color(hex: 0x35325E)

    // Type — chunky rounded (Headspace vibe): SF Rounded heavy display,
    // SF Pro for body.
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    static func wordmark(_ size: CGFloat = 34) -> Font { display(size) }
    static let title   = Font.system(size: 22, weight: .bold, design: .rounded)
    static let button  = Font.system(size: 17, weight: .bold, design: .rounded)

    // Shape
    static let cardRadius: CGFloat = 28
    static let buttonRadius: CGFloat = 16
    static let tileRadius: CGFloat = 16

    // Motion
    static let flick        = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let settle       = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let pop          = Animation.interpolatingSpring(stiffness: 100, damping: 6)
    static let throwOut     = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.72)
    static let stackAdvance = Animation.spring(response: 0.4, dampingFraction: 0.85)
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.button)
            .foregroundColor(Theme.creamInk)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.cream, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct TossButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.button)
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.toss, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Dock icons kick harder than ordinary buttons — paired with haptics.
struct DockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.78 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.button)
            .foregroundColor(Theme.ink)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.surface, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// The glass "xmark" circle used to exit every full-screen list/session.
struct BackButton: View {
    var label: String = "Back to home"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.ink)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }
}
