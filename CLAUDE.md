# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Leftover** is a minimalist iOS photo gallery cleaner built with SwiftUI. Users swipe left to mark photos for deletion and right to keep them. Local-only — no cloud sync, no login, no data collection. Swift 5.5+, SwiftUI, PhotoKit, iOS 16+, Xcode 15+.

## Building & Running

```bash
open Leftover.xcodeproj
```

Build and run from Xcode (`Cmd+R`). There are no automated tests, no linter, and no package dependencies. Sources: `ContentView.swift` (app shell + swipe engine + PhotoKit), `HomeView.swift`, `SettingsView.swift`, `DuplicatesView.swift` (GroupReviewView, shared by Duplicates and Similar Shots), `LargeVideosView.swift`, `DuplicateFinder.swift` (LibraryScanner: one pass computes dHash + Laplacian sharpness, cached in Application Support; products are duplicate groups, similar-shot groups, and blurry assets), `Stats.swift`, `NotificationManager.swift`, `Theme.swift`, `LeftoverApp.swift`. The blur threshold (`LibraryScanner.blurThreshold`) is deliberately conservative — tune it on a real device, and note flat/dark images naturally score low.

- `xcodebuild` from the terminal fails on this machine unless the active developer directory points at Xcode (currently it points at CommandLineTools). Fix with `sudo xcode-select -s /Applications/Xcode.app` if CLI builds are needed; otherwise just build in Xcode.
- **Photo deletion requires a real device.** The simulator sandboxes photo library writes, so delete operations silently fail there. Test the golden path on an iPhone: Splash → Album Picker → swipe a few → Delete Now → verify in Camera Roll.
- Photo library permission is cached per bundle ID; if permissions get stuck, uninstall and reinstall the app. Clean build (`Cmd+Shift+K`) after changing Info.plist keys.

## Architecture

### The real structure

- **ContentView.swift** is the entire app: all views, all state, and **all live PhotoKit operations** (`loadPhotos`, `fetchAlbums`, `deleteMarkedPhotos`, `toggleFavorite`). This centralization is intentional for a small project.
- **LeftoverApp.swift** is a bare `WindowGroup { ContentView() }`.

### Screen flow

One `ZStack` in `ContentView.body` switches between computed-property views based on `@State` flags, in priority order:

1. `splashScreenView` (`showSplashScreen`) — welcome screen with pulse animation
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
- **Double-tap** toggles the PHAsset's favorite flag (with heart animation). Because `PHAsset` objects are immutable snapshots, `toggleFavorite` re-fetches the asset by `localIdentifier` afterward and swaps it into `photoAssets`/`currentAsset` — keep this pattern for any other `performChanges` that mutates asset properties.

### Image loading

Full-size images are *not* preloaded into an array. `PhotoAssetImage` (800×800) and `PhotoThumbnailView` (80×80) are small views that each fetch their own image from `PHImageManager` in `.onAppear`, keyed by `.id(asset.localIdentifier)` so SwiftUI refetches when the asset changes. Album thumbnails are fetched at 300×300 in `fetchAlbums()`.

### Conventions

- All UI updates from PhotoKit completion handlers must hop to `DispatchQueue.main.async`. Library scans (`loadPhotos`, `fetchAlbums`) run on `DispatchQueue.global(qos: .userInitiated)` and publish results on main.
- `withAnimation { ... }` for one-off animated state changes; `.animation(_:value:)` modifiers for continuous effects (pulse, heart, shake).
- `currentAsset` must be kept in sync with `photoAssets[currentIndex]` whenever the index changes (there's an `.onChange(of: currentIndex)` for this, but gesture handlers also set it directly).
- Don't cap Dynamic Type with `.dynamicTypeSize(...)` ranges — accessibility sizes must work.

## Design system

The identity is **dark and minimal, reference-driven** (July 2026, sixth iteration: Light Table → Theater → native-system → Doodle → Headspace → this): near-black canvas, off-white ink, plain SF Pro (no rounded/chunky display face), capsule buttons, and vibrant per-feature chip colors (`Theme.chip*`) retuned for contrast against the dark canvas. Feature icons use `IconBadge` (`Theme.swift`) — a thin, non-`.fill` SF Symbol in its accent color, on a soft ~16%-opacity tint of that same color — replacing the old bold-white-icon-on-solid-chip look everywhere except the swipe screen's action dock and inline photo-overlay status badges (favorite star, keeper/marked badges in Duplicates/Similar Shots), which stay bold/filled since they're status indicators over unpredictable photo content, not feature-identity chips. `Theme.swift` owns every token (`cream`=orange accent — name is historical). Copy is Apple-standard: "Delete 12", "Keep All", "Album Reviewed". Type: plain SF Pro via `Theme.wordmark`/`display`/`title`/`button` (Bold/Semibold, no `.rounded` design); row details are bare one-line values like Settings. Named springs: (`Theme.flick` / `.settle` / `.pop` / `.throwOut` / `.stackAdvance`), `Haptics` helpers, and three button styles. Drag feedback on the swipe card is the edge glow only (no KEEP/TOSS stamps — removed by request). Dark appearance is forced via `UIUserInterfaceStyle = Dark` in Info.plist plus `.preferredColorScheme(.dark)` on the root — dark-only, not adaptive. The splash wordmark is ink-on-stage — deliberately minimal (no icons/mnemonics), auto-dissolving after 2.4s for returning users. Settings' About section has Privacy Policy (sheet, `PrivacyPolicyView`) and Developer (links to Kara's `@whysokara` on X) rows. Glass chrome is `.ultraThinMaterial` + hairline stroke. The swipe screen is a card stack (top card + 2 peeking) with a glass action dock whose buttons share the gesture code path (`throwCard`); there is no filmstrip. Shadows meant to lift content off the app's own (now dark) background use a light glow instead of a dark drop-shadow, which would be invisible against near-black (see `DeleteBlastView`'s falling tiles). `DESIGN.md` is the spec; `AUDIT.md` records the July 2026 audit. Style all new UI through `Theme` tokens — never hardcode colors, fonts, radii, or animation curves in views. The asset-catalog `AccentColor` is orange #FF9142, and `StageColor` (launch screen) matches `Theme.stage` (#121214).

**Personality pass (July 2026, fifth iteration — since superseded):** added `LeftoverBuddy.swift` — a tiny procedurally-drawn mascot (circle + two eyes + a `Shape`-based mouth, `BuddyExpression`: happy/relieved/sleepy/surprised/wink), used only in empty/celebration states that had zero personality before (never replaces existing feature iconography, and deliberately not hand-drawn/sketchy — an earlier "Doodle" line-art redesign was rejected for looking cheap) — **this still stands**. Duplicates/Similar Shots group cards became **fanned photo stacks** (rotation + offset + shadow per photo, keeper largest/frontmost) instead of a flat horizontal scroll, each screen keeping its own chip-color identity (teal/pink) via `accent` — **this still stands**. `ScanProgress` became an animated ring with a breathing pulse instead of a flat system `ProgressView`, later extended to blend a real hash-pass fraction with a real grouping-pass fraction (`LibraryScanner.groupingProgress`) instead of pinning at 100% while duplicate-grouping still runs — **still stands**. The staggered on-load reveal (`cascadeIn(_:slot:)`) is a shared `View` extension in `Theme.swift` — **still stands**. Home's layout has churned the most: Bento grid (fifth iteration) → flat equal-weight rows (early sixth) → the current **Cover Flow carousel** — one square photo-faced card per category (Memory Burst, Duplicates, Similar Shots, Screenshots, Blurry, Large Videos, Albums), centered card forward, neighbors 3D-tilted with a glossy reflection, name/count readout underneath, modeled on the iPod-era landscape Music app at Kara's request. It's a custom ZStack + drag in `HomeView.swift` (`selectedIndex`/`dragFraction`, `rotation3DEffect`, momentum snapping via `predictedEndTranslation`) since iOS 17 scroll-transition APIs are unavailable at the iOS 16 target. All 7 cards always show — empty categories dim instead of hiding. Card art comes from per-category preview `PHAsset`s passed from ContentView (Memory Burst's is a random pick per `loadHomeData()` so it varies between opens). `SortRow` was deleted with the row list; `IconBadge` (Theme.swift) survives as the card badge and Settings row icon.

## Future features (from README / ROADMAP.md)

Leftover Plus (StoreKit 2 paywall; free tier keeps classic album swiping), share footer, home-screen widget (Stats already mirrors into an App Group), batch review mode, blur detection. Follow the established pattern: state + computed view in ContentView, PhotoKit work off the main thread.

## PhotoKit gotcha (July 2026)

`PHImageRequestOptions.deliveryMode = .fastFormat` returns nil with `PHPhotosErrorDomain 3303` for assets without materialized small thumbnails (seen on the iOS 26 simulator). Use `.opportunistic` for async thumbnails and `.highQualityFormat` for synchronous fetches — never `.fastFormat` alone.
