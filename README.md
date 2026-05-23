# 🧹 Leftover – Clean Your Gallery, One Swipe at a Time

Leftover is a minimalist iOS app that helps you clean your photo gallery by swiping—just like Tinder. Swipe left to delete, right to keep, and free up precious storage space without the usual clutter or friction.

---

## 📸 Why I Built This

Like many of us, I have thousands of photos on my phone—screenshots, blurry duplicates, memes I saved “just for now”… and never got around to deleting.

My parents also struggle with smartphone interfaces, and I realized there's no **fun, lightweight** way to clean a gallery without overwhelming them (or me).

So I built **Leftover** in SwiftUI as a weekend project to solve one simple problem:  
👉 **How do we make photo cleanup quick, frictionless, and even fun?**

---

## ✨ Features

- ✅ **Swipe left to delete**, right to keep
- ✅ **Live preview** of the current photo
- ✅ **Undo last swipe** to recover accidental deletions
- ✅ **Track total space freed** as you swipe
- ✅ **iOS-style animations and gestures**
- ✅ **One-tap delete** with iOS-style snackbar confirmation
- ✅ **Progress ring** while deleting for better feedback
- ✅ **Local-only** — no cloud sync, no login required
- ✅ Designed with **simplicity and speed** in mind

---

## 🧠 Still To Come

> Feature ideas for future versions:

- [ ] Batch review mode
- [ ] Auto-suggestions for blurry/duplicate/screenshot photos
- [ ] Dark mode support
- [ ] Onboarding for first-time users
- [ ] App Settings screen for custom swipe actions
- [ ] Support for videos and screenshots

---

## 🛠 Tech Stack

- **Swift** 5.5+
- **SwiftUI** for UI
- **PhotoKit** for photo library access
- **Xcode** 15+
- **iOS** 16+

---

## 🚀 Setup & Run

### Requirements

- Xcode 15 or later
- iOS 16+ device (iPhone or iPad)
- A real device recommended (simulator photo deletion doesn't work due to sandboxing)

### Instructions

1. Clone the repo:
   ```bash
   git clone <repo-url>
   cd leftover
   ```

2. Open the Xcode project:
   ```bash
   open Leftover.xcodeproj
   ```

3. Select your target device in Xcode and hit Run (`Cmd+R`)

4. Grant photo library access when the app asks

5. Pick an album and start swiping!

**Note:** Photo deletion requires a real device. If you test on the simulator, swipes won't actually delete photos from the library due to iOS sandboxing.

---

## ❤️ Made by

Made with love by [Kara](https://x.com/whysokara) – 2025  
This project was a fun solo build to scratch an itch, and it's still evolving.

---
