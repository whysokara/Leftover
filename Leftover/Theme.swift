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
    // Color — the theater
    static let stage    = Color(hex: 0x0D0B09)   // background
    static let surface  = Color(hex: 0x1A1712)   // cards, tiles
    static let raised   = Color(hex: 0x26221B)   // elevated surfaces
    static let ink      = Color(hex: 0xF5EFE4)   // primary text
    static let dim      = Color(hex: 0x9C9285)   // secondary text
    static let cream    = Color(hex: 0xF2E9D8)   // accent: CTAs, progress, glow
    static let creamInk = Color(hex: 0x171310)   // text on cream
    static let keep     = Color(hex: 0x82C795)   // keep stamp / counter
    static let toss     = Color(hex: 0xE56A55)   // toss stamp / delete
    static let hairline = Color(hex: 0x2E2921)   // borders

    // Type
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
    static let title   = Font.system(size: 22, weight: .heavy, design: .rounded)
    static let button  = Font.system(size: 16, weight: .bold, design: .rounded)

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
