# Launch playbook

Companion to `APPSTORE.md` (store listing). This is the go-to-market
side: what to do before, during, and after the App Store release.
Everything assumes one person with zero budget — leverage over spend.

## Positioning (one sentence, use it everywhere)

> **Leftover makes clearing your camera roll feel like a game — swipe
> left to delete, watch the gigabytes come back. No cloud, no account,
> no ads.**

Angles that hook, in order of strength:
1. **The number** — "I freed 12 GB in 20 minutes" is the whole pitch.
2. **The feeling** — Tinder-for-photos is instantly understood.
3. **The trust** — "Data Not Collected" label; every competitor is
   ad-funded. Lead with this in privacy-minded communities.
4. **The story** — one person, 40,000 photos, a full iPhone. Built it.

## Phase 1 — Pre-launch (2–3 weeks before)

- [ ] **TestFlight beta.** Push a build, invite ~20 people (friends +
  r/TestFlight + X followers). Two goals: crash-free sessions on real
  devices, and 5–10 people primed to rate/review on day one. Ask each
  tester one question only: "where did you stop swiping and why?"
- [ ] **Build in public on X** (@whysokara already exists). 2–3 posts a
  week: screen recordings of the swipe physics, the celebration, the
  cover flow. Motion is the asset — the app demos itself. End each
  clip with the freed-space number. No hashtag soup; one clean line.
- [ ] **Record the money shot** once on a real device: a 20-second
  screen recording — messy library → swiping with haptics → "2.3 GB
  freed" celebration → Share. This one clip is reused everywhere:
  App Store preview, TikTok, PH gallery, Reddit comments.
- [ ] **Seed a demo library** on a spare device/sim for clean captures:
  recognizable duplicates, burst series, blurry shots, screenshots.

## Phase 2 — Launch week

Concentrate everything in a 3–4 day window; the algorithms on every
platform reward momentum.

**Day 1 — App Store live + X thread.**
The thread structure that works for indie launches:
1. Hook: the before/after number ("My iPhone had 40,000 photos and 400
   MB free. So I built this.")
2. The 20-second demo clip.
3. 3–4 tweets, one feature each (swipe physics / duplicates / health
   score / privacy) — each with a clip or screenshot.
4. The story tweet (one person, X months, SwiftUI).
5. Link + "it's free."

**Day 2 — Reddit.** One post per community, native tone, *never* the
same text twice. Lead with the story or the number, mention the app in
the body, link only in a comment if the sub requires it. Targets:
- r/iosapps, r/apple ("Apps" Saturday thread), r/iphone — direct.
- r/SideProject, r/indiedev, r/iOSProgramming — the build story
  (SwiftUI, no dependencies, PhotoKit gotchas — devs upvote craft).
- r/declutter, r/minimalism — the outcome angle, no dev talk.
- Rule zero: read each sub's self-promo rules first; a removed post
  burns the account for future launches.

**Day 3 — Product Hunt.**
- Launch 12:01 AM PT. Tagline = the positioning sentence. Gallery =
  the 6 store screenshots + the demo clip first.
- First comment: the story + honest "what's next" + ask for feedback
  (not upvotes — PH punishes vote solicitation).
- Reply to every comment same-day; comment velocity matters as much
  as votes.
- Realistic goal: top-10 of the day → a durable badge + backlink.

**Day 4 — Directories & press.**
- Submit to: AlternativeTo, There's An App For That, tools directories.
- Email 5–6 Apple-ecosystem writers (9to5Mac, MacStories, iMore tip
  lines) — two sentences + the clip + a promo code. MacStories in
  particular loves polished indie + privacy-first.

## Phase 3 — The TikTok/Reels lane (ongoing, highest ceiling)

"Cleaning my camera roll" is an established content genre (CleanTok,
digital-minimalism). The app is a native fit — the swipe is literally
watchable.

- **Own account**: post the demo loop + "oddly satisfying" cuts of the
  celebration. 3 posts/week for a month beats 1 viral attempt.
- **Micro-influencers (1k–50k followers)** in #cleantok,
  #digitalminimalism, #iphonetips: DM 10–20 with a free promo code and
  one line — template:
  > "Hey — I made a free iOS app that makes cleaning your camera roll
  > feel like Tinder (swipe left to delete). Your camera-roll videos
  > made me think your audience would enjoy it. Want a code? No
  > strings — post only if you actually like it."
- The **Share pill** in the celebration is the UGC engine: every
  share is a story-sized brag with the link attached. Watch which
  channels shares land in and double down there.

## Phase 4 — Post-launch loop (weekly, 30 min)

- **Reviews:** reply to every App Store review (replies are public and
  signal care; also a re-rating prompt for updated reviews).
- **ASO iteration:** check keyword rankings; rotate the 99-char keyword
  field every 2–4 weeks based on what's moving (see APPSTORE.md).
  Test one hypothesis per release.
- **What's New as marketing:** every update's notes sell one feature in
  plain voice — indexed by nobody, read by everybody on the update
  screen.
- **Milestone posts:** "Leftover users have freed 1 TB total" — the
  App-Group stats mirror makes this number real when the widget ships.

## What NOT to do

- No paid installs at launch — wasted before organic conversion is
  proven; revisit only if the funnel converts (>30% product-page CVR).
- No fake/incentivized reviews — Apple's #1 takedown trigger, and the
  cleaner category is already watched closely.
- No competitor names in keywords or copy (rejection + looks desperate).
- No launch before a real-device TestFlight pass — deletion is the core
  flow and it only truly works on hardware.
- Don't spread the launch over weeks. Compressed beats prolonged.

## Success metrics (first 30 days, sane targets)

| Metric | Floor | Good |
|---|---|---|
| Impressions → product page CVR | 3% | 6%+ |
| Product page → install CVR | 25% | 40%+ |
| Day-1 retention | 25% | 40% |
| Ratings count | 20 | 100+ |
| Average rating | 4.3 | 4.7+ |
| Keyword: "photo cleaner" rank | top 50 | top 20 |
