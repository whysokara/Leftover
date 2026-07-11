# Leftover Design System — Headspace-inspired

## The vibe

Vibrant and friendly, Headspace-inspired: warm cream canvas (#F7F3EB), deep navy ink (#35325E), chunky SF Rounded heavy headings, white floating cards with soft shadows, capsule buttons in vibrant orange (#F47D31), and every feature color-coded with a filled SF Symbol on its own bright circular chip (`Theme.chipOrange/Blue/Purple/Pink/Teal/Yellow/Coral/Navy`). Decisions stay physical — cards tilt and get thrown, the screen edge glows the decision color, the stack advances underneath.

Personality: quiet, confident, decisive. The photos do the talking; the interface whispers.

Predecessors (see git history): "Light Table / Darkroom", then the dark "Theater" system — both retired July 2026 for the native look.

**Personality pass (July 2026):** the swipe screen and celebrations always had real motion; the list-style cleanup screens didn't. Home's cleanup list is now a **Bento grid** (varied tile sizes carry hierarchy instead of a uniform row list), Duplicates/Similar Shots show their groups as a **fanned photo stack** rather than a flat scroll, and a small procedurally-drawn mascot (`LeftoverBuddy` — circle, two eyes, one mouth curve, several expressions) appears only in empty/celebration states that had no personality before. No hand-drawn illustration anywhere — a prior "Doodle" sketchy-icon system was tried and rejected as looking cheap, so anything drawn stays clean and geometric.

## Color

**Headspace palette** (July 2026, fifth iteration). `Theme.swift` tokens: `stage`=cream #F7F3EB, `surface`=white, `ink`=navy #35325E, `dim`=#8D89A8, `cream`=orange #F47D31 (accent — name historical), `keep`=teal #3EB49E, `toss`=coral #F25C54, plus the eight `chip*` colors.

Glass: `.ultraThinMaterial` + 1px `hairline` stroke, for the action dock, top-bar pills, and toasts.

**Light enforcement:** `UIUserInterfaceStyle = Light` in Info.plist and `.preferredColorScheme(.light)` on the root view. Tokens are system semantics, so dark support later is a two-line change.

## Typography

No bundled fonts. **SF Rounded heavy/bold** for wordmark/display/titles/buttons via `Theme` tokens; SF Pro for body and details.

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

**Supporting motion:** sessions deal their cards up from the bottom with a 70ms stagger; undo flies the card back in from the side it left; screens push in from the trailing edge (crossfade under Reduce Motion); home sections cascade in with a 50ms stagger; dock icons kick to 0.78 scale on press; the splash (ink wordmark on paper) shows on every cold launch — auto-dissolving after 2.4s for returning users — over a paper launch screen (StageColor).

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

Style all UI through `Theme` tokens — never hardcode colors, fonts, radii, or curves in views. Glass surfaces always pair `.ultraThinMaterial` with a hairline stroke. Every failure gets a toast. The asset-catalog `AccentColor` is orange #F47D31. Feature icons are filled SF Symbols, white on their chip color.
