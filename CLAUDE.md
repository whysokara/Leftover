# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Leftover** is a minimalist iOS photo gallery cleaner built with SwiftUI. Users swipe left to mark photos for deletion and right to keep them. Local-only — no cloud sync, no login, no data collection. Swift 5.5+, SwiftUI, PhotoKit, iOS 16+, Xcode 15+.

## Building & Running

```bash
open Leftover.xcodeproj
```

Build and run from Xcode (`Cmd+R`). There are no automated tests, no linter, and no package dependencies. Sources: `ContentView.swift` (app shell + swipe engine + PhotoKit), `HomeView.swift`, `SettingsView.swift`, `DuplicatesView.swift` (GroupReviewView, shared by Duplicates and Similar Shots), `LargeVideosView.swift`, `DuplicateFinder.swift` (LibraryScanner: one pass computes dHash + Laplacian sharpness, cached in Application Support as `leftover-scan.json`; products are duplicate groups, similar-shot groups, and blurry assets. Those grouped products are persisted too — `leftover-results.json`, keyed by a cheap library fingerprint (photo count + newest creationDate) — so `restoreThenRefreshIfStale()` (called once photo access is granted) reopens them instantly on relaunch instead of redoing the O(n²) grouping, and only re-scans, silently in the background via `scan(silent:)`, when the fingerprint moved. Screens gate on `isRestoring` so they don't race ahead into a scan the stored results would have answered), `Stats.swift`, `NotificationManager.swift`, `Theme.swift`, `LeftoverBuddy.swift`, `EdgeSwipeBack.swift`, `Gamification.swift` (HealthScore math + health breakdown sheet + trophy shelf; `Stats.achievedMilestones` is the shelf's data source; debug args `-LeftoverOpenHealth`/`-LeftoverOpenTrophies`), `OnboardingView.swift` (2-step first-run flow: practice swipe, then permission with the trust story folded in; replay via Settings → "How Leftover Works"; debug args `-LeftoverShowOnboarding` [practice] / `-LeftoverOnboardingStep2` [permission]. On a genuine first run — not a replay — finishing with access granted drops straight into the first Memory Burst cleanup instead of resting on Home; exercised headless via `-LeftoverFirstRunCleanup`), `LeftoverApp.swift`. The blur threshold (`LibraryScanner.blurThreshold`) is deliberately conservative — tune it on a real device, and note flat/dark images naturally score low.

- `xcodebuild` from the terminal fails on this machine unless the active developer directory points at Xcode (currently it points at CommandLineTools). Fix with `sudo xcode-select -s /Applications/Xcode.app` if CLI builds are needed; otherwise just build in Xcode.
- **Photo deletion requires a real device.** The simulator sandboxes photo library writes, so delete operations silently fail there. Test the golden path on an iPhone: Splash → Album Picker → swipe a few → Delete Now → verify in Camera Roll.
- Photo library permission is cached per bundle ID; if permissions get stuck, uninstall and reinstall the app. Clean build (`Cmd+Shift+K`) after changing Info.plist keys.

## Architecture

### The real structure

- **ContentView.swift** is the entire app: all views, all state, and **all live PhotoKit operations** (`loadPhotos`, `fetchAlbums`, `deleteMarkedPhotos`, `toggleFavorite`). This centralization is intentional for a small project.
- **LeftoverApp.swift** is a bare `WindowGroup { ContentView() }`.

### Screen flow

One `ZStack` in `ContentView.body` switches between computed-property views based on `@State` flags, in priority order:

1. `splashScreenView` (`showSplashScreen`) — welcome screen with pulse animation; first launch's Start button flows into…
0. **Resume:** two independent layers keep users from re-judging photos. `persistSessionIfNeeded`/`restoreSavedSessionIfAny` (`savedSession.v1`) snapshot an interrupted session on backgrounding and restore it next launch — triggered by *progress alone*, marks not required. Separately, `recordAlbumProgress()` stores the last photo decided on per album (`albumProgress.v1`, keyed by album localIdentifier / `"allPhotos"`, valued by asset localIdentifier so it survives album edits); `loadPhotos(resumeAlbum: true)` — used only by the album-picker entry points — resumes after it. Finishing an album clears its entry. Debug args `-LeftoverResumeSeed` (swipes 4 to create progress) / `-LeftoverResumeCheck` (opens without swiping, so the position shown is purely what resume restored).
1a. `OnboardingView` (`showOnboarding`) — the 2-step first-run flow; while it's up, `homeView` never appears, so the photo-permission request waits for the step-2 primer. On first run (not a Settings replay) a granted finish arms `pendingFirstCleanup`, which `loadHomeData` fires as `startSession(.burst)` — so the first real action is a real swipe, not the Home screen
2. `albumPickerView` (`showAlbumPicker`) — requests photo permission in `.onAppear` (`.readWrite`); shows `permissionDeniedView` (with an Open Settings button) when denied/restricted, a limited-access banner when `.limited`, otherwise a 2-column `LazyVGrid` of albums plus an "All Photos" tile
3. `ProgressView` while `isLoadingPhotos` (album contents load on a background queue)
4. `swipeCard` — shown while `currentIndex < photoAssets.count`; the main review UI
5. `deleteConfirmation` (`showDeleteButton`) — end-of-album prompt; shows a "nothing marked" done-state when `toBeDeleted` is empty
6. `emptyAlbumView` — fallthrough for an empty/emptied album, with a Back to Albums button

Overlays for `isDeleting` spinner and `showSnackbar` toast sit on top of whichever screen is active. Toasts go through the `showToast(_:)` helper (animated in, auto-dismiss after 3s).

To add a screen, follow the same pattern: a computed `var myView: some View`, a `@State` visibility flag, a branch in the `ZStack`, and `withAnimation { flag = true }` to transition.

### Swipe / delete model

- Swiping **left** appends the asset to `toBeDeleted`, adds its file size to `totalSize` (via `assetFileSize`, used for the "freed up X" toast), and advances `currentIndex`; swiping **right** just advances. Nothing touches the library during swiping.
- Actual deletion happens only in `deleteMarkedPhotos()` via a **single batch** `PHPhotoLibrary.performChanges` (never delete one-by-one), triggered by the "Delete N Now" button or the end-of-album confirmation. On failure (including the user tapping "Don't Allow" on the system dialog), all state is kept so they can retry, and a toast says so.
- **Undo** decrements `currentIndex` and removes the asset from `toBeDeleted` (refunding its size) — it works because nothing was really deleted yet.
- In-app favoriting was tried and removed twice (July 2026, then again): no double-tap gesture, no dock heart/star — already-favorited photos just show a passive `star.fill` badge on the swipe card (display-only, reflecting the Photos-app favorite). The toggle logic itself worked (a direct `PHAssetChangeRequest.isFavorite` write succeeds even on the simulator, and re-fetching by `localIdentifier` reflected it), but the double-tap-vs-drag gesture never landed reliably in the user's hands, so the whole feature was pulled. If any future feature mutates asset properties via `performChanges`, remember `PHAsset` objects are immutable snapshots: re-fetch by `localIdentifier` afterward and swap the refreshed asset into `photoAssets`/`currentAsset`.

### Image loading

Full-size images are *not* preloaded into an array. `PhotoAssetImage` (800×800) and `PhotoThumbnailView` (80×80) are small views that each fetch their own image from `PHImageManager` in `.onAppear`, keyed by `.id(asset.localIdentifier)` so SwiftUI refetches when the asset changes. Album thumbnails are fetched at 300×300 in `fetchAlbums()`.

### Conventions

- All UI updates from PhotoKit completion handlers must hop to `DispatchQueue.main.async`. Library scans (`loadPhotos`, `fetchAlbums`) run on `DispatchQueue.global(qos: .userInitiated)` and publish results on main.
- `withAnimation { ... }` for one-off animated state changes; `.animation(_:value:)` modifiers for continuous effects (pulse, heart, shake).
- `currentAsset` must be kept in sync with `photoAssets[currentIndex]` whenever the index changes (there's an `.onChange(of: currentIndex)` for this, but gesture handlers also set it directly).
- Don't cap Dynamic Type with `.dynamicTypeSize(...)` ranges — accessibility sizes must work.

## Design system

The identity is **dark and minimal, reference-driven** (July 2026, sixth iteration: Light Table → Theater → native-system → Doodle → Headspace → this): near-black canvas, off-white ink, plain SF Pro (no rounded/chunky display face), capsule buttons, and vibrant per-feature chip colors (`Theme.chip*`) retuned for contrast against the dark canvas. Feature icons use `IconBadge` (`Theme.swift`) — a thin, non-`.fill` SF Symbol in its accent color, on a soft ~16%-opacity tint of that same color — replacing the old bold-white-icon-on-solid-chip look everywhere except the swipe screen's action dock and inline photo-overlay status badges (favorite star, keeper/marked badges in Duplicates/Similar Shots), which stay bold/filled since they're status indicators over unpredictable photo content, not feature-identity chips. `Theme.swift` owns every token (`cream`=orange accent — name is historical). Copy is Apple-standard: "Delete 12", "Keep All", "Album Reviewed". Type: plain SF Pro via `Theme.wordmark`/`display`/`title`/`button` (Bold/Semibold, no `.rounded` design); row details are bare one-line values like Settings. Named springs: (`Theme.flick` / `.settle` / `.pop` / `.throwOut` / `.stackAdvance`), `Haptics` helpers, and three button styles. Drag feedback on the swipe card is the edge glow only (no KEEP/TOSS stamps — removed by request). Dark appearance is forced via `UIUserInterfaceStyle = Dark` in Info.plist plus `.preferredColorScheme(.dark)` on the root — dark-only, not adaptive. The splash shows the `NeonCardMark` brand mark (Theme.swift — the app icon's gradient outline card, also used on clean session finishes and as the scan ring's arc gradient) above the wordmark, auto-dissolving after 2.4s for returning users. Settings' About section has Privacy Policy (sheet, `PrivacyPolicyView`) and Developer (links to Kara's `@whysokara` on X) rows. Glass chrome is `.ultraThinMaterial` + hairline stroke (toasts, "Keep all" pill, collage-face frost). The swipe screen is a card stack (top card + 2 peeking, flexible height for short screens) with a single-button action dock — undo only, a solid navy chip with `Theme.onChip` glyph; delete/keep are gesture-only, exposed to VoiceOver as custom accessibility actions on the card sharing the gesture code path (`throwCard`); the back button (`BackButton`) is a back chevron on a soft `surface` circle (36pt visual / 44pt hit area, matching Home's gear); there is no filmstrip. Shadows meant to lift content off the app's own (now dark) background use a light glow instead of a dark drop-shadow, which would be invisible against near-black (see `DeleteBlastView`'s falling tiles). `DESIGN.md` is the spec; `AUDIT.md` records the July 2026 audit. Style all new UI through `Theme` tokens — never hardcode colors, fonts, radii, or animation curves in views. The asset-catalog `AccentColor` is orange #FF9142, and `StageColor` (launch screen) matches `Theme.stage` (#121214).

**Personality pass (July 2026, fifth iteration — since superseded):** added `LeftoverBuddy.swift` — a tiny procedurally-drawn mascot (circle + two eyes + a `Shape`-based mouth, `BuddyExpression`: happy/relieved/sleepy/surprised/wink), used only in empty/celebration states that had zero personality before (never replaces existing feature iconography, and deliberately not hand-drawn/sketchy — an earlier "Doodle" line-art redesign was rejected for looking cheap) — **this still stands**. Duplicates/Similar Shots group cards became **fanned photo stacks** (rotation + offset + shadow per photo, keeper largest/frontmost) instead of a flat horizontal scroll, each screen keeping its own chip-color identity (teal/pink) via `accent` — **this still stands**. `ScanProgress` became an animated ring with a breathing pulse instead of a flat system `ProgressView`, later extended to blend a real hash-pass fraction with a real grouping-pass fraction (`LibraryScanner.groupingProgress`) instead of pinning at 100% while duplicate-grouping still runs — **still stands**. The staggered on-load reveal (`cascadeIn(_:slot:)`) is a shared `View` extension in `Theme.swift` — **still stands**. Home's layout has churned the most: Bento grid (fifth iteration) → flat equal-weight rows (early sixth) → the current **Cover Flow carousel** — one square photo-faced card per category (Memory Burst, Duplicates, Similar Shots, Screenshots, Blurry, Large Videos, Albums), centered card forward, neighbors 3D-tilted with a glossy reflection, name/count readout underneath, modeled on the iPod-era landscape Music app at Kara's request. It's a custom ZStack + drag in `HomeView.swift` (`selectedIndex`/`dragFraction`, `rotation3DEffect`, momentum snapping via `predictedEndTranslation`) since iOS 17 scroll-transition APIs are unavailable at the iOS 16 target. The carousel wraps endlessly (wrapped-distance math; cards fade out before the wrap point so the side-swap never shows) and is adaptive: cards whose detail resolves to "None" are filtered out (card faces are a blurred 2×2 collage of the category's four newest assets — `CardPreviews` fed from ContentView — frosted with `.ultraThinMaterial` + black scrim so white labels stay legible, per a July 2026 PRD; empty categories fall back to a solid chip face with dark `Theme.onChip` glyphs, since white fails WCAG AA on bare mid-tone fills, and <4 assets fall back to one full-bleed asset). `selectedIndex` resets to 0 whenever the card count changes so it always names a real card. `SortRow` was deleted with the row list; `IconBadge` (Theme.swift) survives as the card badge and Settings row icon.

## Future features (from README / ROADMAP.md)

Leftover Plus (StoreKit 2 paywall; free tier keeps classic album swiping), share footer, home-screen widget (Stats already mirrors into an App Group), batch review mode, blur detection. Follow the established pattern: state + computed view in ContentView, PhotoKit work off the main thread.

## PhotoKit gotcha (July 2026)

`PHImageRequestOptions.deliveryMode = .fastFormat` returns nil with `PHPhotosErrorDomain 3303` for assets without materialized small thumbnails (seen on the iOS 26 simulator). Use `.opportunistic` for async thumbnails and `.highQualityFormat` for synchronous fetches — never `.fastFormat` alone.
