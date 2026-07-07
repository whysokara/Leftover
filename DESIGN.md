# Leftover Design System — "Light Table / Darkroom"

Visual spec (with rendered components): https://claude.ai/code/artifact/e0f37ee7-d386-4059-95cf-7ec8e26180f3

## The vibe

A photographer culling a contact sheet. **Light mode is the light table** — warm paper, the photos do the talking. **Dark mode is the darkroom** — warm charcoal lit by a safelight-amber accent. Decisions are marked like grease pencil on film: circle what stays (**KEEP**), cross what goes (**TOSS**).

Personality: tidy, warm, decisive. Deleting photos should feel like wiping a counter, not defusing a bomb.

## Color

Neutrals are warm-biased — never pure gray. One brand accent (safelight amber). Keep/Toss are semantic and are **never** used decoratively.

| Token | Light (Light Table) | Dark (Darkroom) | Role |
|---|---|---|---|
| `paper` | `#F7F4ED` | `#15120E` | Background |
| `print` | `#FFFFFF` | `#201C16` | Cards, surfaces |
| `ink` | `#26211A` | `#F1EAE0` | Primary text |
| `pencil` | `#7D7466` | `#9C9080` | Secondary text |
| `safelight` | `#B97B1C` | `#E89B2E` | Accent (text/links) |
| `amberFill` | `#E89B2E` | `#E89B2E` | Primary buttons — always dark ink text on top |
| `keep` | `#3E7C4F` | `#82C795` | Right-swipe stamp, keep confirmations |
| `toss` | `#BC4632` | `#E56A55` | Left-swipe stamp, delete buttons, destructive alerts |
| `hairline` | `#E3DCCD` | `#352F26` | Borders, dividers |

## Typography

No bundled fonts. The identity comes from committing to **SF Pro Rounded at heavy weights** for personality, SF Pro for reading, SF Mono for numbers.

| Role | Face | Spec |
|---|---|---|
| Display (wordmark, titles) | SF Rounded | Black, 34pt (LargeTitle) |
| Title | SF Rounded | Heavy, 22pt |
| Body | SF Pro | Regular, 17pt |
| Buttons | SF Rounded | Bold, 16pt |
| Caption | SF Pro | Regular, 13pt |
| Labels (eyebrows) | SF Mono | Semibold, 11pt, +16% tracking, uppercase |
| Counters ("137 / 248 · 1.2 GB") | SF Mono | Tabular figures — digits never jitter |

**Dynamic Type:** support the full range including accessibility sizes. Never cap with `.dynamicTypeSize(.small ... .xxLarge)`.

## Shape & space

Everything is a print on a table: continuous (squircle) corners, one soft shadow level, hairline borders.

- Photo card: radius **20**, continuous · Buttons: **14** · Album tiles: **12** · Thumbs: **8** · Pills/toasts: **capsule**
- Spacing snaps to a 4pt grid: `4 / 8 / 12 / 16 / 24 / 32 / 48`. No ad-hoc 10s and 6s.
- Tap targets ≥ 44pt everywhere.

## Motion & haptics

Springs, not curves. Respect Reduce Motion (crossfade instead of fly; keep haptics).

| Name | Spec | Used for | Haptic |
|---|---|---|---|
| Flick | `.spring(response: 0.35, dampingFraction: 0.8)` | Card exits, stamp ink-in | `.rigid` on toss, `.soft` on keep |
| Settle | `.spring(response: 0.45, dampingFraction: 0.85)` | Undo return, transitions, toast entry | none |
| Pop | `.interpolatingSpring(stiffness: 100, damping: 6)` | Heart favorite (already shipping — keep) | `.light` |
| Batch delete | progress ring → toast via Settle | The payoff moment | `notification(.success)` |

**The signature moment:** as the user drags, a KEEP (green, circled, rotated −8°) or TOSS (red, boxed, rotated +6°) stamp inks onto the photo with opacity proportional to drag distance — like a grease pencil hitting film.

## Voice

Verbs first, numbers honest. Short, decisive, a little proud of you.

- "Delete 12 Now" → **"Toss 12 photos"**
- "You're done swiping!" → **"That's the whole album."**
- "Loading photos..." → **"Opening Screenshots…"**
- Failure: **"Couldn't toss those — your photos are untouched. Try again?"** (never a silent `print`)
- The freed-space number is only shown once it's real.

## Theme.swift (drop-in tokens)

```swift
import SwiftUI

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

    // Type
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
    static let title   = Font.system(size: 22, weight: .heavy, design: .rounded)
    static let button  = Font.system(size: 16, weight: .bold, design: .rounded)
    static let counter = Font.system(size: 15, design: .monospaced)

    // Shape
    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 14
    static let tileRadius: CGFloat = 12

    // Motion
    static let flick  = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let settle = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let pop    = Animation.interpolatingSpring(stiffness: 100, damping: 6)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.button)
            .foregroundColor(Theme.amberInk)
            .padding(.vertical, 14).padding(.horizontal, 20)
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
            .padding(.vertical, 14).padding(.horizontal, 20)
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
            .padding(.vertical, 14).padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .overlay(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
```

## Adoption order

1. Add `Theme.swift`; replace `Color(.systemBackground)` with `Theme.paper`.
2. Restyle buttons and the snackbar/toast with the three button styles + capsule toast.
3. Add the KEEP/TOSS drag stamps to the swipe card (the signature moment).
4. Apply to empty/permission/done states.
5. Album grid: SF Rounded titles, tabular counts, amber ring on the current filmstrip frame.
