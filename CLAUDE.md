# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Leftover** is a minimalist iOS photo gallery cleaner built with SwiftUI. Users swipe left to mark photos for deletion and right to keep them. Local-only — no cloud sync, no login, no data collection. Swift 5.5+, SwiftUI, PhotoKit, iOS 16+, Xcode 15+.

## Building & Running

```bash
open Leftover.xcodeproj
```

Build and run from Xcode (`Cmd+R`). There are no automated tests, no linter, and no package dependencies — the whole app is three Swift files (`ContentView.swift`, `Theme.swift`, `LeftoverApp.swift`).

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

The "Light Table / Darkroom" identity is **implemented** in `Theme.swift`: color tokens (warm neutrals, safelight-amber accent, KEEP/TOSS semantic colors), SF Rounded display type, named springs (`Theme.flick` / `.settle` / `.pop`), `Haptics` helpers, three button styles (`PrimaryButtonStyle`, `TossButtonStyle`, `QuietButtonStyle`), and the `DecisionStamp` swipe overlay. `DESIGN.md` is the spec; `AUDIT.md` records the July 2026 audit. Style all new UI through `Theme` tokens — never hardcode colors, fonts, radii, or animation curves in views. The asset-catalog `AccentColor` is set to safelight amber (light/dark variants).

## Future features (from README)

Batch review mode; auto-suggestions for blurry/duplicate/screenshot photos; dark mode; onboarding; settings screen for custom swipe actions; video support. Follow the established pattern: state + computed view in ContentView, PhotoKit work off the main thread.
