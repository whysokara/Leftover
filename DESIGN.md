# Leftover Design System — Dark neon, Cover Flow

The seventh-generation design (July 2026): a near-black stage, one glowing
outline-card brand mark that runs from the app icon into the app, Cover Flow
navigation faced with the user's own photos, and physical, spring-driven
decisions everywhere. Personality: quiet, confident, understated — the photos
do the talking; the interface recedes.

Predecessors (see git history): "Light Table / Darkroom" → dark "Theater" →
native-system → "Doodle" (rejected: cheap-looking line art) → light
"Headspace" (cream canvas, Bento grid, personality pass) → the first dark
minimal pass → this. Carried forward from earlier eras: the `LeftoverBuddy`
mascot, the cascade-in entrance, the spring/haptic language, and the swipe
screen's physics.

## The brand mark

The app icon is a single tilted rounded-card **outline** in a neon gradient
stroke (orange → pink → purple) with a soft glow and one trailing echo — a
card mid-swipe, drawn as one line, on the dark stage. `NeonCardMark`
(`Theme.swift`) renders the same mark in SwiftUI and is the only place it
should come from. It appears exactly three ways:

- **Splash** — headlining above the wordmark (icon → app continuity).
- **Session complete, nothing marked** — signs off a clean finish.
- **Scan ring** — the progress arc sweeps the same gradient
  (`AngularGradient`, chipOrange → chipPink → chipPurple).

It is always decorative (`accessibilityHidden`), always paired with text that
carries the meaning. Don't scatter it further; scarcity is what keeps it a
mark.

## Color

`Theme.swift` tokens — never hardcode:

| Token | Value | Role |
|---|---|---|
| `stage` | #121214 | canvas (matches `StageColor` launch asset) |
| `surface` | #1C1C1F | raised cards, rows, chips |
| `raised` | #242428 | secondary fill, dimmed card faces |
| `ink` | #F2F1F5 | primary text |
| `dim` | #9A9AA2 | secondary text (≈6.4:1 on stage) |
| `onChip` | #121214 | **text/glyphs on any bright chip fill** |
| `cream` | #FF9142 | orange accent (name historical) |
| `keep` / `toss` | #4FD1B9 / #FF6F68 | decision semantics |
| `hairline` | white 8% | dividers |
| `chipOrange/Blue/Purple/Pink/Teal/Yellow/Coral/Navy` | — | per-feature identity |

**The onChip rule:** white on these mid-tone accents measures ≈1.5–2.2:1 and
fails WCAG AA; `onChip` clears 9:1 on every chip. Any text or icon-only
control sitting on a solid chip fill (action dock, solid card faces) uses
`onChip`. White text is reserved for photo-backed surfaces behind a dark
scrim.

Feature identity: Duplicates=teal, Similar Shots=pink, Screenshots=blue,
Time-related/Burst=orange, Blurry=yellow, Large Videos=coral, Albums=navy.
Group-review screens carry their chip color as an
`accent` (card borders, keeper badges, empty-state buddy).

Icon badges (`IconBadge`, Theme.swift): thin non-`.fill` SF Symbol in its
accent color on a ~16% tint of the same color — used in Settings rows.
Exceptions that stay bold/filled: the action dock (solid chips, `onChip`
glyphs) and status badges over photos (favorite star, keeper/marked badges —
white-backed circles so the cutout glyphs don't read as holes).

Glass: `.ultraThinMaterial` + 1px `hairline` stroke — toasts, "Keep all"
pill, the collage-face frost.

**Dark enforcement:** `UIUserInterfaceStyle = Dark` + `.preferredColorScheme(.dark)`
on the root. Dark-only, not adaptive. Asset-catalog `AccentColor` is #FF9142.

## Typography

Plain SF Pro via **Dynamic Type text styles only** — `Theme` tokens map to
scaling styles, never fixed point sizes.

| Role | Spec |
|---|---|
| Wordmark / display | `.largeTitle` bold (`Theme.wordmark`/`display(≥32)`); `.title` bold below 32 |
| Section titles | `.title2` semibold (`Theme.title`) |
| Buttons | `.body` semibold (`Theme.button`) |
| Row titles | `.body` / `.subheadline` medium–semibold |
| Details, counters, chips | `.footnote`/`.caption` + `.monospacedDigit()` — bare values, one line |

Counters animate with `.contentTransition(.numericText())`. The Home wordmark
is `lineLimit(1)` + `minimumScaleFactor(0.7)` — it compresses, never wraps.
Never cap with `.dynamicTypeSize(...)`.

## Onboarding

Two steps (`OnboardingView`), value-first then permission — the flow's
one job is to get a first-timer to their first real swipe fast.
First launch only (splash Start → onboarding → first cleanup),
replayable from Settings → About → "How Leftover Works". Skippable on
step 1; forward-only; two progress dots; push transitions; no
`NeonCardMark` (the mark keeps its three placements). The top bar
carries the plain-serif `Leftover` wordmark on the leading edge (brand
continuity from the splash; also anchors "Skip" so it isn't an orphan).

1. **Swipe to Decide** — taught by doing: two chip-gradient practice
   cards with the real swipe physics in miniature (drag, bottom-anchored
   rotation, edge glows, throw + haptics). If the user sits idle the top
   card self-nudges toward the delete edge (twice, then stops; off under
   Reduce Motion). A mini trash/check dock drives the same code path (the
   tap-first / VoiceOver route). Completing both throws lands a `keep`
   check-mark micro-win ("That's the whole app — nothing's gone until you
   confirm.") before auto-advancing.
2. **Let's find your clutter** — the permission ask with the trust story
   folded in where the finger hovers, not a screen earlier. Benefit-first
   copy ("Full access lets Leftover surface duplicates, screenshots, and
   blurry shots — found and cleared right here, never uploaded.") over an
   adaptive button (`notDetermined` → "Allow Photo Access" fires the system
   dialog; granted/limited replay → "Done"; denied → "Open Settings" +
   quiet "Done"), with a three-badge trust strip under it (🔒 on device ·
   ☁︎⃠ never uploaded · ⏱ 30-day undo — the old standalone trust step,
   condensed). Home's own permission request waits, because Home can't
   appear while onboarding is up.

**The handoff.** On a genuine first run (not a Settings replay) that ends
with access granted, finishing drops the user straight into their first
Memory Burst cleanup — their first *action* is a real swipe on real
photos ending in a real "X freed", not the Home screen. Armed on finish
(`pendingFirstCleanup`), fired by `loadHomeData` once the burst assets are
in hand; an empty library falls back to Home.

## Home (canonical layout)

1. **Header** — wordmark left; bare freed-space stat (only when non-zero),
   a trophy count chip (only once a trophy's earned), the health score as a
   tiny linear bar + number, then a 36pt gear circle in a 44pt hit area — no
   capsule chrome. A limited-access banner (+ Manage) appears under the
   header when photo access is `.limited`.
2. **Cover Flow carousel** — the navigation. One square card per category
   (Memory Burst, Duplicates, Similar Shots, Screenshots, Blurry, Large
   Videos, Albums), seated near the vertical middle of the screen.
3. **Recent** — a 3-column `LazyVGrid` of the entire library, newest first,
   square cells, radius 12, 4pt gutters; tapping a cell starts a swipe
   session at that photo. Sized so about a row and a half shows above the
   fold.

### The carousel

- **Geometry:** card 210pt (front scales to 1.06, sides 0.88), ±1 neighbor
  at 216pt with a guaranteed gap (no two cards ever touch), further cards at
  145pt intervals (offscreen on phones), 28° y-axis tilt, perspective 0.55.
- **Endless:** wrapped-distance math loops the deck both directions; cards
  fade out before the wrap distance so the side-swap never shows.
- **Adaptive:** categories whose detail resolves to "None" drop out;
  pre-scan "Scan" and loading "…" states stay; Albums always stays; Memory
  Burst dims (raised-gray face) when done today. Selection resets to the
  front when the card set changes.
- **Faces:** a blurred 2×2 collage of the category's four newest assets
  (`CardPreviews`), frosted with `.ultraThinMaterial` + black 0.42 scrim
  (0.55 dimmed), white title/count bottom-left, soft white ghost glyph
  bleeding off the top-right. Fewer than four assets → one full-bleed asset;
  none → solid chip face with `onChip` glyph and a diagonal light wash.
  Labels render only on the front card (side slivers would overlap).
- **Reflection:** each card's face flipped, cropped to 80pt, masked to ~35%
  fading to clear — the glossy floor.
- **Interaction:** flick with momentum snapping (capped at 4 cards/flick,
  light haptic on landing), tap front to open, tap a side card to bring it
  forward. The ghost glyph parallaxes against the drag and breathes on the
  front card.
- **Implementation:** custom ZStack + drag (`selectedIndex`/`dragFraction`,
  `rotation3DEffect`) — iOS 17 scroll-transition APIs are unavailable at the
  iOS 16 target. Under Reduce Motion the tilt flattens and
  parallax/breathing stop; the carousel still works.

## The swipe screen (canonical layout)

1. Top bar: `BackButton` — a back chevron on a soft `surface` circle,
   36pt visual / 44pt hit area, matching Home's gear (confirms if marks
   exist) · the **decision ribbon** · bare "Keep all" text (`dim`,
   footnote, 44pt hit area — no capsule; a glass pill competed with the
   photo for a secondary escape hatch).
1a. **Decision ribbon** — the screen's single progress element, and a
   record rather than a fraction: one capsule segment per photo, `toss`
   where you deleted, `keep` where you kept, `cream` (and taller) for the
   photo in hand, `hairline` for untouched. Over 24 photos it collapses to
   one bar whose filled run still splits coral/teal in proportion — the
   ribbon says *what you did* at every session length, which is what lets
   the numeric counters stay deleted.
1b. Context line (`dim`, footnote, centered): "{session name} · {n} of
   {total}" — the one place session numbers live. Memory Burst swaps the
   name for the current photo's year ("This day, 2019").
2. Photo chip under the card: calendar + "{Month Year} · {size}", plus a
   "Screenshot" chip when it applies. One object, not three — and its
   coral tint climbs with the file's weight (8 MB reads as heavy) so a
   space hog looks hot before the number is read; ordinary photos stay
   neutral so the signal keeps meaning. Size comes from the scanner's
   NSCache.

**No counter row.** It was three numbers (marked / freed / kept) restating
what the ribbon already draws and what the Delete pill already says. The
rule below — count and size exactly once per screen — applies to this
screen too: the ribbon carries *how many*, the pill carries *how much*,
the chip carries *this photo*. Anything more is the same fact twice.
3. Card stack: top card + 2 peeking (scale 0.94/0.88, lift −16/−30, opacity
   0.7/0.4). Stack height flexes up to 470pt so short screens never push the
   dock off.
4. "Delete {size}" capsule appears above the dock only when something is
   marked (size only — the counter row already has the count).
5. Action dock: a single undo button (solid navy chip, 46pt, `onChip`
   glyph) — the gestures *are* the interface, and undo is the one thing a
   gesture can't do. Delete/keep have no visible buttons; VoiceOver users
   get them as custom accessibility actions on the card, driving the same
   `throwCard` code path.

The signature moment: drag tilts the card from its base, the matching screen
edge glows with drag distance, release throws the card along its vector while
the next springs forward. The edge glow is the only decision indicator — no
stamps. Already-favorited photos show a passive star badge (display only —
in-app favoriting was tried twice and pulled both times; the write worked but
the double-tap gesture never landed reliably). Undo is multi-level, flying the
card back in from the side it left. Left-edge swipe goes back on every
full-screen list and the swipe screen (`edgeSwipeBack`, a real
`UIScreenEdgePanGestureRecognizer`).

## The delete flow (one flow, everywhere)

Count and size each appear **exactly once per screen**:

1. Screen buttons show both where nothing else does: "Delete 3 · 148 MB"
   (Duplicates/Similar/Videos). The mid-session pill shows size only.
2. Every path confirms once with the same alert: title "Delete N
   Photos?/Videos?", message "This frees {size}. They'll stay in Recently
   Deleted for 30 days, so you can still restore them from Photos.",
   destructive button just **"Delete"**.
3. End-of-session screen: up to five marked photos fanned like a discard
   pile, title, one "{n} photos · {size}" line, plain Delete, retention
   caption. Clean finishes (nothing marked) get the brand mark instead.
4. Success plays `DeleteBlastView` on every path: thumbnails swallowed by
   the spotlight, the brand mark, "{size} freed" as the headline, "{n}
   photos deleted", "In Recently Deleted for 30 days", and a glass **Share**
   pill — the system sheet with "I just freed {size} of photo clutter with
   Leftover 🧹" + the marketing link (sharing pauses the auto-dismiss; the
   only sanctioned emoji in the app, and it leaves the device, not the UI).
   Tap anywhere to skip. Failure is never silent: toast "Couldn't delete.
   Photos unchanged." with all state kept for retry.

After deleting: albums resume at the next unseen photo (mid-session) or exit
to where the user came from (end of album); burst flows into Burst Complete;
screenshots/blurry return Home.

## Group review, videos, scans

- **Duplicates/Similar:** white cards on stage with the mode's accent border
  and glow; each group is a uniform-size horizontally scrolling photo row
  (84pt), keeper first with an accent star badge — a fanned overlap was
  tried twice and hid the photos users need to judge. "Delete Rest"/"Keep
  All" per group. Marked photos dim with a coral border + trash badge.
- **Large Videos:** one white list card; 64pt thumbs with play badge and
  mono duration; date + mono size; whole row toggles marking (spring pop).
- **Scan progress:** breathing ring, brand-gradient arc, honest two-phase
  progress (hash pass = first half, match-finding = second half, "Finding
  matches…" label) — never a frozen 100%.

## Health & trophies (the retention layer)

All local, all honest — nothing invented, no points/currency, no servers.

- **Library Health Score** (`HealthScore`, Gamification.swift): 0–100,
  computed from real scanner output — capped, ratio-based penalties
  (duplicates 30 · stale screenshots 25 · similar 20 · blurry 15 · large
  videos 10, each scaling with sqrt of the clutter proportion so library
  size doesn't skew it). Grades A≥90 / B≥75 / C≥60 / D≥40 / E. Colors:
  ≥85 `keep`, ≥60 `chipYellow`, else `toss` — every gauge is stroked/filled
  in the score's color, **never** the brand gradient (that stays reserved).
  Provisional until the first scan. Home's header shows it as a tiny linear
  bar + number (pops on improvement); the breakdown sheet upgrades to a big
  ring gauge, where every penalty row deep-links into the screen that fixes
  it — a reason to return even after a lapse, without punishing you for
  missing a day. Like the group-review results, the sheet fills at least
  the viewport height and centers when short (a spotless library frames the
  ring instead of stranding it up top; a cluttered one scrolls from the top).
- **Trophy shelf** (`TrophyShelfView`): eleven milestones — the original six
  (100/1k/10k deleted · 1/5/10 GB freed, now an escalating rosette → medal →
  trophy icon instead of trash cans) plus one per cleanup feature (20
  duplicates/similar/blurry cleared, 50 screenshots cleared, 5 large videos
  cleared, each a `checkmark.seal.fill` in that feature's chip color) — as a
  badge grid, achieved in full chip color, locked dimmed with a lock and the
  goal stated. A trophy count chip on Home's header (once any are earned)
  and the Settings → About row both read `TrophyShelfView.badges.count`
  directly rather than a hardcoded total, so the shelf can grow without the
  count drifting out of sync. Backed by the same `milestonesShown` history
  the one-shot moments always wrote.

## The mascot

`LeftoverBuddy` — a procedurally-drawn circle face (two eyes, one mouth
curve, five expressions). Appears **only** in empty/celebration states:
group-review and video empty states (`.relieved`), empty album (`.happy`),
permission denied (`.sleepy`). Never replaces feature iconography; never
hand-drawn/sketchy. The brand mark takes the "clean finish" slot; buddy keeps
the "nothing here" slots.

## Motion & haptics

Springs, not curves. Reduce Motion is respected **everywhere**: throws become
direct commits, pushes become crossfades, cascade offsets flatten, carousel
tilt/parallax/breathing and the splash pulse all stop; haptics stay.

| Name | Spec | Used for | Haptic |
|---|---|---|---|
| Flick | `.spring(0.35, 0.8)` | small state pops, mark toggles | — |
| Settle | `.spring(0.45, 0.85)` | transitions, progress, toasts, carousel snap | — |
| Pop | `.interpolatingSpring(100, 6)` | heart, celebration glyph, health score improving | `.light` |
| ThrowOut | `.interactiveSpring(0.3, 0.72)` | card leaving screen | `.rigid` toss / `.soft` keep |
| StackAdvance | `.spring(0.4, 0.85)` | next card promoting | — |

Supporting motion: cards deal in from the bottom with a 70ms stagger;
sections cascade in at 50ms (`cascadeIn`, shared `View` extension); dock
icons kick to 0.78 on press; carousel snaps with momentum + landing haptic;
the splash wordmark pulses (gated on Reduce Motion) and auto-dissolves after
2.4s for returning users.

## Shape, space, shadows

- Cards: radius **28** continuous · buttons **16** · tiles/rows **12–18** ·
  pills/docks/toasts **capsule**.
- Spacing is one 4pt scale — `Theme.Space` (`xs 4 · sm 8 · md 12 · lg 16 ·
  xl 24 · xxl 32 · huge 48`) plus `Theme.screenMargin` (**20**, the gutter
  every full-width screen aligns to). Snap gaps and padding to the nearest
  step; keep raw literals only for structural sizes (card/ring/icon
  dimensions, offsets), never for rhythm. Single-purpose screens fill at
  least the viewport and center short content so a sparse state is framed,
  not stranded at the top (group review, Health).
- Tap targets ≥ **44pt** everywhere (gear and back button pad invisible hit
  areas around smaller visuals).
- Shadows on the dark stage are **light glows**, not dark drops (a black
  shadow vanishes on #121214): celebration tiles use white 0.12, the brand
  mark glows in its own colors, cards use a lit top-leading gradient edge
  instead of a flat hairline. Dark shadows remain only where they sit over
  unpredictable photo content.

## Voice

Native Apple vocabulary. Buttons Title Case, messages sentence case, no
exclamation marks, no cutesy lines. Count and size never repeat on one
screen.

- Buttons: **"Delete"** (in confirms), **"Delete 3 · 148 MB"** (screen
  buttons), **"Delete 148 MB"** (mid-session pill), **"Keep All"**,
  **"Delete Rest"**, **"Start"**
- End states: **"Album Reviewed"**, **"Burst Complete"**, **"No
  Duplicates"**, **"Done for Today"**
- Alerts: **"Delete 12 Photos?"** + "This frees 148 MB. They'll stay in
  Recently Deleted for 30 days…"
- Celebration: **"23 Deleted"** · "148 MB freed" · "In Recently Deleted for
  30 days"
- Failure: **"Couldn't delete. Photos unchanged."** (never silent)
- The freed-space number is only shown once it's real.

## Resilience (designed behavior, not just engineering)

- **Nobody re-judges a photo they already judged.** Two layers: an
  interrupted session is snapshotted on backgrounding and restored next
  launch ("Resumed where you left off.") — progress alone is enough, marks
  aren't required, because keeping 40 photos is work worth saving. And each
  album remembers the last photo actually decided on (`albumProgress.v1`,
  stored by identifier so it survives the album changing), so reopening it
  later starts at the next unseen photo with "Picking up where you left
  off." Finishing an album clears its mark, so the next visit starts fresh.
- A `PHPhotoLibraryChangeObserver` keeps Home honest when the library
  changes externally; active sessions are never disturbed.
- Limited photo access is a first-class state: banner + Manage on Home and
  the album picker; collages and counts compile from permitted assets only.

## Accessibility (audited July 2026)

Dynamic Type through text styles on every themed font; Reduce Motion
coverage as above; WCAG AA contrast via the onChip rule and scrimmed photo
surfaces; 44pt tap targets; VoiceOver labels/hints on every control,
decorative elements (mascot, brand mark, reflections, watermarks) hidden;
toasts posted as VoiceOver announcements; the celebration is tappable to
dismiss with a stated hint.

## Adoption rules

Style all UI through `Theme` tokens — never hardcode colors, fonts, radii,
or curves in views. New screens: state + computed view in ContentView, push
transition, `cascadeIn` entrance, `BackButton` + `edgeSwipeBack` to exit,
every failure gets a toast. Deletes go through the one delete flow above —
batch `performChanges`, confirm once, celebrate once. The brand mark comes
only from `NeonCardMark`; the icon and `StageColor`/`AccentColor` assets stay
in sync with `Theme.stage`/`Theme.cream`.
