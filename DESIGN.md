# Leftover Design System — "Theater"

## The vibe

A private screening room for your own past. The app is **dark-only**: photos glow on a near-black warm stage, chrome floats above them as frosted glass, and the only light besides the photos is cream. Decisions stay physical — cards get thrown, stamps ink on, the stack advances underneath.

Personality: quiet, confident, decisive. The photos do the talking; the interface whispers.

Predecessor: the light/dark "Light Table / Darkroom" system (see git history). Retired July 2026 in favor of a single committed dark look.

## Color

Warm-biased neutrals — never pure gray, never pure black. One accent (cream). Keep/Toss are semantic and **never** decorative.

| Token | Value | Role |
|---|---|---|
| `stage` | `#0D0B09` | Background |
| `surface` | `#1A1712` | Cards, tiles |
| `raised` | `#26221B` | Elevated surfaces |
| `ink` | `#F5EFE4` | Primary text |
| `dim` | `#9C9285` | Secondary text |
| `cream` | `#F2E9D8` | Accent: CTAs, progress fill, favorite star, glow |
| `creamInk` | `#171310` | Text on cream buttons |
| `keep` | `#82C795` | Right-swipe stamp, keep counter, edge glow |
| `toss` | `#E56A55` | Left-swipe stamp, toss counter, delete buttons |
| `hairline` | `#2E2921` | Borders, progress track |

Glass: `.ultraThinMaterial` (always renders dark because the app forces dark appearance) + 1px `hairline` stroke, for the action dock, top-bar pills, and toasts.

**Dark-only enforcement:** `UIUserInterfaceStyle = Dark` in Info.plist and `.preferredColorScheme(.dark)` on the root view. Tokens are single-value — no light variants exist.

## Typography

No bundled fonts. SF Pro Rounded at heavy weights carries the personality, SF Pro reads, SF Mono counts.

| Role | Face | Spec |
|---|---|---|
| Display (wordmark, celebrations) | SF Rounded | Black, 30–48pt |
| Title | SF Rounded | Heavy, 22pt |
| Body | SF Pro | Regular, 17pt |
| Buttons | SF Rounded | Bold, 16pt |
| Eyebrows ("TODAY'S MEMORY BURST") | SF Mono | Bold, 12pt, +2 tracking, uppercase |
| Counters | SF Mono | Bold 15pt, tabular — digits never jitter |

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

**The signature moment** is now a sequence: drag tilts the card from its base (`anchor: .bottom`), the KEEP/TOSS stamp inks in with drag distance, the matching screen edge glows, and on release the card flies off along the throw vector while the next card springs forward from the stack.

## The swipe screen (canonical layout)

1. Top bar: glass `✕` pill (confirms if marks exist) · 4pt progress bar (cream on hairline) · glass "Keep all" pill.
2. Counter row: toss count left (`toss`, mono), kept count right (`keep`, mono).
3. Card stack: top card + 2 peeking behind (scale 0.94/0.88, lift −16/−30, opacity 0.7/0.4).
4. "Toss N" capsule appears above the dock only when something is marked.
5. Glass action dock: trash (`toss`) · undo · star (`cream`) · checkmark (`keep`). Dock buttons drive the *same* code path as gestures (`throwCard`).

No filmstrip, no "N / M" pill — the stack is the queue, the bar is the progress.

## Voice

Calm minimal. Short sentences, honest numbers, periods. No exclamation marks, no cheerleading.

- "That's the whole album!" → **"Album clear."**
- "Tossed 12 · freed 148 MB" → **"12 tossed · 148 MB freed"**
- "Today's burst is complete" → **"Done for today."** / "Come back tomorrow."
- Failure: **"Couldn't toss. Photos untouched."** (never a silent failure)
- The freed-space number is only shown once it's real.

## Adoption rules

Style all UI through `Theme` tokens — never hardcode colors, fonts, radii, or curves in views. Glass surfaces always pair `.ultraThinMaterial` with a hairline stroke. Every failure gets a toast. The asset-catalog `AccentColor` is cream.
