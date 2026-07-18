# 🧹 Leftover – Clean Your Gallery, One Swipe at a Time

Leftover is a minimalist iOS app that helps you clean your photo gallery by swiping—just like Tinder. Swipe left to delete, right to keep, and free up precious storage space without the usual clutter or friction.

---

## 📸 Why I Built This

Like many of us, I have thousands of photos on my phone—screenshots, blurry duplicates, memes I saved “just for now”… and never got around to deleting.

My parents also struggle with smartphone interfaces, and I realized there's no **fun, lightweight** way to clean a gallery without overwhelming them (or me).

So I built **Leftover** in SwiftUI to solve one simple problem:
👉 **How do we make photo cleanup quick, frictionless, and even fun?**

---

## ✨ Features

### The home

- ✅ **Cover Flow navigation** — every cleanup category is a card in an endless 3D carousel (after the iPod-era Music app), complete with glossy floor reflections
- ✅ **Living card faces** — each card is a blurred collage of that category's actual photos, so you see your clutter before you tap
- ✅ **Adaptive carousel** — categories with nothing to clean disappear until they're needed again
- ✅ **Your whole library** — a Recent grid of everything, newest first; tap any photo to start swiping right there

### The swipe

- ✅ **Hands-on onboarding** — practice the swipe on demo cards before the app ever touches your library
- ✅ **Card stack** — the next photos peek behind the one you're judging
- ✅ **Swipe left to delete**, right to keep — with real throw physics and edge glows
- ✅ **Keep all**, progress bar, and live keep/delete counters
- ✅ **Undo** any swipe — nothing is deleted until you confirm
- ✅ **One consistent delete flow** — every delete confirms once, shows the space you're freeing, reminds you about the 30-day Recently Deleted safety net, then celebrates
- ✅ **Never re-judge the same photo** — leave mid-sweep and come back whenever; the session resumes where you left off, and every album remembers the last photo you decided on, so reopening it starts at the next unseen one

### The habit

- ✅ **Today's Memory Burst** — a daily bite of "this day, years ago" photos, spread across multiple years (falls back to a screenshot sweep so it never dead-ends)
- ✅ **Library Health Score** — an honest 0–100 grade of your library's clutter that drops when mess piles up and climbs as you clean, with a breakdown that jumps straight to the fix
- ✅ **Trophy shelf** — every milestone you've hit (photos deleted, space freed), collected as badges instead of vanishing after one celebration
- ✅ **Daily reminder** — one gentle nudge, only if you haven't played today
- ✅ **Screenshot Sweep** cleanup flow
- ✅ **Duplicates finder** — perceptual-hash groups with the best copy preselected to keep, cached so rescans are instant
- ✅ **Similar Shots** — rapid-fire series (same moment, seconds apart) grouped with the sharpest shot preselected to keep
- ✅ **Blurry sweep** — sharpness scoring finds the blur, then you judge each one in the swipe deck
- ✅ **Large Videos** — biggest space hogs in a list, tap to preview, batch delete

### The vibe

- ✅ **Dark, neon-accented design** — near-black stage, vibrant per-feature colors, and a glowing outline-card brand mark that runs from the app icon through the splash screen
- ✅ **Local-only** — no cloud sync, no login, no data collection, ever
- ✅ **Accessibility-audited** — Dynamic Type throughout, Reduce Motion respected everywhere, WCAG-checked contrast, 44pt tap targets, VoiceOver labels on every control

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
- iOS 16+ iPhone
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
