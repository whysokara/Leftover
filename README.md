# 🧹 Leftover – Clean Your Gallery, One Swipe at a Time

Leftover is a minimalist iOS app that helps you clean your photo gallery by swiping—just like Tinder. Swipe left to toss, right to keep, and free up precious storage space without the usual clutter or friction.

---

## 📸 Why I Built This

Like many of us, I have thousands of photos on my phone—screenshots, blurry duplicates, memes I saved “just for now”… and never got around to deleting.

My parents also struggle with smartphone interfaces, and I realized there's no **fun, lightweight** way to clean a gallery without overwhelming them (or me).

So I built **Leftover** in SwiftUI to solve one simple problem:
👉 **How do we make photo cleanup quick, frictionless, and even fun?**

---

## ✨ Features

### The swipe

- ✅ **Card stack** — the next photos peek behind the one you're judging
- ✅ **Swipe left to toss**, right to keep — with real throw physics, KEEP/TOSS stamps, and edge glows
- ✅ **Action dock** for tap-first users (toss / undo / favorite / keep) — same logic as the gestures
- ✅ **Keep all**, progress bar, and live keep/toss counters
- ✅ **Undo** any swipe — nothing is deleted until you confirm
- ✅ **Double-tap to favorite** a photo without leaving the flow
- ✅ **Batch delete** with a freed-space toast ("12 tossed · 148 MB freed")

### The habit

- ✅ **Home dashboard** — lifetime space freed, streak flame, and today's session at a glance
- ✅ **Today's Memory Burst** — a daily bite of "this week, years ago" photos (falls back to a screenshot sweep so it never dead-ends)
- ✅ **Streaks with freezes** — every 7-day streak earns a freeze that auto-bridges a missed day
- ✅ **Daily reminder** — one gentle nudge, only if you haven't played today
- ✅ **Screenshot Sweep** and **Time Capsule** cleanup flows
- ✅ **Duplicates finder** — perceptual-hash groups with the best copy preselected to keep, cached so rescans are instant
- ✅ **Similar Shots** — rapid-fire series (same moment, seconds apart) grouped with the sharpest shot preselected to keep
- ✅ **Blurry sweep** — sharpness scoring finds the blur, then you judge each one in the swipe deck
- ✅ **Large Videos** — biggest space hogs in a list, tap to preview, batch toss

### The vibe

- ✅ **"Theater" design** — dark-only, photos glowing on a near-black stage with floating glass chrome
- ✅ **Local-only** — no cloud sync, no login, no data collection, ever
- ✅ Full **Dynamic Type** support and Reduce Motion respect

---

## 🧠 Still To Come

> From the [roadmap](ROADMAP.md):

- [ ] Leftover Plus (unlimited bursts, power features) + paywall
- [ ] Share footer ("Sorted with Leftover 🧹")
- [ ] Home-screen widget

---

## 🛠 Tech Stack

- **Swift** 5.5+
- **SwiftUI** for UI
- **PhotoKit** for photo library access
- **UserNotifications** for the daily reminder
- **Xcode** 15+
- **iOS** 16+

No package dependencies — the whole app is a handful of Swift files.

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
   cd Leftover
   ```

2. Open the Xcode project:
   ```bash
   open Leftover.xcodeproj
   ```

3. Select your target device in Xcode and hit Run (`Cmd+R`)

4. Grant photo library access when the app asks

5. Start today's burst, or pick an album and start swiping!

**Note:** Photo deletion requires a real device. If you test on the simulator, swipes won't actually delete photos from the library due to iOS sandboxing.

---

## ❤️ Made by

Made with love by [Kara](https://x.com/whysokara) – 2025–2026
This project started as a weekend build to scratch an itch, and it's still evolving.

---
