# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Leftover** is a minimalist iOS photo gallery cleaner built with SwiftUI. Users swipe left to delete photos and right to keep them. It's a local-only app—no cloud sync, no login required.

## Tech Stack

- **Language**: Swift 5.5+
- **UI Framework**: SwiftUI
- **Photo Access**: PhotoKit / UIKit
- **Minimum iOS**: iOS 16+
- **IDE**: Xcode 15+

## Building & Running

### Prerequisites

- Xcode 15 or later
- iOS 16+ device or simulator (note: delete operations don't work properly in simulator due to sandboxing)

### Build & Run

```bash
# Open the project in Xcode
open Leftover.xcodeproj

# Or build from command line
xcodebuild -scheme Leftover -configuration Debug
```

**For real device testing**: Connect an iPhone and run from Xcode. Photo deletion requires a real device because the simulator sandboxes photo library writes.

## Codebase Structure

### Core Files

- **LeftoverApp.swift**: App entry point. Simple `WindowGroup` setup with `ContentView()` as root.
- **ContentView.swift** (785 lines): Main UI hub. Contains all view hierarchy, state management, and gesture handling.
  - `splashScreenView`: Welcome screen with app name and tagline
  - `albumPickerView`: Grid of photo albums to select from
  - `swipeCard`: Main swiping interface for photos
  - `deleteConfirmation`: Final confirmation before batch delete
  - Multiple gesture handlers for swipe/drag interactions
- **PhotoManager.swift**: Encapsulates PhotoKit operations.
  - `requestPhotoAccess()`: Handles permission requests
  - `fetchPhotos()`: Loads all photos (or filtered by album) from the library, resizes to 600x600
  - `deleteImage()`: Actually removes photo from library
  - `keepImage()`: Removes from UI view only (not from library)

### State Management

ContentView uses `@State` for local UI state:
- `photoAssets`: Array of `PHAsset` objects being reviewed
- `currentIndex`: Index of currently displayed photo
- `toBeDeleted`: Photos marked for deletion
- `showAlbumPicker`, `showSplashScreen`, `isDeleting`: View visibility flags
- Animation/gesture states: `heartScale`, `pulse`, `shakeOffset`, `bgColor`, etc.

PhotoManager uses `@Published` properties to expose photo arrays to SwiftUI.

## Key Architectural Decisions

1. **Centralized UI in ContentView**: Rather than breaking into smaller components, most logic lives in ContentView for simplicity. This is intentional for a small project.

2. **Lazy Photo Loading**: Photos are fetched from PhotoKit in the background and resized to 600x600 for performance. The original assets are kept for deletion operations.

3. **Real vs. UI Deletion**: "Keep" moves a photo out of the current view without deleting from library. "Delete" marks for batch deletion via `PHPhotoLibrary.performChanges()`.

4. **Album Picker**: Must request photo library access before loading. Users pick an album (or "All Photos") and then review images from that collection.

5. **Animations**: Heavy use of SwiftUI `withAnimation()` for UI transitions and `.animation()` modifiers for continuous effects (pulse, scale, rotation). See splash screen and heart animations for examples.

## Common Development Tasks

### Adding a New View

1. Create a computed var property in ContentView (e.g., `var myNewView: some View { ... }`)
2. Add a new `@State` flag to control visibility (e.g., `@State private var showMyView = false`)
3. Update the main `ZStack` logic to conditionally show the view
4. Use `withAnimation { showMyView = true }` to transition

### Modifying Photo Fetching

- Edit `PhotoManager.fetchPhotos()` to change sort order, filtering, or request options
- Changes to target image size are in `requestImage(targetSize:...)`
- Remember to dispatch UI updates back to `DispatchQueue.main`

### Adding Gesture/Animation

- Swipe/drag gestures live in the `swipeCard` view
- Use `.gesture()` modifier to attach `DragGesture` or similar
- State updates inside gesture handlers automatically trigger re-renders
- Wrap updates in `withAnimation()` to animate the change

### Debugging Photo Library Access

- Check Info.plist: NSPhotoLibraryUsageDescription and NSPhotoLibraryAddUsageDescription must be set
- Test on a real device (simulator doesn't fully support photo library writes)
- Use Xcode's Debug → View Hierarchy to inspect SwiftUI state in the simulator

## Important Notes

1. **No PhotoManager singleton**: PhotoManager is instantiated fresh in ContentView (or passed via dependency injection). This avoids tight coupling.

2. **Photo indices are tied**: `assets` and `images` arrays must stay in sync. When you delete or keep a photo, update both arrays.

3. **Main thread dispatch**: All UI updates from PhotoKit callbacks must dispatch to `DispatchQueue.main.async { ... }`.

4. **Animation syntax**: Use `withAnimation { ... }` for one-off state changes that should animate. Use `.animation()` modifiers for continuous bindings.

5. **Xcode build quirks**: 
   - Always do a clean build (`Cmd+Shift+K`) if you change Info.plist keys
   - Photo library permissions are cached per app bundle ID; uninstall and reinstall if permissions are stuck

## Testing & QA

- **Manual testing only**: No automated tests currently. Test by running on device.
- **Golden path**: Splash → Album Picker → Swipe a few → Confirm delete → Check Camera Roll
- **Edge cases**: Empty albums, single photo, rapid swiping, toggling favorites
- **Undo feature**: If implemented, verify it properly re-adds deleted photos and indices

## Performance Considerations

- **Photo resize**: 600x600 is chosen as a balance between UI quality and memory. Adjust if needed.
- **Batch deletion**: Deleting multiple photos via one `performChanges()` is efficient. Don't delete one-by-one.
- **Lazy grid**: Album picker uses `LazyVGrid` with 2 columns. Thumbnails are cached or regenerated per album.

## Future Features (from README)

- Batch review mode
- Auto-suggestions (blurry/duplicate/screenshot detection)
- Dark mode
- Onboarding flow
- Custom swipe action settings
- Video support

When implementing any of these, follow the established patterns: add state to ContentView, create new view properties, and dispatch PhotoKit work to background threads.

## Useful Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [PhotoKit Documentation](https://developer.apple.com/documentation/photokit)
- [PHAsset & PHAssetChangeRequest](https://developer.apple.com/documentation/photokit/phasset)
- Xcode Help: `Cmd+?` in Xcode, search "SwiftUI" or "PhotoKit"

