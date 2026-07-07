//
//  Theme.swift
//  Leftover
//
//  "Light Table / Darkroom" design tokens — see DESIGN.md.
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
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}

enum Theme {
    // Color — light table / darkroom
    static let paper     = Color(light: 0xF7F4ED, dark: 0x15120E)
    static let print     = Color(light: 0xFFFFFF, dark: 0x201C16)
    static let ink       = Color(light: 0x26211A, dark: 0xF1EAE0)
    static let pencil    = Color(light: 0x7D7466, dark: 0x9C9080)
    static let safelight = Color(light: 0xB97B1C, dark: 0xE89B2E)
    static let amberFill = Color(hex: 0xE89B2E)   // always dark ink text on top
    static let amberInk  = Color(hex: 0x2A1F0C)
    static let keep      = Color(light: 0x3E7C4F, dark: 0x82C795)
    static let toss      = Color(light: 0xBC4632, dark: 0xE56A55)
    static let hairline  = Color(light: 0xE3DCCD, dark: 0x352F26)

    // Darkroom constants for the toast, which stays dark in both themes
    static let darkroom      = Color(hex: 0x15120E)
    static let photoPaper    = Color(hex: 0xF1EAE0)

    // Type
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
    static let title   = Font.system(size: 22, weight: .heavy, design: .rounded)
    static let button  = Font.system(size: 16, weight: .bold, design: .rounded)

    // Shape
    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 14
    static let tileRadius: CGFloat = 12

    // Motion
    static let flick  = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let settle = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let pop    = Animation.interpolatingSpring(stiffness: 100, damping: 6)
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
            .foregroundColor(Theme.amberInk)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.amberFill)
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
            .overlay(
                RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Decision stamp (the grease-pencil KEEP / TOSS mark)

struct DecisionStamp: View {
    let isKeep: Bool

    var body: some View {
        Text(isKeep ? "KEEP" : "TOSS")
            .font(.system(size: 22, weight: .black, design: .rounded))
            .tracking(2)
            .foregroundColor(isKeep ? Theme.keep : Theme.toss)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: isKeep ? 999 : 8, style: .continuous)
                    .stroke(isKeep ? Theme.keep : Theme.toss, lineWidth: 3.5)
            )
            .rotationEffect(.degrees(isKeep ? -8 : 6))
    }
}
