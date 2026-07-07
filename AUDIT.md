# Leftover — Full App Audit (UI + Logic)

Audited: `ContentView.swift`, `PhotoManager.swift`, `LeftoverApp.swift`, `Info.plist` — 2026-07-08.
Severity: **High** = broken feature, stuck state, or crash risk · **Medium** = wrong-but-recoverable behavior or notable UX/API debt · **Low** = hygiene.

> **Status (2026-07-08):** All findings below were fixed in the same-day fix pass, with two deliberate exceptions: the `onChange(of:perform:)` deprecation is kept (the two-parameter replacement requires iOS 17; the app targets iOS 16), and line numbers below refer to the pre-fix code. `PhotoManager.swift` was deleted outright.

---

## High

### H1. "Freed up X" always reports zero — `totalSize` is never computed
`ContentView.swift:9, 550`
`totalSize` is declared, formatted into the delete snackbar ("Deleted N photos, freed up **Zero KB**"), and reset in three places — but nothing ever adds to it. The storage-freed counter, a headline README feature, is dead.
**Repro:** delete any photos → snackbar always says "freed up Zero KB".
**Fix direction:** sum `PHAssetResource`/`asset.value(forKey:)` file sizes as assets are appended to `toBeDeleted` (or at delete time).

### H2. Permanent "Loading photos…" dead end (three repro paths)
`ContentView.swift:44–49`
The `body` fallthrough (`else { ProgressView("Loading photos...") }`) doubles as both the loading state and the empty state, with no back button. The app gets stuck there whenever `photoAssets` is empty and `showDeleteButton` is false:
1. Tap "All Photos" when the library is empty (empty user albums are filtered out of the grid, but All Photos is not).
2. Swipe-delete the last remaining photos → `deleteMarkedPhotos` reloads the now-empty album (`ContentView.swift:560`).
3. Finish swiping, tap "Delete Now", then tap **"Don't Allow"** on the system's own delete-confirmation dialog → the failure branch sets `showDeleteButton = false` (`ContentView.swift:564`) with `currentIndex` already past the end → spinner forever. This one any user can hit by simply changing their mind.
**Fix direction:** a real empty state with a "Back to Albums" button; on delete failure, keep `showDeleteButton = true`.

### H3. `fetchAlbums()` mutates `@State` off the main thread and does synchronous I/O
`ContentView.swift:194–200, 603–660`
`PHPhotoLibrary.requestAuthorization`'s callback arrives on an arbitrary thread; `fetchAlbums()` runs right there and assigns `sortedAlbums`, `allPhotosCount`, `allPhotosThumbnail` — off-main `@State` mutation (undefined behavior; Xcode purple warnings; crash risk). Worse, it issues a **synchronous** `requestImage` per album with `isNetworkAccessAllowed = true` (`ContentView.swift:625–626`), so one iCloud-offloaded thumbnail can block the whole scan for seconds. It also re-runs the full scan every time the picker re-appears ("Albums" back button), since `onAppear` re-triggers it.
**Fix direction:** do the scan on a background queue with async image requests, hop to `DispatchQueue.main` for state writes, and cache results across appearances.

### H4. Smart albums are almost certainly missing from the picker
`ContentView.swift:608`
`PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, ...)` uses a *user-album* subtype as the filter; smart albums have their own subtypes (`.smartAlbumScreenshots`, `.smartAlbumSelfPortraits`, …), so this fetch returns nothing. Recents, Screenshots, Selfies, Favorites don't show up — and screenshots cleanup is the app's core use case.
**Fix direction:** `subtype: .albumRegular` → `.any` for the smart-album fetch (then optionally filter out irrelevant ones like Hidden/Recently Deleted).

### H5. Permission denied or restricted → silent empty screen
`ContentView.swift:195–199`
Only `.authorized`/`.limited` are handled. If the user denies access (or has it restricted), the album grid stays empty forever with no explanation and no link to Settings. `.limited` is treated as full access with no way to expand the selection (`presentLimitedLibraryPicker`).
**Fix direction:** handle `.denied`/`.restricted` with a message + `UIApplication.openSettingsURLString` button; offer the limited-library picker for `.limited`.

---

## Medium

### M1. Stale `PHAsset` snapshots after favoriting
`ContentView.swift:245, 308, 478–501`
`PHAsset` objects are immutable snapshots; after `performChanges` toggles `isFavorite`, the instances in `photoAssets` still report the old value. Consequences: the white heart badge (`:308`) and accessibility label (`:289`) show the pre-toggle state when you navigate back to a photo (Undo or thumbnail tap), and a second double-tap on that photo computes `!asset.isFavorite` from the stale value (`:245, 481`) so it re-favorites instead of unfavoriting.
**Fix direction:** re-fetch the asset by `localIdentifier` after the change, or adopt `PHPhotoLibraryChangeObserver`.

### M2. Double-tap favorite auto-advances, and Undo doesn't undo it
`ContentView.swift:494–495, 319–327`
Favoriting a photo also skips to the next one (`currentIndex += 1` inside `toggleFavorite`'s completion) — surprising, and it fires ~a beat after the heart animation. Undo then walks the index back and removes the asset from `favoritedAssets`, but never reverts the actual library favorite — so Undo silently lies for favorite actions.
**Fix direction:** don't advance on favorite (or make Undo action-aware with a proper action stack).

### M3. Delete failure/cancel is silent
`ContentView.swift:561–564`
If `performChanges` fails — including the very normal case of the user tapping "Don't Allow" on the system dialog — the only output is `print`. No snackbar, no retained state (`showDeleteButton` is cleared; see H2 path 3). `toBeDeleted` is kept, so the count is preserved, but the user gets zero feedback.
**Fix direction:** show a snackbar on failure and restore the pre-delete UI state.

### M4. Thumbnail strip: custom drag fights native scrolling, and it wraps around
`ContentView.swift:351–398`
A `DragGesture` is attached to the content of a horizontal `ScrollView` to page photos — the two compete for the same pan, so behavior is inconsistent (scroll sometimes wins, gesture sometimes fires, both feel glitchy). Separately, `(currentIndex + $0) % photoAssets.count` (`:354`) wraps already-reviewed (and to-be-deleted) photos back into the "upcoming" strip near the end, and tapping one jumps backwards without clearing intermediate marks the way Undo does.
**Fix direction:** drop the custom gesture (thumbnail taps already navigate) and clamp the window instead of wrapping.

### M5. Whole-library enumeration on the main thread
`ContentView.swift:580–601`
`loadPhotos` is called from the album-tap action on the main thread and synchronously materializes every `PHAsset` via `enumerateObjects`. On a 20–50k photo library ("All Photos") this is a visible UI hang. The `DispatchQueue.main.async` at the end only re-dispatches to the queue it's already on.
**Fix direction:** run fetch+enumerate on a background queue; publish results on main.

### M6. Finishing with nothing marked still lands on the delete screen
`ContentView.swift:447–475, 534–540`
`moveToNextPhoto` sets `showDeleteButton = true` unconditionally, so swiping right through everything shows "You're done swiping! **0 photos marked for deletion**" with a red "Delete Now" button that performs an empty batch delete (snackbar: "Deleted 0 photos, freed up Zero KB") and reloads the album from index 0.
**Fix direction:** when `toBeDeleted.isEmpty`, show a "All done 🎉 / Choose another album" state without the delete button.

### M7. Dynamic Type is capped below accessibility sizes
`ContentView.swift:132, 331, 405` (and others)
`.dynamicTypeSize(.small ... .xxLarge)` *limits* text scaling — users with accessibility text sizes (AX1–AX5) don't get larger text on exactly the controls that matter (Undo, Delete). Given the README's stated audience includes the developer's parents, this works against the goal.
**Fix direction:** remove the caps or raise the upper bound to `.accessibility5`.

### M8. Deprecated APIs
- `PHPhotoLibrary.requestAuthorization(_:)` (`:195, PhotoManager.swift:17`) — deprecated since iOS 14; use `requestAuthorization(for: .readWrite)`, which also distinguishes `.limited` properly.
- `NavigationView` (`:159`) — deprecated in iOS 16; use `NavigationStack`.
- `onChange(of:perform:)` (`:75`) — deprecated in iOS 17; use the two-parameter form.
- `UIScreen.main.bounds` for grid sizing (`:683, 689`) — wrong under iPad multitasking; use `GeometryReader` or let the grid size itself.

---

## Low

### L1. `PhotoManager.swift` is entirely dead code
Never instantiated anywhere. Its `deleteImage` also deletes one-by-one and its `fetchPhotos` eagerly loads every image at 600×600 into memory — patterns the live code correctly avoids. Delete the file (already flagged in CLAUDE.md).

### L2. `favoritePhoto(_:)` is an unused near-duplicate of `toggleFavorite(_:)`
`ContentView.swift:504–531` — never called; delete.

### L3. Write-only / unused `@State`
- `favoritedAssets` (`:22`) — appended/removed but never read; pure bookkeeping with no UI.
- `bgColor` (`:32`), `shouldPulseHeart` (`:31`), `albumSearchText` (`:21`) — never used.

### L4. `.buttonStyle(ScaleButtonStyle())` has no effect where it's applied
`ContentView.swift:117` — it's on the `Text` *inside* the button's label; `buttonStyle` propagates downward, so it never reaches the enclosing `Button`. Move it onto the `Button` itself (after `:123`).

### L5. Info.plist issues
`Info.plist:29–34` — `NSPhotoLibraryUsageDescription` is declared **twice** (duplicate key; which one wins is undefined — clean up before App Store submission). `NSPhotoLibraryAddUsageDescription` is unnecessary: it governs *add-only* access; deletion is covered by the main usage key. Also portrait-only `UISupportedInterfaceOrientations` without an iPad-specific key can trip App Store validation if iPad is a supported destination.

### L6. Snackbar animation and stray hide
`showSnackbar = true` in `deleteMarkedPhotos` (`:552`) isn't wrapped in `withAnimation`, so the `.transition(.move(edge: .bottom))` (`:71`) never animates — the toast pops in. And `toggleFavorite` schedules `showSnackbar = false` after 2s (`:491–493`) without ever showing one, which can prematurely hide the delete snackbar if a favorite happens within its 3s window.

### L7. Misc
- `deleteMarkedPhotos` waits an arbitrary hard-coded 0.8s before processing the result (`:547`) — cosmetic delay that also delays error handling.
- `fetchAlbums` creates a fresh `PHCachingImageManager` per call (`:616`) — the cache never survives, so it's just a slower `PHImageManager`.
- Splash button has a redundant `.accessibilityAddTraits(.isButton)` (`:124`) — `Button` already has the trait.

---

## What's in good shape

- The core batch-delete design is right: swipes only mark; one `performChanges` deletes everything at once; Undo works *because* nothing is deleted eagerly.
- On-demand image loading (`PhotoAssetImage` 800×800, `PhotoThumbnailView` 80×80, `.id(localIdentifier)`) keeps memory flat — no eager full-library image array.
- Accessibility effort is well above average for a weekend project: labels, hints, and combined elements on all interactive views (M7's size caps are the main gap).
- Async `PHImageManager.requestImage` callbacks (used by the photo views) deliver on the main thread, so those `@State` writes are safe — the threading problem is confined to `fetchAlbums` (H3).

## Suggested fix order

1. **H2 + M3** (dead ends + silent failure) — the only "app feels broken, force-quit" class.
2. **H4** (smart albums) — one-word change, unlocks the core screenshots use case.
3. **H3 + M5** (threading/perf) — correctness under the hood, big-library responsiveness.
4. **H5** (permissions UX) — required for App Store quality bar.
5. **H1** (space-freed counter) — headline feature, moderate effort.
6. M1/M2 (favorites correctness), M6/M7, then the Lows as a cleanup pass.
