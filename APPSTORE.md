# App Store Connect — fill-in pack

Everything below is ready to paste into App Store Connect. Character
counts are against Apple's limits. Indexed fields (name, subtitle,
keywords) never repeat a word between them — Apple indexes the union,
and repeats waste characters.

## Identity

| Field | Value | Limit |
|---|---|---|
| **App name** | `Leftover: Photo Cleaner` | 23/30 |
| **Subtitle** | `Swipe to free up storage` | 24/30 |
| **Primary category** | Photo & Video | |
| **Secondary category** | Utilities | |
| **Age rating** | 4+ (no flagged content) | |
| **Price** | Free | |

Name pattern is brand + top keyword; subtitle carries the two next
highest-intent phrases ("swipe", "free up storage") without repeating
"photo" or "cleaner" from the name.

## Keyword field (99/100 chars)

```
duplicate,similar,screenshot,blurry,delete,remove,gallery,album,declutter,space,video,tidy,organize
```

Rules applied: no spaces after commas (wastes chars), no words already
in name/subtitle, no plurals (Apple stems), no competitor names
(rejection bait). Long-tail combinations these unlock: "delete
duplicate photos", "remove screenshots", "declutter gallery", "blurry
photo cleaner", "free up space video".

## Promo text (164/170 — editable anytime without review)

```
Your camera roll didn't get messy in a day. Two minutes of swiping a day cleans it for good — and you'll actually see the gigabytes come back. No cloud. No account.
```

## Description (not indexed — written purely to convert)

```
Your photo library has thousands of photos you'll never look at twice.
Screenshots of parking spots. Nine takes of the same sunset. Blurry
everything. Leftover makes clearing them feel like a game you want to
play.

SWIPE TO DECIDE
Left deletes, right keeps. Real throw physics, satisfying haptics, and
an undo for changed minds. Nothing is deleted until you confirm — and
everything you delete sits in Recently Deleted for 30 days.

IT FINDS THE CLUTTER FOR YOU
• Duplicates — exact copies grouped, best version pre-selected to keep
• Similar Shots — burst-alike series, sharpest shot picked for you
• Blurry — sharpness-scored, worst first
• Screenshots — the pile you always mean to deal with
• Large Videos — your biggest space hogs, sorted by size

WATCH THE SPACE COME BACK
Every cleanup ends with the number that matters: how much storage you
freed. A Library Health Score grades your whole library and climbs as
you clean. Earn trophies for milestones. Come back tomorrow for a
fresh Memory Burst — a daily two-minute dose of "this day, years ago."

PRIVATE BY DESIGN
No account. No cloud. No analytics. No ads. Your photos never leave
your phone — all scanning happens on-device. One permission, and it's
the one you'd expect.

Made by one person who had 40,000 photos and a full iPhone.
```

## What's New template (v1.0)

```
First release. Swipe away the photos you don't need — Leftover finds
duplicates, similar shots, screenshots, blur, and giant videos, and
shows you exactly how much space you got back.
```

## URLs

| Field | Value |
|---|---|
| Support URL | `https://whysokara.github.io/Leftover/support.html` |
| Marketing URL (optional) | `https://whysokara.github.io/Leftover/` |
| Privacy Policy URL | `https://whysokara.github.io/Leftover/privacy.html` |

> ⚠️ Requires enabling GitHub Pages on the repo (Settings → Pages →
> deploy from `main` `/docs`). Do this before submission — App Review
> opens these links.

## App Privacy (nutrition label)

- **Data collection: "Data Not Collected"** — the strongest label on
  the store and true for Leftover: no analytics, no tracking, no
  third-party SDKs, no accounts. All processing on-device.
- Privacy manifest (`PrivacyInfo.xcprivacy`) already declares the only
  required-reason API in use (UserDefaults, CA92.1).

## Review notes (paste into "Notes for Review")

```
Leftover is a local-only photo cleanup app. No login — no demo account
needed. Photo library full-access is requested because the app scans
for duplicates/similar/blurry photos across the library; all analysis
is on-device (no network calls in the app at all). Deletions go
through the standard PHPhotoLibrary confirm dialog and land in
Recently Deleted for 30 days. To see the main flow: grant access →
tap the Memory Burst card → swipe left/right → tap Delete.
```

## Screenshot script (6.7" required set, 6 frames)

2026 note: Apple OCR-indexes caption text — captions carry keywords.
First 3 frames decide the install; lead with the outcome, not the UI.

| # | Frame | Caption (large, top) |
|---|---|---|
| 1 | Delete celebration — "2.3 GB freed" headline + brand mark | **Free up gigabytes in minutes** |
| 2 | Swipe screen mid-throw, edge glow visible | **Swipe left to delete, right to keep** |
| 3 | Duplicates screen, one group with keeper badge | **Finds duplicate photos for you** |
| 4 | Similar Shots group | **Cleans burst photos & similar shots** |
| 5 | Home cover-flow + health score visible | **Your library gets a health score** |
| 6 | Settings privacy panel / permission screen | **No cloud. No account. On-device.** |

Production notes: shoot on the 6.7" sim (`iPhone 17 Pro Max`) with a
seeded photo library; dark canvas frames on the store look distinctive
against white competitor listings. Reuse frame 1 as the App Store
preview poster if a video is added later.

## Submission checklist

- [ ] Enable GitHub Pages (support/privacy URLs live)
- [ ] Archive with Distribution profile, upload via Xcode Organizer
- [ ] Privacy label: "Data Not Collected"
- [ ] Screenshots: 6.7" set (mandatory), 6.1" optional (scaled otherwise)
- [ ] Review notes pasted
- [ ] `ITSAppUsesNonExemptEncryption` already in Info.plist ✓
- [ ] Rating prompt gated ✓ (2+ cleanups, 1/version, 120-day spacing)
- [ ] TestFlight pass on a real device first (deletion needs real hardware)
