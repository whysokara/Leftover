# App Store Readiness Plan — Leftover iOS App

## BLOCKERS — Fix First or Submission Will Fail

### 1. Fix Bundle ID in Xcode project
**File:** `Leftover.xcodeproj` > target > Signing & Capabilities > Bundle Identifier

Change `test.Leftover` → `com.kara.leftover` in both Debug and Release configurations.

### 2. Set Development Team
**Requires:** Paid Apple Developer Program membership ($99/year)

In Xcode, sign into your Apple ID under Signing & Capabilities and select your team.

### 3. App Icon PNG — design asset needed
**File:** `Leftover/Assets.xcassets/AppIcon.appiconset/`

The icon slot exists but no PNG is present. Create a 1024×1024 PNG (RGB, no transparency, no rounded corners — Apple applies the mask). Place it in `AppIcon.appiconset/` and update `Contents.json`:
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

### 4. Add PrivacyInfo.xcprivacy (required since Spring 2024)
**New file:** `Leftover/PrivacyInfo.xcprivacy`

Create the file, then in Xcode right-click the Leftover group > Add Files, check "Add to target: Leftover":
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
Reason `1.1` = "App accesses this API for its primary functionality."

### 5. Fix malformed Info.plist
**File:** `Leftover/Info.plist`

- **Remove duplicate `NSPhotoLibraryUsageDescription`** — key appears twice. Keep one: `"Leftover needs access to your photo library to show images for swiping and to delete the ones you choose."`
- **Remove `UILaunchStoryboardName`** — references a storyboard that doesn't exist. The project already uses auto-generated launch screen.
- **In `project.pbxproj`**, set `GENERATE_INFOPLIST_FILE = NO` in both Debug and Release — avoids plist merge collision with the custom Info.plist.

---

## HIGH PRIORITY — Apple Review Risk

### 6. Handle photo permission denied
**File:** `ContentView.swift` — `albumPickerView` `onAppear`

Currently if the user denies photo access, the app silently shows an empty list. Apple reviewers test this. Need to:

1. Add state: `@State private var photoAuthStatus: PHAuthorizationStatus = .notDetermined`
2. Use non-deprecated API: `PHPhotoLibrary.requestAuthorization(for: .readWrite) { ... }`
3. Dispatch status update to main thread
4. Show an alert with "Open Settings" button when status is `.denied` or `.restricted`

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

---

## WARNINGS — Polish Before Submission

### 7. Show error feedback when photo deletion fails
**File:** `ContentView.swift` — `deleteMarkedPhotos()`

The `else` branch on deletion failure only calls `print()`. Show a snackbar instead so the user knows something went wrong.

### 8. Fix force-unwrapped URL (line 135, ContentView.swift)
```swift
// Before
Link("Kara", destination: URL(string: "https://x.com/whysokara")!)

// After
if let url = URL(string: "https://x.com/whysokara") {
    Link("Kara", destination: url)
}
```

### 9. Fix orientation conflict
Info.plist declares portrait-only but `project.pbxproj` also allows landscape. In Xcode > target > General > Deployment Info, uncheck Landscape Left and Landscape Right. Remove `UISupportedInterfaceOrientations` from Info.plist.

### 10. Remove dead code
- `favoritePhoto(_ asset:)` function in ContentView.swift — never called
- `PhotoManager.swift` — entire class is unused (ContentView does everything inline). Delete from project.

### 11. Remove debug print() statements
Three `print()` calls in `toggleFavorite`, `favoritePhoto`, and `deleteMarkedPhotos`. Replace with snackbar feedback or wrap in `#if DEBUG`.

### 12. Replace deprecated UIScreen.main.bounds
**File:** `ContentView.swift` — `AlbumGridItem` struct

Replace `UIScreen.main.bounds.width` with `GeometryReader { geo in ... geo.size.width ... }`.

---

## App Store Connect Checklist (do last)

- [ ] Age rating: 4+
- [ ] Screenshots: 6.5" iPhone (required), iPad (optional)
- [ ] App description: emphasize "no account, no data collected"
- [ ] Privacy nutrition label: Photos > App Functionality > Not Linked to You
- [ ] Category: Utilities or Photo & Video

---

## Verification Before Submitting

1. Clean build (Cmd+Shift+K), archive succeeds with zero errors
2. Check built `Leftover.app/Info.plist` — `CFBundleIdentifier = com.kara.leftover`, single `NSPhotoLibraryUsageDescription`, no `UILaunchStoryboardName`
3. Confirm `PrivacyInfo.xcprivacy` exists inside the app bundle
4. Asset catalog shows AppIcon with no yellow warning triangle
5. On a real device: deny photo permission → alert appears → "Open Settings" deep-links correctly
6. Product > Archive → Validate App in Organizer before uploading
