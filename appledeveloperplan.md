# App Store Readiness Plan — Leftover iOS App

*Last updated: 2026-05-23 (re-audit confirmed nothing has been implemented yet; all items below still apply)*

---

## ✅ What's Already Good (no action needed)

- **Accessibility** — 13+ VoiceOver labels, dynamic type support, combined element hints. Solid.
- **Memory safety** — No retain cycles, array bounds are properly checked (e.g., `if newIndex < photoAssets.count` at line 77).
- **Nil safety** — `guard let asset = currentAsset else { return }` used where needed.
- **Encryption export compliance** — App uses no encryption, no network. No `ITSAppUsesNonExemptEncryption` declaration needed.
- **Entitlements** — None needed (no iCloud, push, Sign-in-with-Apple, HealthKit, etc.).
- **Snackbar UI** — Already implemented for success cases; just needs to be extended to failure paths.

---

## 🔴 BLOCKERS — Submission Will Fail Without These

### 1. Bundle ID mismatch
**File:** `Leftover.xcodeproj/project.pbxproj` (lines 289 & 318)

Both Debug and Release configs have `PRODUCT_BUNDLE_IDENTIFIER = test.Leftover`. Info.plist has the correct `com.kara.leftover`, but the project setting overrides it.

**Fix:** In Xcode > target > Signing & Capabilities > Bundle Identifier, change `test.Leftover` → `com.kara.leftover`. This updates both configurations.

### 2. Development Team not set
**File:** `Leftover.xcodeproj/project.pbxproj`

`CODE_SIGN_STYLE = Automatic` is set but no `DEVELOPMENT_TEAM` exists. **Requires a paid Apple Developer Program membership ($99/year)**.

**Fix:** In Xcode > target > Signing & Capabilities, sign in with your Apple ID, select your team.

### 3. App Icon PNG missing (design asset)
**Folder:** `Leftover/Assets.xcassets/AppIcon.appiconset/`

Only `Contents.json` exists — no PNG file. Build will fail with "Missing App Icon."

**Fix:** Create a 1024×1024 PNG (RGB, no transparency, no rounded corners — Apple applies the mask). Name it `AppIcon.png`, drop it in the folder, and update `Contents.json`:
```json
{
  "images": [
    {
      "filename": "AppIcon.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

### 4. Missing PrivacyInfo.xcprivacy (required since Spring 2024)
**New file:** `Leftover/PrivacyInfo.xcprivacy`

App uses `PHPhotoLibrary` (a tracked API per Apple's policy). Without this manifest, Apple will reject the submission.

**Fix:** Create the file below, then in Xcode right-click the Leftover group > Add Files > check "Add to target: Leftover":
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryPhotoLibrary</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>1.1</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
</dict>
</plist>
```
Reason code `1.1` = "App accesses this API for its primary functionality."

### 5. Info.plist + project.pbxproj conflict
**Files:** `Leftover/Info.plist` and `Leftover.xcodeproj/project.pbxproj`

Three intertwined problems caused by `GENERATE_INFOPLIST_FILE = YES` alongside a custom Info.plist — Xcode auto-generates a base plist and *overrides* parts of your custom one, causing silent drops/conflicts.

**Fixes (do all three):**

**a)** In `project.pbxproj`, set `GENERATE_INFOPLIST_FILE = NO` in both Debug and Release configs. This makes your custom Info.plist authoritative.

**b)** In Info.plist, remove the duplicate `NSPhotoLibraryUsageDescription` key. Keep one with clear language:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Leftover needs access to your photo library to show images for swiping and to delete the ones you choose.</string>
```

**c)** In Info.plist, remove the orphaned launch storyboard reference (no `LaunchScreen.storyboard` file exists in the project):
```xml
<!-- DELETE THESE TWO LINES: -->
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>
```

---

## 🟡 HIGH PRIORITY — Apple Review Risk

### 6. Handle photo permission denial gracefully
**File:** `ContentView.swift` — `albumPickerView` `onAppear` (lines 194–200)

Currently: if user denies, app silently shows an empty album list. Apple reviewers test this exact path and will reject.

**Fix:**

Add state variable near the other `@State` declarations:
```swift
@State private var photoAuthStatus: PHAuthorizationStatus = .notDetermined
```

Replace the current `onAppear` block:
```swift
.onAppear {
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        DispatchQueue.main.async {
            photoAuthStatus = status
            if status == .authorized || status == .limited {
                fetchAlbums()
            }
        }
    }
}
```
*(This also fixes the deprecated `requestAuthorization` API — use `requestAuthorization(for:)` per iOS 14+.)*

Add `.alert` modifier to the `NavigationView` in `albumPickerView`:
```swift
.alert("Photo Access Required", isPresented: .constant(photoAuthStatus == .denied || photoAuthStatus == .restricted)) {
    Button("Open Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("Leftover needs access to your photos to work. Please enable it in Settings > Privacy > Photos.")
}
```

### 7. Orientation conflict
Info.plist says portrait-only, but `project.pbxproj` allows portrait + landscape on both iPhone and iPad. The app UI is not landscape-aware.

**Fix:** In Xcode > target > General > Deployment Info, uncheck **Landscape Left**, **Landscape Right**, and **Portrait Upside Down** for both iPhone and iPad. Then remove `UISupportedInterfaceOrientations` from Info.plist entirely (let the project setting be authoritative once `GENERATE_INFOPLIST_FILE = NO`).

---

## 🟢 POLISH — Should Fix Before Submission

### 8. Show error feedback when deletion fails
**File:** `ContentView.swift` — `deleteMarkedPhotos()` (around line 562)

The `else` branch only calls `print()`. Show a snackbar instead (the snackbar UI is already wired up):
```swift
} else {
    snackbarMessage = "Could not delete photos. Please try again."
    showSnackbar = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showSnackbar = false }
}
```

### 9. Fix force-unwrapped URL (line 135)
```swift
// Replace:
Link("Kara", destination: URL(string: "https://x.com/whysokara")!)

// With:
if let url = URL(string: "https://x.com/whysokara") {
    Link("Kara", destination: url)
        .font(.footnote)
        .foregroundColor(.accentColor)
        .underline()
}
```

### 10. Remove debug print() statements
Three locations in ContentView.swift (lines 497, 527, 562). Replace with snackbar feedback (combines with #8) or wrap in `#if DEBUG` blocks.

### 11. Replace deprecated UIScreen.main.bounds
**File:** `ContentView.swift` — `AlbumGridItem` struct (lines 683, 689)

Replace `UIScreen.main.bounds.width / 2 - 32` with a `GeometryReader` so the cell respects its allocated width inside `LazyVGrid`:
```swift
GeometryReader { geo in
    // use geo.size.width
}
```

### 12. Remove dead code
- `favoritePhoto(_ asset:)` in ContentView.swift (lines 504–531) — never called; `toggleFavorite()` is the real one
- `PhotoManager.swift` (entire file, 82 lines) — never imported or instantiated. Right-click in Xcode > Delete > Move to Trash

---

## 📋 App Store Connect Setup (after code is ready)

- **Age rating:** 4+
- **Category:** Utilities or Photo & Video
- **Screenshots:** Required for 6.7" iPhone (e.g., iPhone 15 Pro Max). Optional for iPad
- **Description:** Emphasize "no account, no data collection, fully local"
- **Privacy nutrition label:** Photos → "App Functionality" → "Not Linked to You"
- **Encryption declaration:** Select "Does not use encryption" (or set `ITSAppUsesNonExemptEncryption = false` in Info.plist to skip the prompt every upload)

---

## ✔️ Verification Before Archiving

1. Clean build (`Cmd+Shift+K`), then build — zero errors, zero "missing key" warnings
2. Open built `Leftover.app/Info.plist` from DerivedData and verify:
   - `CFBundleIdentifier = com.kara.leftover`
   - Exactly one `NSPhotoLibraryUsageDescription`
   - No `UILaunchStoryboardName`
3. Confirm `PrivacyInfo.xcprivacy` exists at the root of the `.app` bundle
4. Asset catalog shows AppIcon with no yellow warning triangle
5. On a real device:
   - First launch shows photo permission prompt
   - Deny permission → alert appears with working "Open Settings" deep-link
   - Grant permission → albums load → swipe → delete works
   - Force a deletion error (e.g., revoke permission mid-flow) → snackbar shows error
6. Product > Archive → Validate App in Organizer → all checks pass

---

## ⏱️ Estimated effort

- **Blockers (1–5):** ~2 hours of code/config + design time for the icon + Apple Developer enrollment
- **High priority (6–7):** ~1 hour
- **Polish (8–12):** ~1 hour
- **App Store Connect setup + first upload:** ~2 hours

**Total dev time: ~6 hours** once you have an Apple Developer account and an app icon ready.
