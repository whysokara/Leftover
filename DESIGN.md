# Leftover Design System — Dark, minimal tool list

## The vibe

Near-black canvas, plain SF Pro type (no rounded/chunky display face), and thin outline SF Symbols sitting on softly tinted per-feature accent badges (`Theme.chipOrange/Blue/Purple/Pink/Teal/Yellow/Coral/Navy`) rather than bold white icons on solid saturated chips. Home's navigation is a **Cover Flow carousel** (July 2026, after the iPod-era Music app): one square card per category — Memory Burst, Duplicates, Similar Shots, Screenshots, Blurry, Large Videos, Albums — each faced with a real photo from that category as card art (icon badge + name + count on a scrim), the centered card facing forward, neighbors tilted away in 3D with a glossy floor reflection, and the centered card's name/count echoed underneath like the old song-title readout. All seven cards are always present; empty categories dim rather than disappear, so the carousel never changes length. Tap the front card to open it, tap a side card to bring it forward, flick to move — snapping follows the flick's projected momentum. Implementation is a custom ZStack + drag (`selectedIndex` + `dragFraction`, `rotation3DEffect`, `Theme.settle` snapping) because the iOS 17 scroll-transition APIs are unavailable at the iOS 16 target; under Reduce Motion the 3D tilt flattens out but the carousel still works. Decisions on the swipe screen stay physical — cards tilt and get thrown, the screen edge glows the decision color, the stack advances underneath.

Personality: quiet, confident, understated. The photos do the talking; the interface recedes further than it ever has.

Predecessors (see git history): "Light Table / Darkroom", a dark "Theater" system, then a "Headspace" light system with a Bento-grid home and a "personality pass" (mascot, fanned photo stacks, bigger type) — all retired July 2026 for this reference-driven dark redesign, the sixth iteration. The mascot (`LeftoverBuddy`), fanned photo stacks, and cascade-in motion from the Headspace era all carry forward unchanged — only the palette, type, icon treatment, and Home's layout changed this time.

## Color

**Dark palette** (July 2026, sixth iteration). `Theme.swift` tokens: `stage`=near-black #121214, `surface`=#1C1C1F (raised cards/rows), `ink`=off-white #F2F1F5, `dim`=#9A9AA2, `cream`=orange #FF9142 (accent — name historical), `keep`=teal #4FD1B9, `toss`=coral #FF6F68, plus the eight `chip*` colors — same hues as the light system, brightened for legibility against near-black.

Icon badges: a soft tint of the feature's accent color (~16% opacity) behind a thin-weight, non-`.fill` SF Symbol in that same accent color — see `IconBadge` in `Theme.swift`. This replaced the old "bold filled icon, white, on a fully saturated chip" look everywhere except the swipe screen's action dock and inline photo-overlay badges (favorite star, keeper/marked badges), which keep their bold/filled treatment since they're status indicators over unpredictable photo content, not feature-identity chips.

Glass: `.ultraThinMaterial` + 1px `hairline` stroke, for the action dock, top-bar pills, and toasts.

**Dark enforcement:** `UIUserInterfaceStyle = Dark` in Info.plist and `.preferredColorScheme(.dark)` on the root view — dark-only, not adaptive, the same single-mode enforcement model the app has always used (just flipped). Tokens are system semantics, so light support later is a two-line change.

## Typography

No bundled fonts, no rounded design. **Plain SF Pro** for everything via `Theme` tokens.

| Role | Spec |
|---|---|
| Wordmark / screen titles | SF Pro Bold, 34pt (`Theme.wordmark`/`Theme.display` — matches system large titles) |
| Display (celebrations) | SF Pro Bold, 30pt (`Theme.display`) |
| Section titles | SF Pro Semibold, 22pt (`Theme.title`) |
| Row titles / body | `.body` medium / regular |
| Buttons | SF Pro Semibold, 17pt (`Theme.button`) |
| Row details, counters | `.footnote` / `.subheadline` + `.monospacedDigit()` — bare values, one line, like Settings |

Counters animate with `.contentTransition(.numericText())` — digits roll, never jitter.

**Dynamic Type:** full range including accessibility sizes. Never cap with `.dynamicTypeSize(...)`.

## Shape & space

- Photo cards: radius **28**, continuous · Buttons: **16** · Tiles: **16** · Docks/pills/toasts: **capsule**
- Spacing snaps to a 4pt grid.
- Tap targets ≥ 44pt (dock buttons are 60×52).
- Shadows: dark drop-shadows disappear against the near-black stage, so anything meant to lift *off the app's own background* (not off a photo) uses a light glow instead — e.g. the delete celebration's falling tiles use `white.opacity(0.12)`. Shadows that provide contrast against unpredictable photo content (favorite star, keeper/marked badges) stay dark, since that's still the photo's brightness, not the app canvas.

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

Style all UI through `Theme` tokens — never hardcode colors, fonts, radii, or curves in views. Glass surfaces always pair `.ultraThinMaterial` with a hairline stroke. Every failure gets a toast. The asset-catalog `AccentColor` is orange #FF9142; the `StageColor` launch-screen color matches `Theme.stage` (#121214) so the launch screen doesn't flash a different tone before the app UI appears. Feature icons use `IconBadge` — thin outline SF Symbols in their accent color, on a soft tint of that same color — except the swipe screen's action dock and inline photo-overlay status badges, which stay bold/filled by design (see Color section above).
