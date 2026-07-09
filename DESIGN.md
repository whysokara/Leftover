# Leftover Design System — Native Light

## The vibe

A native Apple app with real physics. **Light mode**, system colors, system type — the interface disappears and the photos and motion carry the personality. Decisions stay physical — cards tilt and get thrown, the screen edge glows the decision color, the stack advances underneath.

Personality: quiet, confident, decisive. The photos do the talking; the interface whispers.

Predecessors (see git history): "Light Table / Darkroom", then the dark "Theater" system — both retired July 2026 for the native look.

## Color

**iOS system semantics only** (July 2026: the warm cream/amber palette was retired for a native Apple look). Token names in `Theme.swift` survive; only their values changed — views never reference system colors directly.

| Token | Value | Role |
|---|---|---|
| `stage` | `systemBackground` | Background (white — app forces light) |
| `surface` | `secondarySystemGroupedBackground` | Cards, tiles |
| `raised` | `tertiarySystemFill` | Icon chips |
| `ink` | `Color.primary` | Primary text |
| `dim` | `Color.secondary` | Secondary text |
| `cream` | `systemBlue` | Accent: CTAs, progress fill, glow (name is historical) |
| `creamInk` | `.white` | Text on accent buttons |
| `keep` | `systemGreen` | Keep counter, right edge glow |
| `toss` | `systemRed` | Delete counter, left edge glow, delete buttons |
| `hairline` | `separator` | Borders, progress track |

Glass: `.ultraThinMaterial` + 1px `hairline` stroke, for the action dock, top-bar pills, and toasts.

**Light enforcement:** `UIUserInterfaceStyle = Light` in Info.plist and `.preferredColorScheme(.light)` on the root view. Tokens are system semantics, so dark support later is a two-line change.

## Typography

No bundled fonts, no display faces. **SF Pro with Apple's semantic text styles, sized like the system apps** (July 2026: rounded and serif retired — the personality lives in color, motion, and copy, not letterforms).

| Role | Spec |
|---|---|
| Wordmark / screen titles | SF Pro Bold, 34pt (`Theme.wordmark` — matches system large titles) |
| Display (celebrations) | SF Pro Bold, 30pt (`Theme.display`) |
| Section titles | `.title2.bold()` (`Theme.title`) |
| Row titles / body | `.body` semibold / regular |
| Buttons | `.body.weight(.semibold)` (`Theme.button`) |
| Row details, counters | `.footnote` / `.subheadline` + `.monospacedDigit()` — bare values, one line, like Settings |

Counters animate with `.contentTransition(.numericText())` — digits roll, never jitter.

**Dynamic Type:** full range including accessibility sizes. Never cap with `.dynamicTypeSize(...)`.

## Shape & space

- Photo cards: radius **28**, continuous · Buttons: **16** · Tiles: **16** · Docks/pills/toasts: **capsule**
- Spacing snaps to a 4pt grid.
- Tap targets ≥ 44pt (dock buttons are 60×52).
- One shadow language: black, soft, large radius — cards throw `black.opacity(0.55), radius 22`; floating chrome `0.4, radius 16`.

## Motion & haptics

Springs, not curves. Respect Reduce Motion (`UIAccessibility.isReduceMotionEnabled` → crossfade instead of throw; keep haptics).

| Name | Spec | Used for | Haptic |
|---|---|---|---|
| Flick | `.spring(response: 0.35, dampingFraction: 0.8)` | Small state pops | — |
| Settle | `.spring(response: 0.45, dampingFraction: 0.85)` | Screen transitions, progress bar, toast | — |
| Pop | `.interpolatingSpring(stiffness: 100, damping: 6)` | Heart favorite, celebration glyph, streak flame | `.light` |
| ThrowOut | `.interactiveSpring(response: 0.3, dampingFraction: 0.72)` | Card leaving the screen | `.rigid` toss / `.soft` keep |
| StackAdvance | `.spring(response: 0.4, dampingFraction: 0.85)` | Next card promoting to the top | — |

**The signature moment** is now a sequence: drag tilts the card from its base (`anchor: .bottom`), the matching screen edge glows brighter with drag distance, and on release the card flies off along the throw vector while the next card springs forward from the stack. The edge glow is the only decision indicator — no stamps or badges on the photo itself.

**Supporting motion:** sessions deal their cards up from the bottom with a 70ms stagger; undo flies the card back in from the side it left; screens push in from the trailing edge (crossfade under Reduce Motion); home sections cascade in with a 50ms stagger; dock icons kick to 0.78 scale on press; the splash (black wordmark on white) shows on every cold launch — auto-dissolving after 1.4s for returning users — over a white system launch screen (StageColor).

## The swipe screen (canonical layout)

1. Top bar: glass `✕` pill (confirms if marks exist) · 4pt progress bar (cream on hairline) · glass "Keep all" pill.
2. Counter row: toss count left (`toss`, mono), kept count right (`keep`, mono).
3. Card stack: top card + 2 peeking behind (scale 0.94/0.88, lift −16/−30, opacity 0.7/0.4).
4. "Toss N" capsule appears above the dock only when something is marked.
5. Glass action dock: trash (`toss`) · undo · star (`cream`) · checkmark (`keep`). Dock buttons drive the *same* code path as gestures (`throwCard`).

No filmstrip, no "N / M" pill — the stack is the queue, the bar is the progress.

## Voice

**Native Apple vocabulary** (July 2026: "toss" retired). Delete means delete; buttons are Title Case; messages are sentence case; no exclamation marks, no cutesy lines.

- Buttons: **"Delete 12"**, **"Keep All"**, **"Delete Rest"**, **"Start"**
- End states: **"Album Reviewed"**, **"Burst Complete"**, **"No Duplicates"**
- Alert: **"Delete 12 Photos?"** — Delete / Keep All / Cancel
- Celebration: **"23 Deleted"** / "148 MB freed"
- Failure: **"Couldn't delete. Photos unchanged."** (never silent)
- The freed-space number is only shown once it's real.

## Adoption rules

Style all UI through `Theme` tokens — never hardcode colors, fonts, radii, or curves in views. Glass surfaces always pair `.ultraThinMaterial` with a hairline stroke. Every failure gets a toast. The asset-catalog `AccentColor` is system blue.
