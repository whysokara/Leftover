//
//  Theme.swift
//  Leftover
//
//  Dark design tokens (July 2026, sixth iteration — see DESIGN.md).
//  Near-black canvas, plain SF Pro type, thin outline icons on softly
//  tinted per-feature accent badges. Keep/Toss stay semantic.
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
    // Color — dark canvas, off-white ink, accents retuned to stay
    // legible (and keep their hue identity) against near-black.
    static let stage    = Color(hex: 0x121214)   // near-black canvas
    static let surface  = Color(hex: 0x1C1C1F)   // raised cards/rows
    static let raised   = Color(hex: 0x242428)   // secondary fill
    static let ink      = Color(hex: 0xF2F1F5)   // off-white primary text
    static let dim       = Color(hex: 0x9A9AA2)  // mid-gray secondary text
    static let cream    = Color(hex: 0xFF9142)   // vibrant orange accent
    static let creamInk = Color.white            // text on accent
    static let keep     = Color(hex: 0x4FD1B9)   // teal
    static let toss     = Color(hex: 0xFF6F68)   // coral
    static let hairline = Color.white.opacity(0.08) // subtle light-on-dark divider

    // Feature chip colors — same hue identity as before, brightened for
    // contrast on a dark canvas.
    static let chipOrange = Color(hex: 0xFF9142)
    static let chipBlue   = Color(hex: 0x6E93FF)
    static let chipPurple = Color(hex: 0xA48BE8)
    static let chipPink   = Color(hex: 0xFF93C4)
    static let chipTeal   = Color(hex: 0x4FD1B9)
    static let chipYellow = Color(hex: 0xFFC85C)
    static let chipCoral  = Color(hex: 0xFF6F68)
    static let chipNavy   = Color(hex: 0x8C97C4)  // was aliased to `ink`,
    // which is now the (light) text color — needs its own identity.

    // Type — plain SF Pro, no rounded design.
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold)
    }
    static func wordmark(_ size: CGFloat = 34) -> Font { display(size) }
    static let title   = Font.system(size: 22, weight: .semibold)
    static let button  = Font.system(size: 17, weight: .semibold)

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
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.ink)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

/// The shared icon treatment: a thin-weight SF Symbol in its feature's
/// accent color, sitting on a softly tinted circle of the same color —
/// replaces the old "bold filled icon on a solid chip" look everywhere
/// a feature badge appears (Home rows, Settings rows, group-review
/// accents). `dimmed` mutes both the glyph and the tint for an inactive
/// row, without changing layout.
struct IconBadge: View {
    let icon: String
    let chip: Color
    var size: CGFloat = 36
    var dimmed: Bool = false

    private var tint: Color { dimmed ? Theme.dim : chip }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(dimmed ? 0.14 : 0.16)))
    }
}

extension View {
    /// Sections fade-slide in with a small stagger once `appeared` flips
    /// true — the same on-load reveal HomeView originated, promoted here
    /// so every screen's first appearance can share it.
    func cascadeIn(_ appeared: Bool, slot: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : (UIAccessibility.isReduceMotionEnabled ? 0 : 14))
            .animation(Theme.settle.delay(slot * 0.05), value: appeared)
    }
}
