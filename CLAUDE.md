# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Leftover** is a minimalist iOS photo gallery cleaner built with SwiftUI. Users swipe left to mark photos for deletion and right to keep them. Local-only — no cloud sync, no login, no data collection. Swift 5.5+, SwiftUI, PhotoKit, iOS 16+, Xcode 15+.

## Building & Running

```bash
open Leftover.xcodeproj
```

Build and run from Xcode (`Cmd+R`). There are no automated tests, no linter, and no package dependencies — the whole app is three Swift files.

- `xcodebuild` from the terminal fails on this machine unless the active developer directory points at Xcode (currently it points at CommandLineTools). Fix with `sudo xcode-select -s /Applications/Xcode.app` if CLI builds are needed; otherwise just build in Xcode.
- **Photo deletion requires a real device.** The simulator sandboxes photo library writes, so delete operations silently fail there. Test the golden path on an iPhone: Splash → Album Picker → swipe a few → Delete Now → verify in Camera Roll.
- Photo library permission is cached per bundle ID; if permissions get stuck, uninstall and reinstall the app. Clean build (`Cmd+Shift+K`) after changing Info.plist keys.

## Architecture

### The real structure (read this before trusting file names)

- **ContentView.swift (~785 lines)** is the entire app: all views, all state, and **all live PhotoKit operations** (`loadPhotos`, `fetchAlbums`, `deleteMarkedPhotos`, `toggleFavorite`). This centralization is intentional for a small project.
- **PhotoManager.swift is dead code.** It looks like the PhotoKit layer, but ContentView never instantiates it — it's a leftover from an earlier design. Don't add features there expecting them to run; either wire it up deliberately or keep working in ContentView.
- **LeftoverApp.swift** is a bare `WindowGroup { ContentView() }`.

### Screen flow

One `ZStack` in `ContentView.body` switches between computed-property views based on `@State` flags, in priority order:

1. `splashScreenView` (`showSplashScreen`) — welcome screen with pulse animation
2. `albumPickerView` (`showAlbumPicker`) — requests photo permission in `.onAppear`, then shows a 2-column `LazyVGrid` of albums plus an "All Photos" tile
3. `swipeCard` — shown while `currentIndex < photoAssets.count`; the main review UI
4. `deleteConfirmation` (`showDeleteButton`) — end-of-album batch-delete prompt

Overlays for `isDeleting` spinner and `showSnackbar` toast sit on top of whichever screen is active.

To add a screen, follow the same pattern: a computed `var myView: some View`, a `@State` visibility flag, a branch in the `ZStack`, and `withAnimation { flag = true }` to transition.

### Swipe / delete model

- Swiping **left** appends the asset to `toBeDeleted` and advances `currentIndex`; swiping **right** just advances. Nothing touches the library during swiping.
- Actual deletion happens only in `deleteMarkedPhotos()` via a **single batch** `PHPhotoLibrary.performChanges` (never delete one-by-one), triggered by the "Delete N Now" button or the end-of-album confirmation.
- **Undo** decrements `currentIndex` and removes the asset from `toBeDeleted` / `favoritedAssets` — it works because nothing was really deleted yet.
- **Double-tap** toggles the PHAsset's favorite flag (with heart animation) and advances to the next photo.

### Image loading

Full-size images are *not* preloaded into an array. `PhotoAssetImage` (800×800) and `PhotoThumbnailView` (80×80) are small views that each fetch their own image from `PHImageManager` in `.onAppear`, keyed by `.id(asset.localIdentifier)` so SwiftUI refetches when the asset changes. Album thumbnails are fetched at 300×300 in `fetchAlbums()`.

### Conventions

- All UI updates from PhotoKit completion handlers must hop to `DispatchQueue.main.async`.
- `withAnimation { ... }` for one-off animated state changes; `.animation(_:value:)` modifiers for continuous effects (pulse, heart, shake).
- `currentAsset` must be kept in sync with `photoAssets[currentIndex]` whenever the index changes (there's an `.onChange(of: currentIndex)` for this, but gesture handlers also set it directly).

## Known quirks

- Info.plist declares `NSPhotoLibraryUsageDescription` **twice** (duplicate key) alongside `NSPhotoLibraryAddUsageDescription`. Both usage-description keys are required for photo access; clean up the duplicate if editing that file.
- `favoritePhoto(_:)` in ContentView is a near-duplicate of `toggleFavorite(_:)` and appears unused from the UI.

## Future features (from README)

Batch review mode; auto-suggestions for blurry/duplicate/screenshot photos; dark mode; onboarding; settings screen for custom swipe actions; video support. Follow the established pattern: state + computed view in ContentView, PhotoKit work off the main thread.
