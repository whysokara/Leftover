# Leftover Roadmap — from album swiper to daily cleaning habit

Target feature set (from reference screenshots): home dashboard with lifetime-freed stat and streak, a daily "Memory Burst" session, smart cleanup categories (Duplicates, Screenshot Sweep, Large Videos, Time Capsule), an upgraded review screen (progress bar, keep/toss counters, action bar, Keep all), streaks with freezes and a daily reminder, a Settings screen with a privacy trust panel, a Plus subscription with a post-burst paywall, and an optional share-link footer.

Everything stays **local-only** — no accounts, no backend. All state lives in `UserDefaults`/`@AppStorage` plus one small JSON cache file. Every screen uses `Theme` tokens (safelight amber replaces the reference app's green as accent; KEEP/TOSS stamps and haptics carry over everywhere).

---

## Phase 0 — Foundation refactor (prerequisite for everything below)

The ContentView monolith works for one flow; eight new screens need structure. No behavior changes in this phase.

**New file layout (each ~100–300 lines, same patterns as today):**

- `AppModel.swift` — one `ObservableObject` injected via `.environmentObject`: photo auth status, album/category loading, streak state, stats, entitlement. Absorbs `fetchAlbums`/`loadPhotos`/`deleteMarkedPhotos`/`toggleFavorite` and the toast queue.
- `ReviewSession.swift` — a struct that owns what today is scattered `@State`: `assets`, `currentIndex`, `toBeDeleted`, `totalSize`, plus `source` (album / burst / category) and computed `progress`, `keptCount`, `tossedCount`. Both the classic album flow and every new flow run through the same session type — one review engine, many entry points.
- `Stats.swift` — persistent counters: `lifetimeFreedBytes`, `lifetimeTossedCount`, `lastSessionDate`, streak fields. Written after each successful batch delete.
- Views split out: `HomeView.swift`, `ReviewView.swift`, `AlbumPickerView.swift`, `SettingsView.swift`, `PaywallView.swift` (later phases).

**Navigation:** replace the ZStack flag-switching with one `enum Screen { case home, albums, review(ReviewSession.Source), settings }` on AppModel — same visual transitions (`Theme.settle`), but new screens stop multiplying boolean flags.

**Verify:** golden path unchanged on device; empty-album / permission-denied / delete-cancel paths still work.

---

## Phase 1 — Home dashboard (new root screen)

**Flow:** splash (first launch only) → **Home**. Home replaces the album picker as root; "Browse albums" becomes a row/tile that pushes the existing picker.

**Layout (top to bottom):**
1. Top bar: gear (→ Settings), spacer, **freed-space stat** ("3.2 GB" — `lifetimeFreedBytes`, SF Mono tabular) and **streak flame + count**.
2. Wordmark row: `Theme.display` "Leftover".
3. **Today's Burst card** — the hero. Amber-gradient print card (`Theme.amberFill` → deepened variant), eyebrow "TODAY'S MEMORY BURST" (mono, tracked), title from the burst engine ("This week, years ago"), subtitle "N photos from your past.", primary CTA "Start today's burst". Completed state: card flips to `Theme.print` with a checkmark and "Come back tomorrow."
4. **"Sort your leftovers" 2×2 grid** — Duplicates, Screenshot Sweep, Large Videos, Time Capsule tiles: SF Symbol in safelight, rounded title, mono count/size subtitle. Counts load lazily (Phase 3 engines) with a shimmer placeholder; tap → review session for that category.
5. **Recent photos strip** — first ~9 of All Photos, tap → classic review at that photo.

**Logic:** category counts computed on `.task` per visit, cached in memory for the session; heavy ones (duplicates) read from the Phase 3 cache file first and refresh in background.

**Interaction:** tiles use `ScaleButtonStyle`; counts animate in with `Theme.settle`; the streak flame does one `Theme.pop` when it increments today.

---

## Phase 2 — Review screen upgrades (applies to all sources)

Matches the reference review screen while keeping the card + stamps as the centerpiece.

**Top bar:** `X` (capsule pill, exits with confirm-if-marks alert: "Toss the N you marked, or discard marks?") · thin **progress bar** (`session.progress`, safelight fill, hairline track) · **"Keep all"** (marks the session done, no deletions — primarily for burst/category flows).
**Counter row:** left `tossedCount` in `Theme.toss`, right `keptCount` in `Theme.keep`, both mono tabular — mirrors the red/green counters in the reference.
**Bottom action bar** (capsule dock, `.ultraThinMaterial`): **Share** (`UIActivityViewController` for the current photo) · **Toss** (trash, = left swipe: same stamp animation fired programmatically + `.rigid` haptic) · **Undo** · **Keep** (heart, = right swipe + `.soft`) · **Favorite** (star → existing `toggleFavorite`). Buttons exist so parents don't have to swipe; swiping keeps working identically.
**End of session:** existing `deleteConfirmation`, plus session summary line ("Kept 12 · Tossed 7 · 148 MB ready to free").

**Logic:** all buttons drive the same `ReviewSession` mutations the gestures use — one code path, no drift.

---

## Phase 3 — Smart categories (the "Sort your leftovers" engines)

Each engine produces `[PHAsset]` (or groups) consumed by a `ReviewSession`. All run on background queues; results published on main (established pattern).

**a. Screenshot Sweep** (easiest, ship first)
- Logic: `PHAsset.fetchAssets` with `NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)`, newest first.
- Flow: tile shows count → straight into a review session titled "Screenshot Sweep".

**b. Large Videos**
- Logic: fetch `.video` assets, read sizes via `assetFileSize` (already exists), sort desc, keep those > ~50 MB.
- Flow: not a swipe deck — a **list** (thumbnail, duration badge, mono file size), tap to preview (`PHImageManager.requestPlayerItem` + `VideoPlayer`), swipe-to-mark or checkbox, one batch "Toss N videos · frees X GB" button. Reuses batch-delete + toast.
- Requires extending review/delete to videos (delete path is identical; only the card view differs).

**c. Duplicates**
- Logic: perceptual hash (dHash): for each image asset, request a 32×32 grayscale thumbnail, compute a 64-bit hash, group by Hamming distance ≤ 5, groups sorted by wasted bytes.
- **Performance is the risk** on 20k+ libraries: hash incrementally (batches of ~500 with progress "Scanned 3,200 / 18,000"), persist `localIdentifier → hash` in a JSON cache in Application Support so rescans only hash new assets. First scan happens behind the tile with a progress ring; tile shows "232 groups" when ready.
- Flow: group review screen — best-guess keeper preselected (highest resolution, then favorite, then newest), others marked to toss; user can flip any; "Keep all" per group; confirm across groups → one batch delete.

**d. Time Capsule / Memory Burst** (same engine, two doors)
- Logic: "this week, years ago" — for each prior year, fetch assets where `creationDate` falls in the current ISO week; burst takes up to 10 (oldest year first), Time Capsule tile opens the full set.
- Burst flow: Home card → review session (progress bar reads "3 of 10") → **burst-complete sheet**: celebration glyph (`sparkles` pop + success haptic), "You've kept what matters today. Come back tomorrow.", streak increment — and the Plus upsell (Phase 5) if free.
- Empty case (no photos from prior years this week): card says "No memories this week — sweep 10 screenshots instead" and substitutes the newest 10 screenshots. The daily habit never dead-ends.

---

## Phase 4 — Streak, freezes, daily reminder

**Streak logic (`Stats.swift`):** `streakCount`, `freezesEarned`, `lastCompletedDay` (a `DateComponents` day, computed in the user's calendar — no raw `Date` comparisons across midnight/timezones).
- Completing any burst (or any session that tosses ≥ 1 photo) marks today complete; if yesterday was complete, `streakCount += 1`, else reset logic runs first.
- **Freeze:** every 7th consecutive day earns one (cap 3). On a missed single day, silently consume a freeze to bridge the gap; only reset to 1 when no freezes remain. Settings shows "Freezes ready: N" with the earn rule as a footnote.

**Daily reminder:** Settings toggle → request `UNUserNotificationCenter` authorization on first enable (handle denial with the Open Settings pattern from the permission screen). Schedule one repeating calendar notification (default 19:00, editable with a time picker). Copy: "Your gallery has leftovers 🧹 2 minutes of swiping?" On every app open, cancel/reschedule so it only fires **if today's burst isn't done** (re-register on `scenePhase == .background`, skip when complete — "only if you haven't played").

---

## Phase 5 — Plus (StoreKit 2) + paywall

**Product:** `leftover.plus` — start subscription-simple: monthly + a lifetime one-time purchase (parents understand "buy once").
**Free tier:** classic album swiping stays **fully free** (the app's soul, and it already shipped free). Plus gates the *new* power features: unlimited daily bursts (free = 1/day), Duplicates and Large Videos engines (free shows counts + first group/video as a teaser), future widget.
**Logic:** `EntitlementStore` (ObservableObject) wrapping StoreKit 2 — `Transaction.currentEntitlements` on launch, `Transaction.updates` listener, `purchase()`/`AppStore.sync()` for Restore. No receipts server; StoreKit 2 verification is local.
**Paywall flow:** burst-complete sheet (primary placement, exactly like the reference: cream primary button "Go unlimited with Plus", quiet "Maybe tomorrow") and gated-tile taps → `PaywallView`: feature list with KEEP-stamp bullets, price, subscribe/lifetime buttons, Restore, Terms/Privacy links. Settings gets "Leftover Plus" section (Get / Restore).
**Rules:** never gate deletion of something already marked; never interrupt mid-review; paywall only at natural pauses.

---

## Phase 6 — Settings & trust panel

Single `SettingsView` (List/Form, `Theme.paper` grouped style):
1. **Daily reminder** — toggle + time picker + footnote (Phase 4).
2. **Leftover Plus** — Get Plus row (crown/sparkle icon, subtitle "Unlimited bursts, duplicates, and more") / Restore Purchases.
3. **Streak** — Freezes ready: N + earn rule footnote.
4. **Sharing** — "Add a Leftover line when I share" toggle (Phase 7).
5. **Privacy panel** (static trust rows, safelight icons): "Everything stays on this iPhone" · "Your photos are never uploaded" · "Deletions are always yours to confirm". Mirrors the splash promise; parents-facing reassurance.
6. **About** — Version (from bundle), Rate Leftover (`SKStoreReviewController` / App Store write-review URL), Send feedback (`mailto:` with device/version prefilled), Privacy policy, Terms (hosted as simple GitHub Pages, required for IAP review).

Entry: gear on Home. Presented as a sheet with Done, like the reference.

---

## Phase 7 — Share footer

When sharing from the review action bar and the toggle is on, the share sheet gets a second `activityItem` string: "Sorted with Leftover 🧹" + App Store link. The photo itself is untouched — copy in Settings says exactly that ("never watermarked or changed; a short line of text you can edit or delete before sending").

---

## Build order & why

| # | Phase | Depends on | Size | Rationale |
|---|---|---|---|---|
| 1 | 0 Foundation | — | M | Everything else lands on it |
| 2 | 2 Review upgrades | 0 | M | Improves the existing core for all future flows |
| 3 | 3a Screenshot Sweep | 0 | S | Biggest value/effort ratio; validates category → session plumbing |
| 4 | 1 Home | 0, 3a | M | Needs at least one real tile to not feel empty |
| 5 | 3d Burst + 4 Streak | 1 | M | The habit loop; reminder rides along |
| 6 | 3b Large Videos | 3a | M | Extends engine to videos |
| 7 | 3c Duplicates | cache infra | L | Hardest (perf); ship behind a progress UI |
| 8 | 6 Settings | 4 | S | Needs reminder + streak to have content |
| 9 | 5 Plus/paywall | 5–8 | L | Monetize only once the habit loop is real |
| 10 | 7 Share footer | 2 | XS | One toggle + one activity item |

**Cross-cutting rules:** every new PhotoKit call follows the audit-era patterns (background queue → main-thread publish, no stale `PHAsset` snapshots, batch deletes only, every failure gets a toast). Every screen supports full Dynamic Type and both themes via `Theme` tokens. Each phase is verified on-device against its flow before starting the next, plus the standing regressions: empty album, permission denied, delete-cancel.

**App Store prerequisites** (from `appledeveloperplan.md` track): privacy policy + terms URLs before Phase 5; App Privacy questionnaire stays "data not collected"; IAP review needs the paywall to show price, term, and restore.
