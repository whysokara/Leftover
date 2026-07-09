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
    // Color — iOS system semantics (July 2026: warm Theater palette
    // retired for the native Apple look; token names kept so views
    // never change).
    static let stage    = Color(uiColor: .systemBackground)                 // background
    static let surface  = Color(uiColor: .secondarySystemGroupedBackground) // cards, tiles
    static let raised   = Color(uiColor: .tertiarySystemFill)               // icon chips
    static let ink      = Color.primary                                     // primary text
    static let dim      = Color.secondary                                   // secondary text
    static let cream    = Color(uiColor: .systemBlue)                       // accent: CTAs, progress, glow
    static let creamInk = Color.white                                       // text on accent
    static let keep     = Color(uiColor: .systemGreen)                      // keep counter / glow
    static let toss     = Color(uiColor: .systemRed)                        // delete counter / buttons
    static let hairline = Color(uiColor: .separator)                        // borders

    // Type — Apple-standard SF Pro semantic styles, sized like the
    // system apps (Settings/Photos). Rounded and serif faces retired.
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold)
    }
    static func wordmark(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold)
    }
    static let title   = Font.title2.bold()
    static let button  = Font.body.weight(.semibold)

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
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
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
            .background(Theme.toss)
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
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
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
