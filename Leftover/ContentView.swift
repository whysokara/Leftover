import SwiftUI
import Photos
import PhotosUI
import StoreKit
import UIKit

enum SessionSource {
    case album, burst, screenshots, blurry
}

/// Where a review session was launched from — exits return here.
enum SessionOrigin {
    case home, albums
}

struct ContentView: View {
    @State private var photoAssets: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var toBeDeleted: [PHAsset] = []
    @State private var totalSize: Int64 = 0
    @State private var showDeleteButton = false
    @State private var showAlbumPicker = false
    @State private var selectedAlbum: PHAssetCollection? = nil
    @State private var currentAsset: PHAsset? = nil
    @State private var isDeleting = false
    @State private var isLoadingPhotos = false
    @State private var isLoadingAlbums = false
    @State private var photoAuthStatus: PHAuthorizationStatus = .notDetermined
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""
    @State private var allPhotosThumbnail: UIImage?
    @State private var allPhotosCount: Int = 0
    @State private var sortedAlbums: [AlbumMeta] = []
    @State private var pulse = false
    // The splash shows on every cold launch: first launch keeps the
    // Start button, returning launches auto-dissolve into home.
    @State private var showSplashScreen = true
    private let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    // Onboarding: first launch (after Start) or replayed from Settings.
    // While it's up, homeView never appears, so its permission request
    // waits until the primer has done its job.
    @State private var showOnboarding = false
    @State private var pendingOnboardingReplay = false
    @State private var onboardingInitialStep = 0
    // Genuine first run (splash Start), not a Settings replay — used to
    // drop the user into their first cleanup once onboarding finishes.
    @State private var isFirstRunOnboarding = false
    @State private var pendingFirstCleanup = false

    @StateObject private var stats = Stats()
    @StateObject private var notifications = NotificationManager()
    @State private var sessionSource: SessionSource = .album
    @State private var sessionOrigin: SessionOrigin = .home
    @State private var sessionActive = false
    @State private var showBurstComplete = false
    @State private var showSettings = false
    @State private var isLoadingHome = false
    @State private var screenshotAssets: [PHAsset] = []
    /// Bytes the screenshot pile would free — computed in a trailing
    /// background pass so the first Home paint never waits on
    /// PHAssetResource lookups for thousands of assets.
    @State private var screenshotBytes: Int64 = 0
    /// Screenshots older than 30 days — a health-score input.
    @State private var staleScreenshotCount = 0
    @State private var showHealth = false
    @State private var showTrophies = false
    @State private var burstAssets: [PHAsset] = []
    @State private var videoCount = 0
    @State private var recentAssets: [PHAsset] = []
    @StateObject private var libraryScanner = LibraryScanner()
    @StateObject private var libraryMonitor = LibraryChangeMonitor()
    @State private var showLargeVideos = false
    @State private var showDuplicates = false
    @State private var showSimilar = false
    @State private var showBlurryScan = false
    @State private var largeVideos: [VideoItem] = []
    @State private var largeVideosShowingAll = false
    @Environment(\.scenePhase) private var scenePhase

    // Swipe-card physics: offset follows the finger, then animates the
    // card off-screen (throw) or back to center (settle).
    @State private var cardOffset: CGSize = .zero
    @State private var isThrowingCard = false
    @State private var showExitAlert = false
    @State private var showPillConfirm = false
    @State private var dealtIn = true
    @State private var burstTeaser: String? = nil
    @State private var deleteCelebration: DeleteCelebration?

    var body: some View {
        ZStack {
            Theme.stage.ignoresSafeArea()

            if showSplashScreen {
                splashScreenView
            } else if showOnboarding {
                OnboardingView(initialStep: onboardingInitialStep) {
                    // On a genuine first run that ended with access granted,
                    // hand straight into the first cleanup (armed here,
                    // fired once loadHomeData has the burst assets) instead
                    // of resting on Home. Replays just dismiss.
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if isFirstRunOnboarding && (status == .authorized || status == .limited) {
                        pendingFirstCleanup = true
                    }
                    isFirstRunOnboarding = false
                    withAnimation(Theme.settle) { showOnboarding = false }
                }
                .transition(pushTransition)
            } else if showAlbumPicker {
                albumPickerView
                    .transition(pushTransition)
            } else if isLoadingPhotos {
                ProgressView("Opening \(selectedAlbum?.localizedTitle ?? "All Photos")…")
                    .foregroundColor(Theme.dim)
            } else if sessionActive && currentIndex < photoAssets.count {
                swipeCard
                    .transition(pushTransition)
            } else if sessionActive && showDeleteButton {
                deleteConfirmation
                    .transition(settleTransition)
            } else if sessionActive {
                emptyAlbumView
                    .transition(settleTransition)
            } else if showBurstComplete {
                burstCompleteView
                    .transition(settleTransition)
            } else if showLargeVideos {
                LargeVideosView(
                    videos: largeVideos,
                    showingAllSizes: largeVideosShowingAll,
                    onClose: {
                        withAnimation(Theme.settle) { showLargeVideos = false }
                    },
                    onToss: { assets, freed in
                        performBatchDelete(assets, freed: freed, category: .videos) {
                            let ids = Set(assets.map(\.localIdentifier))
                            largeVideos.removeAll { ids.contains($0.id) }
                            videoCount = max(videoCount - assets.count, 0)
                        }
                    }
                )
                .transition(pushTransition)
            } else if showDuplicates {
                GroupReviewView(
                    scanner: libraryScanner,
                    mode: .duplicates,
                    onClose: {
                        withAnimation(Theme.settle) { showDuplicates = false }
                    },
                    onToss: { assets, freed in
                        performBatchDelete(assets, freed: freed, category: .duplicates) {
                            libraryScanner.removeAssets(withIdentifiers: Set(assets.map(\.localIdentifier)))
                        }
                    }
                )
                .transition(pushTransition)
            } else if showSimilar {
                GroupReviewView(
                    scanner: libraryScanner,
                    mode: .similar,
                    onClose: {
                        withAnimation(Theme.settle) { showSimilar = false }
                    },
                    onToss: { assets, freed in
                        performBatchDelete(assets, freed: freed, category: .similar) {
                            libraryScanner.removeAssets(withIdentifiers: Set(assets.map(\.localIdentifier)))
                        }
                    }
                )
                .transition(pushTransition)
            } else if showBlurryScan {
                blurryScanScreen
                    .transition(pushTransition)
            } else {
                homeView
                    .transition(.opacity)
            }

            if isDeleting {
                ProgressView("Deleting…")
                    .tint(Theme.ink)
                    .foregroundColor(Theme.ink)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
            }

            if showSnackbar {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Theme.cream)
                            .frame(width: 8, height: 8)
                        Text(snackbarMessage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.ink)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 14, y: 4)
                    .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let moment = momentContent {
                momentView(moment)
                    .transition(.opacity)
                    .zIndex(2)
            }

            // The payoff: tossed photos get swallowed by the spotlight.
            if let celebration = deleteCelebration {
                DeleteBlastView(celebration: celebration) {
                    withAnimation(Theme.settle) { deleteCelebration = nil }
                    // Peak-joy moment: they just watched space get freed.
                    // The gate inside keeps this rare and Apple-compliant.
                    maybeRequestReview()
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: currentIndex) { newIndex in
            if newIndex < photoAssets.count {
                currentAsset = photoAssets[newIndex]
            }
        }
        .onChange(of: scenePhase) { phase in
            // Reminder only fires if today's burst isn't done — refresh on
            // every backgrounding so completing a burst cancels the nudge,
            // and feed it the freshest copy hooks.
            if phase == .background {
                persistSessionIfNeeded()
                notifications.burstTeaser = burstTeaser
                notifications.reschedule(burstDoneToday: stats.isBurstDoneToday)
            }
        }
        .onChange(of: libraryMonitor.changeToken) { _ in
            // The library changed under us (Photos delete, iCloud sync,
            // AirDrop). Refresh Home's counts when idle; an active swipe
            // session is left alone.
            guard photoAuthStatus == .authorized || photoAuthStatus == .limited,
                  !sessionActive, !isDeleting else { return }
            loadHomeData()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(notifications: notifications, stats: stats,
                         onReplayOnboarding: {
                             pendingOnboardingReplay = true
                             showSettings = false
                         })
        }
        .onChange(of: showSettings) { open in
            // Start the replay only once the sheet has actually gone,
            // so the two presentations don't race each other.
            guard !open, pendingOnboardingReplay else { return }
            pendingOnboardingReplay = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onboardingInitialStep = 0
                withAnimation(Theme.settle) { showOnboarding = true }
            }
        }
        .sheet(isPresented: $showHealth) {
            HealthDetailView(health: healthScore) { partID in
                // Deep-link: close the sheet, then open the screen that
                // fixes that part of the score.
                showHealth = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    switch partID {
                    case "duplicates":
                        withAnimation(Theme.settle) { showDuplicates = true }
                    case "similar":
                        withAnimation(Theme.settle) { showSimilar = true }
                    case "blurry":
                        openBlurry()
                    case "screenshots":
                        startSession(.screenshots, assets: screenshotAssets)
                    case "videos":
                        withAnimation(Theme.settle) { showLargeVideos = true }
                    default:
                        break
                    }
                }
            }
        }
        .sheet(isPresented: $showTrophies) {
            TrophyShelfView(achieved: stats.achievedMilestones)
        }
        .onChange(of: libraryScanner.hasScanned) { done in
            // A scan launched from the Blurry row flows straight into
            // the review session once it finishes.
            guard done, showBlurryScan else { return }
            showBlurryScan = false
            startBlurrySession()
        }
    }

    // MARK: - Screen transitions (crossfade under Reduce Motion)

    private var pushTransition: AnyTransition {
        UIAccessibility.isReduceMotionEnabled
            ? .opacity
            : .move(edge: .trailing).combined(with: .opacity)
    }

    private var settleTransition: AnyTransition {
        UIAccessibility.isReduceMotionEnabled
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.97))
    }

    // MARK: - Milestone & weekly recap moments

    private var momentContent: (title: String, subtitle: String, isMilestone: Bool)? {
        guard !sessionActive, !isDeleting, !showSplashScreen else { return nil }
        if let milestone = stats.pendingMilestone {
            return ("\(milestone).", "Keep going.", true)
        }
        if let recap = stats.pendingRecap {
            return ("Last week.", recap, false)
        }
        return nil
    }

    private func momentView(_ moment: (title: String, subtitle: String, isMilestone: Bool)) -> some View {
        VStack(spacing: 16) {
            Image(systemName: moment.isMilestone ? "trophy.fill" : "calendar")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 84, height: 84)
                .background(Circle().fill(moment.isMilestone ? Theme.chipYellow : Theme.chipPurple))
                .shadow(color: (moment.isMilestone ? Theme.chipYellow : Theme.chipPurple).opacity(0.4), radius: 22)

            Text(moment.title)
                .font(Theme.display(30))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)

            Text(moment.subtitle)
                .font(.subheadline)
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)

            Button("Done") {
                withAnimation(Theme.settle) {
                    if moment.isMilestone {
                        stats.clearMilestone()
                    } else {
                        stats.clearRecap()
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 64)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage.ignoresSafeArea())
        .onAppear { Haptics.success() }
    }

    var blurryScanScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                BackButton {
                    withAnimation(Theme.settle) { showBlurryScan = false }
                }

                Text("Blurry")
                    .font(Theme.title)
                    .foregroundColor(Theme.ink)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()
            ScanProgress(scanner: libraryScanner)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Opaque like every other full-screen view: without this the push
        // transition slid a see-through panel over the outgoing screen.
        .background(Theme.stage)
        .edgeSwipeBack {
            withAnimation(Theme.settle) { showBlurryScan = false }
        }
    }

    func startBlurrySession() {
        if libraryScanner.blurryAssets.isEmpty {
            showToast("No blurry photos found.")
        } else {
            startSession(.blurry, assets: libraryScanner.blurryAssets)
        }
    }

    func openBlurry() {
        if libraryScanner.hasScanned {
            startBlurrySession()
        } else {
            withAnimation(Theme.settle) { showBlurryScan = true }
            // A restore in flight will flip hasScanned itself, and the
            // onChange above flows straight into the session — no need to
            // burn a scan that the stored results would have answered.
            if !libraryScanner.isRestoring { libraryScanner.scan() }
        }
    }

    private func scanDetail(count: Int) -> String {
        guard libraryScanner.hasScanned else { return "Scan" }
        if count == 0 { return "None" }
        return count.formatted()
    }

    /// Recomputed from live scanner/home state — deleting clutter or
    /// receiving new clutter moves it on the next Home refresh.
    private var healthScore: HealthScore {
        HealthScore.compute(
            libraryCount: recentAssets.count,
            duplicateCount: libraryScanner.duplicateGroups.reduce(0) { $0 + max($1.assets.count - 1, 0) },
            similarCount: libraryScanner.similarGroups.reduce(0) { $0 + max($1.assets.count - 1, 0) },
            blurryCount: libraryScanner.blurryAssets.count,
            staleScreenshots: staleScreenshotCount,
            videoBytes: largeVideos.reduce(0) { $0 + $1.size },
            hasScanned: libraryScanner.hasScanned)
    }

    var splashScreenView: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                NeonCardMark(size: 92)
                    // A gentle hover — the mark floats and sways so it
                    // reads as alive, not a static logo. A thin neon
                    // outline barely shows a scale breath, so this leans on
                    // travel + rotation instead. Driven by the wordmark's
                    // pulse state and gated on Reduce Motion the same way.
                    .rotationEffect(.degrees(pulse ? 2.5 : -2.5))
                    .offset(y: pulse ? -8 : 6)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: pulse)
                    .padding(.bottom, 16)

                VStack(spacing: 0) {
                    Text("Leftover")
                        .font(Theme.wordmark(46))
                        .foregroundColor(Theme.ink)
                        .scaleEffect(pulse ? 1.0 : 0.96)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                        .background(
                            // A whisper of a vignette behind the black wordmark.
                            RadialGradient(colors: [Theme.ink.opacity(0.06), .clear],
                                           center: .center, startRadius: 10, endRadius: 220)
                                .frame(width: 440, height: 440)
                        )
                        .onAppear {
                            // The only repeat-forever motion in the app —
                            // stays still under Reduce Motion.
                            if !UIAccessibility.isReduceMotionEnabled {
                                pulse = true
                            }
                        }

                    // Serif title's line-height leaves a lot of built-in
                    // space below the baseline — pull the subtitle up so
                    // the gap reads as intentional, not accidental.
                    Text("Swipe right to keep, left to delete.")
                        .font(.footnote)
                        .foregroundColor(Theme.dim.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.top, -4)
                }
            }
            .padding(.bottom, Theme.Space.xl)

            if isFirstLaunch {
                Button("Start") {
                    stats.hasLaunchedBefore = true
                    isFirstRunOnboarding = true
                    withAnimation(Theme.settle) {
                        showSplashScreen = false
                        // First launch flows through onboarding before
                        // Home (and its permission request) appears.
                        showOnboarding = true
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 64)
            }

            Spacer()

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Built by")
                        .font(.footnote)
                        .foregroundColor(Theme.dim)

                    if let url = URL(string: "https://x.com/whysokara") {
                        Link("Kara", destination: url)
                            .font(.footnote)
                            .foregroundColor(Theme.cream)
                            .underline()
                    } else {
                        Text("Kara")
                            .font(.footnote)
                            .foregroundColor(Theme.cream)
                    }
                }

                Text("No signup. We don’t collect any data.")
                    .font(.footnote)
                    .foregroundColor(Theme.dim)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Built by Kara. No signup required. We don’t collect any data.")
            .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 60 : 32)
        }
        .multilineTextAlignment(.center)
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            // Returning users can skip the brand moment.
            guard !isFirstLaunch else { return }
            withAnimation(Theme.settle) { showSplashScreen = false }
        }
        .onAppear {
            guard !isFirstLaunch else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(Theme.settle) { showSplashScreen = false }
            }
        }
        .opacity(showSplashScreen ? 1 : 0)
        .scaleEffect(showSplashScreen ? 1 : 0.96)
        .animation(.easeInOut(duration: 0.3), value: showSplashScreen)
    }

    var homeView: some View {
        Group {
            if photoAuthStatus == .denied || photoAuthStatus == .restricted {
                permissionDeniedView
            } else {
                HomeView(
                    freedBytes: stats.lifetimeFreedBytes,
                    burstDetail: stats.isBurstDoneToday
                        ? "Done today"
                        : (burstAssets.isEmpty ? "None" : burstAssets.count.formatted()),
                    burstDimmed: stats.isBurstDoneToday || burstAssets.isEmpty,
                    previews: CardPreviews(
                        burst: Array(burstAssets.prefix(4)),
                        duplicates: Array(libraryScanner.duplicateGroups.prefix(2).flatMap(\.assets).prefix(4)),
                        similar: Array(libraryScanner.similarGroups.prefix(2).flatMap(\.assets).prefix(4)),
                        screenshots: Array(screenshotAssets.prefix(4)),
                        blurry: Array(libraryScanner.blurryAssets.prefix(4)),
                        videos: Array(largeVideos.prefix(4)).map(\.asset),
                        albums: Array(recentAssets.prefix(4))
                    ),
                    screenshotCount: screenshotAssets.count,
                    videoCount: videoCount,
                    duplicateBytes: libraryScanner.duplicateGroups.reduce(0) { $0 + $1.wastedBytes },
                    similarBytes: libraryScanner.similarGroups.reduce(0) { $0 + $1.wastedBytes },
                    screenshotBytes: screenshotBytes,
                    blurryBytes: libraryScanner.blurryBytes,
                    videoBytes: largeVideos.reduce(0) { $0 + $1.size },
                    duplicateDetail: scanDetail(count: libraryScanner.duplicateGroups.count),
                    similarDetail: scanDetail(count: libraryScanner.similarGroups.count),
                    blurryDetail: scanDetail(count: libraryScanner.blurryAssets.count),
                    recentAssets: recentAssets,
                    isLoading: isLoadingHome,
                    isLimitedAccess: photoAuthStatus == .limited,
                    healthScore: healthScore,
                    onHealth: { showHealth = true },
                    onTrophies: { showTrophies = true },
                    onSettings: { showSettings = true },
                    onManageLimited: { presentLimitedLibraryPicker() },
                    onStartBurst: { startSession(.burst, assets: burstAssets) },
                    onScreenshots: { startSession(.screenshots, assets: screenshotAssets) },
                    onDuplicates: {
                        withAnimation(Theme.settle) { showDuplicates = true }
                    },
                    onSimilar: {
                        withAnimation(Theme.settle) { showSimilar = true }
                    },
                    onBlurry: { openBlurry() },
                    onLargeVideos: {
                        withAnimation(Theme.settle) { showLargeVideos = true }
                    },
                    onAlbums: {
                        withAnimation(Theme.settle) { showAlbumPicker = true }
                    },
                    onRecent: { index in loadPhotos(startAt: index, origin: .home) },
                    onComingSoon: { message in showToast(message) }
                )
            }
        }
        .onAppear {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    self.photoAuthStatus = status
                    if status == .authorized || status == .limited {
                        // Pick an interrupted session (killed in the
                        // background with marks pending) back up first.
                        if !self.sessionActive {
                            _ = self.restoreSavedSessionIfAny()
                        }
                        self.loadHomeData()
                        // Bring back the last scan's duplicate/similar/blurry
                        // products so those screens open instantly; quietly
                        // refreshes only if the library actually moved.
                        self.libraryScanner.restoreThenRefreshIfStale()
                        #if DEBUG
                        // Headless-verification hooks (simctl launch … -Leftover…).
                        let args = ProcessInfo.processInfo.arguments
                        if args.contains("-LeftoverFirstRunCleanup"), !self.sessionActive {
                            // Exercises the first-run handoff: loadHomeData
                            // (already kicked off above) fires startSession
                            // once the burst is in hand.
                            self.pendingFirstCleanup = true
                        } else if args.contains("-LeftoverResumeSeed"), !self.sessionActive {
                            // Opens All Photos the way the picker does, then
                            // fakes four keeps so a later launch has progress
                            // to resume from.
                            self.loadPhotos(resumeAlbum: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                for _ in 0..<4 where self.currentIndex < self.photoAssets.count {
                                    self.commitSwipe(toss: false, asset: self.photoAssets[self.currentIndex])
                                }
                            }
                        } else if args.contains("-LeftoverResumeCheck"), !self.sessionActive {
                            // Same entry point, but never swipes — whatever
                            // position shows is purely what resume restored.
                            self.loadPhotos(resumeAlbum: true)
                        } else if args.contains("-LeftoverMixDemo"), !self.sessionActive {
                            self.loadPhotos(origin: .home)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                for i in 0..<5 where self.currentIndex < self.photoAssets.count {
                                    self.commitSwipe(toss: i % 2 == 0,
                                                     asset: self.photoAssets[self.currentIndex])
                                }
                            }
                        } else if args.contains("-LeftoverAutoSession"), !self.sessionActive {
                            self.loadPhotos(origin: .home)
                        } else if args.contains("-LeftoverOpenDuplicates") {
                            self.showDuplicates = true
                        } else if args.contains("-LeftoverOpenLargeVideos") {
                            self.showLargeVideos = true
                        } else if args.contains("-LeftoverOpenSimilar") {
                            self.showSimilar = true
                        } else if args.contains("-LeftoverOpenBlurry") {
                            self.openBlurry()
                        } else if args.contains("-LeftoverOpenSettings") {
                            self.showSettings = true
                        } else if args.contains("-LeftoverOpenHealth") {
                            self.showHealth = true
                        } else if args.contains("-LeftoverOpenTrophies") {
                            self.showTrophies = true
                        } else if args.contains("-LeftoverShowOnboarding") {
                            self.onboardingInitialStep = 0
                            self.showOnboarding = true
                        } else if args.contains("-LeftoverOnboardingStep2") {
                            self.onboardingInitialStep = 1
                            self.showOnboarding = true
                        } else if args.contains("-LeftoverOnboardingStep3") {
                            self.onboardingInitialStep = 2
                            self.showOnboarding = true
                        } else if args.contains("-LeftoverBlastDemo") {
                            // Preview the delete celebration without deleting.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                let demo = Array(self.recentAssets.prefix(5))
                                self.prefetchThumbnails(of: demo) { images in
                                    withAnimation(Theme.settle) {
                                        self.deleteCelebration = DeleteCelebration(
                                            images: images, count: 23, freed: 148_000_000)
                                    }
                                }
                            }
                        }
                        #endif
                    }
                }
            }
        }
    }

    @State private var celebrationScale: CGFloat = 0.4

    var burstCompleteView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Theme.chipOrange))
                .scaleEffect(celebrationScale)
                .shadow(color: Theme.chipOrange.opacity(0.45), radius: 24)
                .background(
                    // The spotlight blooms open behind the celebration.
                    RadialGradient(colors: [Theme.cream.opacity(0.16), .clear],
                                   center: .center, startRadius: 8, endRadius: 250)
                        .frame(width: 500, height: 500)
                        .scaleEffect(celebrationScale)
                )
                .onAppear {
                    celebrationScale = 0.4
                    withAnimation(Theme.pop) { celebrationScale = 1.0 }
                }

            Text("Done for Today")
                .font(Theme.display(30))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)

            Text("Come back tomorrow.")
                .font(.subheadline)
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Done") {
                withAnimation(Theme.settle) { returnHome() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 64)
            .padding(.top, 8)
        }
        .padding()
    }

    var albumPickerView: some View {
        NavigationStack {
            Group {
                if photoAuthStatus == .denied || photoAuthStatus == .restricted {
                    permissionDeniedView
                } else {
                    albumGrid
                }
            }
            .background(Theme.stage)
            .navigationTitle("Albums")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Same close idiom as every other full-screen list.
                    BackButton {
                        withAnimation(Theme.settle) {
                            showAlbumPicker = false
                        }
                    }
                }
            }
            .onAppear {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    DispatchQueue.main.async {
                        self.photoAuthStatus = status
                        if status == .authorized || status == .limited {
                            self.fetchAlbums()
                        }
                    }
                }
            }
        }
    }

    var albumGrid: some View {
        ScrollView {
            if photoAuthStatus == .limited {
                HStack {
                    Text("Showing only the photos you’ve shared.")
                        .font(.footnote)
                        .foregroundColor(Theme.dim)
                    Spacer()
                    Button("Manage") {
                        presentLimitedLibraryPicker()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Theme.cream)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {

                // All Photos tile
                AlbumGridItem(
                    title: "All Photos",
                    count: allPhotosCount,
                    thumbnail: allPhotosThumbnail
                ) {
                    self.selectedAlbum = nil
                    self.showAlbumPicker = false
                    self.loadPhotos(resumeAlbum: true)
                }

                // Album List
                ForEach(sortedAlbums, id: \.collection.localIdentifier) { albumMeta in
                    AlbumGridItem(
                        title: albumMeta.collection.localizedTitle ?? "Unnamed",
                        count: albumMeta.assetCount,
                        thumbnail: albumMeta.thumbnail
                    ) {
                        self.selectedAlbum = albumMeta.collection
                        self.showAlbumPicker = false
                        self.loadPhotos(from: albumMeta.collection, resumeAlbum: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            if isLoadingAlbums && sortedAlbums.isEmpty {
                ProgressView()
                    .padding(.top, 40)
            }
        }
    }

    var permissionDeniedView: some View {
        VStack(spacing: 12) {
            LeftoverBuddy(color: Theme.chipPurple, expression: .sleepy)

            Text("Leftover needs your library")
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            Text("Allow photo access in Settings. Nothing ever leaves your phone.")
                .font(.subheadline)
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 64)
            .padding(.top, 8)
        }
    }

    var emptyAlbumView: some View {
        VStack(spacing: 12) {
            LeftoverBuddy(color: Theme.chipOrange, expression: .happy)

            Text("Nothing to Review")
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            Text("This album is already clean.")
                .font(.subheadline)
                .foregroundColor(Theme.dim)

            Button(sessionOrigin == .albums ? "Albums" : "Home") {
                withAnimation(Theme.settle) {
                    if sessionOrigin == .albums {
                        resetToAlbumPicker()
                    } else {
                        returnHome()
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 64)
            .padding(.top, 8)
        }
    }



    // MARK: - Swipe screen (the theater)

    var swipeCard: some View {
        ZStack {
            // Edge glows — the decision colors bleed in from the screen
            // edges as the card is dragged toward them.
            HStack(spacing: 0) {
                LinearGradient(colors: [Theme.toss.opacity(0.55), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 110)
                    .opacity(dragProgress(-cardOffset.width))
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, Theme.keep.opacity(0.55)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 110)
                    .opacity(dragProgress(cardOffset.width))
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                reviewTopBar
                sessionContextLine

                Spacer(minLength: 8)

                cardStack

                if let asset = currentAsset {
                    photoCaption(asset)
                }

                Spacer(minLength: 8)

                if !toBeDeleted.isEmpty {
                    tossNowPill
                }

                actionDock
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .edgeSwipeBack { endSessionTapped() }
        .alert("Delete \(toBeDeleted.count) Photos?", isPresented: $showExitAlert) {
            Button("Delete", role: .destructive) {
                deleteMarkedPhotos()
            }
            Button("Keep All") {
                withAnimation(Theme.settle) { exitSession() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This frees \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)). They'll stay in Recently Deleted for 30 days, so you can still restore them from Photos.")
        }
        .alert("Delete \(toBeDeleted.count) Photos?", isPresented: $showPillConfirm) {
            Button("Delete", role: .destructive) {
                deleteMarkedPhotos()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This frees \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)). They'll stay in Recently Deleted for 30 days, so you can still restore them from Photos.")
        }
        .onAppear {
            DispatchQueue.main.async { dealtIn = true }
        }
    }

    private func dragProgress(_ distance: CGFloat) -> Double {
        Double(min(max(distance - 24, 0) / 220, 1))
    }

    // Shared by the "End session" button and the edge-swipe-back gesture —
    // both need the same "confirm if something's marked" behavior.
    private func endSessionTapped() {
        if toBeDeleted.isEmpty {
            withAnimation(Theme.settle) { exitSession() }
        } else {
            showExitAlert = true
        }
    }

    private var reviewTopBar: some View {
        HStack(spacing: 14) {
            BackButton(label: "End session") {
                endSessionTapped()
            }

            decisionRibbon
                .frame(height: 40)
                .accessibilityElement()
                .accessibilityLabel("Reviewed \(currentIndex) of \(photoAssets.count), \(toBeDeleted.count) marked to delete")

            // Bare text, not a glass pill — this is the secondary escape
            // hatch, and a chunky capsule competed with the photo.
            Button("Keep all") {
                keepAll()
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(Theme.dim)
            .padding(.horizontal, 4)
            .frame(height: 44)
            .contentShape(Rectangle())
            .accessibilityHint("Keeps every remaining photo and ends the session")
        }
    }

    /// The progress bar as a record of decisions: one segment per photo —
    /// coral where you deleted, teal where you kept, cream for the one in
    /// hand. Reads as a ribbon of what you've done, not just how far you
    /// are. Long sessions fall back to a single bar; 500 segments is mush.
    private var decisionRibbon: some View {
        let marked = Set(toBeDeleted.map(\.localIdentifier))
        return GeometryReader { geo in
            Group {
                if photoAssets.count <= 24 {
                    HStack(spacing: 3) {
                        ForEach(Array(photoAssets.enumerated()), id: \.element.localIdentifier) { index, _ in
                            Capsule()
                                .fill(segmentColor(index: index, marked: marked))
                                .frame(height: index == currentIndex ? 7 : 4)
                        }
                    }
                    .animation(Theme.settle, value: currentIndex)
                    .animation(Theme.settle, value: toBeDeleted.count)
                } else {
                    // Too many photos to draw one segment each, but the
                    // ribbon still has to say what you did — so the filled
                    // run splits coral/teal in proportion to the decisions.
                    let total = CGFloat(max(photoAssets.count, 1))
                    let tossed = CGFloat(toBeDeleted.count)
                    let kept = max(CGFloat(currentIndex) - tossed, 0)
                    Capsule()
                        .fill(Theme.hairline)
                        .frame(height: 4)
                        .overlay(alignment: .leading) {
                            HStack(spacing: 0) {
                                Rectangle().fill(Theme.toss)
                                    .frame(width: geo.size.width * tossed / total)
                                Rectangle().fill(Theme.keep)
                                    .frame(width: geo.size.width * kept / total)
                            }
                            .frame(height: 4)
                            .clipShape(Capsule())
                            .animation(Theme.settle, value: currentIndex)
                        }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func segmentColor(index: Int, marked: Set<String>) -> Color {
        if index == currentIndex { return Theme.cream }
        guard index < currentIndex, photoAssets.indices.contains(index) else { return Theme.hairline }
        return marked.contains(photoAssets[index].localIdentifier) ? Theme.toss : Theme.keep
    }

    /// What you're reviewing and how far in — the progress bar shows the
    /// fraction, this gives it a name and a scale. Memory Burst swaps the
    /// name for the current photo's year: nostalgia is its whole engine.
    private var sessionContextLine: some View {
        let position = min(currentIndex + 1, max(photoAssets.count, 1))
        let name: String
        switch sessionSource {
        case .album:
            name = selectedAlbum?.localizedTitle ?? "All Photos"
        case .burst:
            if let date = currentAsset?.creationDate,
               Calendar.current.component(.year, from: date) < Calendar.current.component(.year, from: Date()) {
                name = "This day, \(String(Calendar.current.component(.year, from: date)))"
            } else {
                name = "Memory Burst"
            }
        case .screenshots:
            name = "Screenshots"
        case .blurry:
            name = "Blurry"
        }
        return Text("\(name) · \(position) of \(photoAssets.count)")
            .font(.footnote)
            .foregroundColor(Theme.dim)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(name), photo \(position) of \(photoAssets.count)")
    }

    /// Decision fuel for the top card: how old, how big, and whether it's
    /// a screenshot — the exact inputs you weigh before a swipe.
    private static let captionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// One chip, not three — everything you weigh about this photo in a
    /// single object, tinted by its weight. A second chip appears only
    /// when the photo is a category worth calling out.
    private func photoCaption(_ asset: PHAsset) -> some View {
        let size = assetFileSize(asset)
        var facts: [String] = []
        if let date = asset.creationDate {
            facts.append(Self.captionDateFormatter.string(from: date))
        }
        if size > 0 {
            facts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        return HStack(spacing: 6) {
            if !facts.isEmpty {
                captionChip("calendar", facts.joined(separator: " · "), tint: heftTint(size))
            }
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                captionChip("camera.viewfinder", "Screenshot", tint: nil)
            }
        }
        .id(asset.localIdentifier)
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
        .animation(Theme.settle, value: asset.localIdentifier)
    }

    /// A space hog should look hot before you read the number: the size
    /// chip's coral tint climbs with the photo's weight (8 MB reads as
    /// heavy). Ordinary photos stay neutral so the signal means something.
    private func heftTint(_ bytes: Int64) -> Color? {
        let heft = min(Double(bytes) / 8_000_000, 1)
        guard heft > 0.15 else { return nil }
        return Theme.toss.opacity(0.12 + 0.28 * heft)
    }

    private func captionChip(_ icon: String, _ text: String, tint: Color?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption.weight(.medium).monospacedDigit())
        }
        .foregroundColor(tint == nil ? Theme.dim : Theme.ink)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint ?? Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }


    private var stackIndices: [Int] {
        guard currentIndex < photoAssets.count else { return [] }
        return Array(currentIndex..<min(currentIndex + 3, photoAssets.count))
    }

    private var cardStack: some View {
        // Greedy up to 560pt, shrinking on short devices (SE-class) so
        // the dock never gets pushed off-screen by a fixed card height.
        // The cap is generous so the card actually fills a tall screen —
        // a smaller cap left it floating mid-column between an over-large
        // gap above (counter) and below (dock).
        GeometryReader { geo in
            ZStack {
                ForEach(stackIndices.reversed(), id: \.self) { index in
                    photoCard(asset: photoAssets[index],
                              depth: index - currentIndex,
                              height: max(geo.size.height - 30, 220))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: 560)
    }

    // One card view for every depth so a peeking card animates smoothly
    // into the top position when the stack advances.
    private func photoCard(asset: PHAsset, depth: Int, height: CGFloat) -> some View {
        let isTop = depth == 0
        let peekScale: CGFloat = depth == 1 ? 0.94 : 0.88
        let peekLift: CGFloat = depth == 1 ? -16 : -30

        // Opaque surface mat behind the aspect-fit photo — the full image
        // stays visible for judging, and peeking cards can't bleed through.
        return ZStack {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.surface)
            PhotoAssetImage(asset: asset)
                .padding(6)
        }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isTop && asset.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(Theme.chipYellow)
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.top, 14)
                        .padding(.trailing, 16)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
            }
            .shadow(color: .black.opacity(isTop ? 0.55 : 0.3),
                    radius: isTop ? 22 : 10, y: isTop ? 12 : 6)
            .scaleEffect(isTop ? 1 : peekScale)
            .offset(y: isTop ? 0 : peekLift)
            .opacity(isTop ? 1 : (depth == 1 ? 0.7 : 0.4))
            .offset(x: isTop ? cardOffset.width : 0,
                    y: isTop ? cardOffset.height * 0.35 : 0)
            .rotationEffect(.degrees(isTop ? Double(cardOffset.width / 18) : 0),
                            anchor: .bottom)
            .zIndex(Double(3 - depth))
            .gesture(dragGesture, including: isTop && !isThrowingCard ? .all : .none)
            // Deal-in: cards rise from the bottom with a stagger when a
            // session starts.
            .offset(y: dealtIn ? 0 : (UIAccessibility.isReduceMotionEnabled ? 0 : 560))
            .opacity(dealtIn ? 1 : 0)
            .animation(Theme.settle.delay(Double(depth) * 0.07), value: dealtIn)
            .id(asset.localIdentifier)
            .accessibilityElement()
            .accessibilityLabel(isTop
                ? (asset.isFavorite ? "Photo \(currentIndex + 1), favorited" : "Photo \(currentIndex + 1)")
                : "Upcoming photo")
            .accessibilityHint(isTop ? "Swipe left to delete, right to keep." : "")
            .accessibilityAddTraits(.isImage)
            // Dock-free delete/keep for VoiceOver users, who can't
            // perform the card drag.
            .accessibilityAction(named: "Delete") {
                if isTop { throwCard(toss: true) }
            }
            .accessibilityAction(named: "Keep") {
                if isTop { throwCard(toss: false) }
            }
            .accessibilityHidden(!isTop)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                cardOffset = value.translation
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                if value.translation.width < -110 || projected < -280 {
                    throwCard(toss: true)
                } else if value.translation.width > 110 || projected > 280 {
                    throwCard(toss: false)
                } else {
                    withAnimation(Theme.settle) { cardOffset = .zero }
                }
            }
    }

    private var tossNowPill: some View {
        Button {
            // Confirm like every other delete path — this was the one
            // unguarded destructive tap in the app.
            showPillConfirm = true
        } label: {
            // The only place the marked size appears — the ribbon carries
            // how many, this carries how much, and it's the actionable one.
            Text("Delete \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.toss, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(Theme.settle, value: totalSize)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Delete \(toBeDeleted.count) selected photos, freeing \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
    }

    // The gestures are the whole interface — the dock keeps only the
    // one thing a gesture can't do: undo.
    private var actionDock: some View {
        dockButton("arrow.uturn.left",
                   chip: currentIndex > 0 ? Theme.chipNavy : Theme.dim.opacity(0.45),
                   label: "Undo") {
            undoLast()
        }
        .disabled(currentIndex == 0)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface, in: Capsule())
        .shadow(color: Theme.ink.opacity(0.12), radius: 16, y: 6)
    }

    private func dockButton(_ icon: String, chip: Color, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.onChip)
                .frame(width: 46, height: 46)
                .background(Circle().fill(chip))
        }
        .buttonStyle(DockButtonStyle())
        .accessibilityLabel(label)
    }

    // MARK: - Swipe actions (one code path for gestures and dock buttons)

    /// Ask for a rating only at a happy moment, only for invested users,
    /// and only rarely: at least two cleanups deep (100+ photos judged is
    /// implied by then), never twice on one version, and never within 120
    /// days of the last ask — Apple caps the system sheet at 3/year, so
    /// each ask has to count. The system may still choose not to show it.
    func maybeRequestReview() {
        let defaults = UserDefaults.standard
        let cleanups = defaults.integer(forKey: "cleanupCount") + 1
        defaults.set(cleanups, forKey: "cleanupCount")
        guard cleanups >= 2 else { return }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        guard defaults.string(forKey: "reviewAskedVersion") != version else { return }
        let lastAsk = defaults.double(forKey: "reviewAskedAt")
        guard Date().timeIntervalSince1970 - lastAsk > 120 * 24 * 3600 else { return }

        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        defaults.set(version, forKey: "reviewAskedVersion")
        defaults.set(Date().timeIntervalSince1970, forKey: "reviewAskedAt")
        // A beat after the celebration clears, so the sheet never collides
        // with the dismiss animation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    func throwCard(toss: Bool) {
        guard !isThrowingCard, currentIndex < photoAssets.count else { return }
        let asset = photoAssets[currentIndex]
        Haptics.impact(toss ? .rigid : .soft)

        if UIAccessibility.isReduceMotionEnabled {
            commitSwipe(toss: toss, asset: asset)
            return
        }

        isThrowingCard = true
        let direction: CGFloat = toss ? -1 : 1
        withAnimation(Theme.throwOut) {
            cardOffset = CGSize(width: direction * 640,
                                height: cardOffset.height * 0.35 - 30)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            commitSwipe(toss: toss, asset: asset)
            isThrowingCard = false
        }
    }

    func commitSwipe(toss: Bool, asset: PHAsset) {
        if toss {
            toBeDeleted.append(asset)
            totalSize += assetFileSize(asset)
        }
        withAnimation(Theme.stackAdvance) {
            currentIndex += 1
            moveToNextPhoto()
        }
        cardOffset = .zero
        recordAlbumProgress()
    }

    func undoLast() {
        guard currentIndex > 0, !isThrowingCard else { return }
        Haptics.impact(.light)
        let asset = photoAssets[currentIndex - 1]
        let wasTossed = toBeDeleted.contains(asset)

        func restore() {
            currentIndex -= 1
            if wasTossed {
                totalSize -= assetFileSize(asset)
                toBeDeleted.removeAll { $0 == asset }
            }
            currentAsset = asset
            recordAlbumProgress()
        }

        if UIAccessibility.isReduceMotionEnabled {
            withAnimation(Theme.stackAdvance) { restore() }
            cardOffset = .zero
            return
        }

        // The card flies back in from the side it left.
        cardOffset = CGSize(width: wasTossed ? -640 : 640, height: -30)
        withAnimation(Theme.stackAdvance) { restore() }
        DispatchQueue.main.async {
            withAnimation(Theme.settle) { cardOffset = .zero }
        }
    }

    func keepAll() {
        Haptics.impact(.soft)
        withAnimation(Theme.settle) {
            currentIndex = photoAssets.count
            moveToNextPhoto()
        }
        // Jumping to the end skips commitSwipe, so the album's saved
        // position never got cleared — reopening it resumed into photos
        // this just kept. Finishing here means finished.
        recordAlbumProgress()
    }

    func exitSession() {
        toBeDeleted = []
        totalSize = 0
        if sessionOrigin == .albums {
            resetToAlbumPicker()
        } else {
            returnHome()
        }
    }

    // MARK: - Session resume (marks survive background kills)

    private static let savedSessionKey = "savedSession.v1"

    /// Snapshot an in-flight session with marks pending, so an app kill
    /// in the background doesn't silently discard a long swipe run.
    func persistSessionIfNeeded() {
        // Progress alone is worth saving — someone who kept 40 photos and
        // marked none should not have to judge those 40 again. But a deck
        // that's been reviewed to the end with nothing marked is finished,
        // not interrupted: restoring it would reopen the app on a spent
        // album's "Album Reviewed" screen instead of Home.
        let finishedAndEmpty = currentIndex >= photoAssets.count && toBeDeleted.isEmpty
        guard sessionActive, !finishedAndEmpty,
              currentIndex > 0 || !toBeDeleted.isEmpty else {
            UserDefaults.standard.removeObject(forKey: Self.savedSessionKey)
            return
        }
        recordAlbumProgress()
        var payload: [String: Any] = [
            "assets": photoAssets.map(\.localIdentifier),
            "marked": toBeDeleted.map(\.localIdentifier),
            "index": currentIndex,
            "origin": sessionOrigin == .albums ? "albums" : "home",
        ]
        if let album = selectedAlbum { payload["album"] = album.localIdentifier }
        UserDefaults.standard.set(payload, forKey: Self.savedSessionKey)
    }

    func clearSavedSession() {
        UserDefaults.standard.removeObject(forKey: Self.savedSessionKey)
    }

    // MARK: - Per-album progress

    private static let albumProgressKey = "albumProgress.v1"

    private func albumKey(for album: PHAssetCollection?) -> String {
        album?.localIdentifier ?? "allPhotos"
    }

    private func savedAlbumProgress(for album: PHAssetCollection?) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: Self.albumProgressKey) as? [String: String]
        return map?[albumKey(for: album)]
    }

    /// Remembers the last photo the user actually decided on, so reopening
    /// this album later resumes after it instead of replaying everything
    /// they already judged. Finishing the album clears the mark so the next
    /// visit starts fresh.
    func recordAlbumProgress() {
        guard sessionSource == .album else { return }
        let key = albumKey(for: selectedAlbum)
        var map = UserDefaults.standard.dictionary(forKey: Self.albumProgressKey) as? [String: String] ?? [:]
        if currentIndex >= photoAssets.count || currentIndex <= 0 {
            map.removeValue(forKey: key)
        } else {
            map[key] = photoAssets[currentIndex - 1].localIdentifier
        }
        UserDefaults.standard.set(map, forKey: Self.albumProgressKey)
    }

    /// Rebuilds an interrupted session on launch — whether or not anything
    /// was marked, since the swiping already done is itself worth keeping.
    /// Returns true if a session was restored.
    func restoreSavedSessionIfAny() -> Bool {
        guard let payload = UserDefaults.standard.dictionary(forKey: Self.savedSessionKey),
              let ids = payload["assets"] as? [String],
              let index = payload["index"] as? Int,
              !ids.isEmpty, index > 0 || !((payload["marked"] as? [String]) ?? []).isEmpty
        else { return false }
        let markedIDs = (payload["marked"] as? [String]) ?? []
        clearSavedSession()

        // Fetch order isn't guaranteed — rebuild in the saved order and
        // silently drop anything deleted since.
        var byID: [String: PHAsset] = [:]
        PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            .enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }
        let assets = ids.compactMap { byID[$0] }
        let marked = markedIDs.compactMap { byID[$0] }
        guard !assets.isEmpty else { return false }

        // Restore the album too, so "Back to Albums" and the post-delete
        // resume reload the right collection rather than All Photos.
        if let albumID = payload["album"] as? String {
            selectedAlbum = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [albumID], options: nil).firstObject
        }

        sessionSource = .album
        sessionOrigin = (payload["origin"] as? String) == "albums" ? .albums : .home
        photoAssets = assets
        toBeDeleted = marked
        totalSize = marked.reduce(Int64(0)) { $0 + assetFileSize($1) }
        currentIndex = min(max(index, 0), assets.count)
        currentAsset = assets.indices.contains(currentIndex) ? assets[currentIndex] : nil
        showDeleteButton = currentIndex >= assets.count
        dealtIn = true
        sessionActive = true
        showToast("Resumed where you left off.")
        return true
    }

    private var sessionEndTitle: String {
        switch sessionSource {
        case .album:       return "Album Reviewed"
        case .burst:       return "Burst Complete"
        case .screenshots: return "Screenshots Reviewed"
        case .blurry:      return "Blurry Photos Reviewed"
        }
    }

    var deleteConfirmation: some View {
        VStack(spacing: 16) {
            if toBeDeleted.isEmpty {
                // Clean finish — the brand mark signs the session off.
                NeonCardMark(size: 68)

                Text(sessionEndTitle)
                    .font(Theme.title)
                    .foregroundColor(Theme.ink)

                Text("No photos selected.")
                    .font(.subheadline)
                    .foregroundColor(Theme.dim)

                Button(sessionOrigin == .albums ? "Albums" : "Home") {
                    withAnimation(Theme.settle) {
                        if sessionOrigin == .albums {
                            resetToAlbumPicker()
                        } else {
                            returnHome()
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.top, 8)
            } else {
                // The condemned, fanned out — the screen was bare text
                // before, and showing the actual photos both fills it and
                // makes the decision concrete.
                markedPreviewFan
                    .padding(.bottom, 8)

                Text(sessionEndTitle)
                    .font(Theme.title)
                    .foregroundColor(Theme.ink)

                // Count and size live here, once — the button below is
                // just the verb.
                Text("\(toBeDeleted.count) photo\(toBeDeleted.count == 1 ? "" : "s") · \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(Theme.dim)

                Button("Delete") {
                    deleteMarkedPhotos()
                }
                .buttonStyle(TossButtonStyle())
                .padding(.horizontal)
                .padding(.top, 8)

                Text("They'll stay in Recently Deleted for 30 days.")
                    .font(.caption)
                    .foregroundColor(Theme.dim)

                if sessionSource == .burst {
                    // Backing out of a toss still finishes the burst — the
                    // habit is showing up, not deleting.
                    Button("Keep All") {
                        toBeDeleted = []
                        totalSize = 0
                        finishBurst()
                    }
                    .buttonStyle(QuietButtonStyle())
                    .padding(.horizontal)
                } else {
                    Button(sessionOrigin == .albums ? "Albums" : "Home") {
                        withAnimation(Theme.settle) {
                            if sessionOrigin == .albums {
                                resetToAlbumPicker()
                            } else {
                                returnHome()
                            }
                        }
                    }
                    .buttonStyle(QuietButtonStyle())
                    .padding(.horizontal)
                }
            }
        }
        .padding()
    }


    /// Up to five of the marked photos, fanned like a discard pile.
    /// The subtitle carries the exact count, so no "+N" badge here.
    private var markedPreviewFan: some View {
        let preview = Array(toBeDeleted.prefix(5))
        let mid = Double(preview.count - 1) / 2
        return ZStack {
            ForEach(Array(preview.enumerated()), id: \.element.localIdentifier) { index, asset in
                let fan = Double(index) - mid
                PhotoThumbnailView(asset: asset)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
                    .rotationEffect(.degrees(fan * 6))
                    .offset(x: fan * 46, y: abs(fan) * 6)
                    .zIndex(-abs(fan))
            }
        }
        .frame(height: 120)
        .accessibilityHidden(true) // decorative; the text carries the info
    }

    func moveToNextPhoto() {
        if currentIndex >= photoAssets.count {
            if sessionSource == .burst && toBeDeleted.isEmpty {
                finishBurst()
            } else {
                showDeleteButton = true
            }
        } else {
            currentAsset = photoAssets[currentIndex]
        }
    }

    func startSession(_ source: SessionSource, assets: [PHAsset], startAt: Int = 0) {
        dealtIn = false
        withAnimation(Theme.settle) {
            sessionSource = source
            sessionOrigin = .home
            photoAssets = assets
            currentIndex = min(startAt, max(assets.count - 1, 0))
            toBeDeleted = []
            totalSize = 0
            currentAsset = assets.indices.contains(currentIndex) ? assets[currentIndex] : nil
            showDeleteButton = false
            showBurstComplete = false
            sessionActive = true
        }
    }

    func finishBurst() {
        Haptics.success()
        stats.completeBurst()
        notifications.reschedule(burstDoneToday: true)
        sessionActive = false
        showDeleteButton = false
        withAnimation(Theme.settle) {
            showBurstComplete = true
        }
    }

    func returnHome() {
        clearSavedSession()
        sessionActive = false
        showAlbumPicker = false
        showBurstComplete = false
        photoAssets = []
        currentIndex = 0
        toBeDeleted = []
        totalSize = 0
        selectedAlbum = nil
        currentAsset = nil
        showDeleteButton = false
    }

    func deleteMarkedPhotos() {
        guard !isDeleting else { return }
        isDeleting = true
        // Thumbnails must be captured before the assets stop existing —
        // they star in the delete celebration.
        prefetchThumbnails(of: Array(toBeDeleted.prefix(7))) { images in
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(self.toBeDeleted as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                isDeleting = false
                if success {
                    Haptics.success()
                    let count = toBeDeleted.count
                    // Where to land afterwards: a delete at the end of the
                    // stack means the session is finished; a mid-session
                    // delete (the pill) resumes at the next unseen photo
                    // instead of restarting the album from zero.
                    let wasAtEnd = currentIndex >= photoAssets.count
                    let resumeIndex = max(currentIndex - count, 0)
                    let category: Stats.ClearCategory? = {
                        switch sessionSource {
                        case .screenshots: return .screenshots
                        case .blurry: return .blurry
                        case .album, .burst: return nil
                        }
                    }()
                    stats.recordDelete(count: count, freed: totalSize, category: category)
                    if count > 0 {
                        // Any session that tosses ≥ 1 photo marks today complete.
                        stats.completeBurst()
                        notifications.reschedule(burstDoneToday: true)
                    }
                    withAnimation(Theme.settle) {
                        deleteCelebration = DeleteCelebration(images: images, count: count, freed: totalSize)
                    }

                    let tossedIDs = Set(toBeDeleted.map(\.localIdentifier))
                    self.toBeDeleted.removeAll()
                    self.totalSize = 0
                    self.currentIndex = 0
                    self.showDeleteButton = false
                    self.clearSavedSession()
                    // Keep scanner products honest after any swipe delete.
                    if libraryScanner.hasScanned {
                        libraryScanner.removeAssets(withIdentifiers: tossedIDs)
                    }
                    switch sessionSource {
                    case .album:
                        if wasAtEnd {
                            withAnimation(Theme.settle) {
                                if sessionOrigin == .albums {
                                    resetToAlbumPicker()
                                } else {
                                    returnHome()
                                }
                            }
                            loadHomeData()
                        } else {
                            self.loadPhotos(from: self.selectedAlbum,
                                            startAt: resumeIndex,
                                            origin: sessionOrigin)
                        }
                    case .burst:
                        sessionActive = false
                        withAnimation(Theme.settle) { showBurstComplete = true }
                    case .screenshots, .blurry:
                        withAnimation(Theme.settle) { returnHome() }
                        loadHomeData()
                    }
                } else {
                    // Also reached when the user taps "Don't Allow" on the
                    // system dialog — keep all state so they can retry.
                    showToast("Couldn’t delete. Photos unchanged.")
                }
            }
        }
        }
    }

    /// Batch delete outside a swipe session (Large Videos, Duplicates).
    /// Same PhotoKit pattern as deleteMarkedPhotos: one performChanges,
    /// stats + reminder wiring, celebration on success, toast on failure.
    func performBatchDelete(_ assets: [PHAsset], freed: Int64, category: Stats.ClearCategory? = nil, onSuccess: @escaping () -> Void) {
        guard !assets.isEmpty, !isDeleting else { return }
        isDeleting = true
        prefetchThumbnails(of: Array(assets.prefix(7))) { images in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }) { success, _ in
                DispatchQueue.main.async {
                    self.isDeleting = false
                    if success {
                        Haptics.success()
                        self.stats.recordDelete(count: assets.count, freed: freed, category: category)
                        self.stats.completeBurst()
                        self.notifications.reschedule(burstDoneToday: true)
                        withAnimation(Theme.settle) {
                            self.deleteCelebration = DeleteCelebration(images: images,
                                                                       count: assets.count,
                                                                       freed: freed)
                        }
                        onSuccess()
                    } else {
                        self.showToast("Couldn’t delete. Photos unchanged.")
                    }
                }
            }
        }
    }

    /// Small stills of the condemned, captured while they still exist —
    /// the delete celebration plays them being swallowed by the spotlight.
    func prefetchThumbnails(of assets: [PHAsset], completion: @escaping ([UIImage]) -> Void) {
        guard !assets.isEmpty else {
            completion([])
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = true
            options.isNetworkAccessAllowed = true
            var images: [UIImage] = []
            for asset in assets {
                autoreleasepool {
                    _ = manager.requestImage(for: asset,
                                             targetSize: CGSize(width: 220, height: 220),
                                             contentMode: .aspectFill,
                                             options: options) { result, _ in
                        if let result { images.append(result) }
                    }
                }
            }
            DispatchQueue.main.async { completion(images) }
        }
    }

    func resetToAlbumPicker() {
        clearSavedSession()
        self.sessionActive = false
        self.showAlbumPicker = true
        self.photoAssets = []
        self.currentIndex = 0
        self.toBeDeleted = []
        self.totalSize = 0
        self.selectedAlbum = nil
        self.currentAsset = nil
        self.showDeleteButton = false
    }

    func showToast(_ message: String) {
        snackbarMessage = message
        // Toasts are transient — surface them to VoiceOver too.
        UIAccessibility.post(notification: .announcement, argument: message)
        withAnimation(Theme.settle) {
            showSnackbar = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(Theme.settle) {
                showSnackbar = false
            }
        }
    }

    func assetFileSize(_ asset: PHAsset) -> Int64 {
        LibraryScanner.fileSize(asset)
    }

    func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
    }

    /// `resumeAlbum` picks up where this album was last left off — used when
    /// the user opens an album from the picker, not when a caller already
    /// knows the index it wants (a post-delete resume, or a Recent tap).
    func loadPhotos(from album: PHAssetCollection? = nil, startAt: Int = 0,
                    origin: SessionOrigin = .albums, resumeAlbum: Bool = false) {
        isLoadingPhotos = true
        let lastReviewedID = resumeAlbum ? savedAlbumProgress(for: album) : nil

        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let assets: PHFetchResult<PHAsset>
            if let album = album {
                assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
            } else {
                assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            }

            var result: [PHAsset] = []
            assets.enumerateObjects { (asset, _, _) in result.append(asset) }

            // Resume from the photo after the last one they decided on.
            // Matching by identifier rather than a stored index survives the
            // album changing while they were away. Reaching the end means
            // they finished it — start clean rather than reopening on "done".
            var resumeStart: Int? = nil
            if let lastReviewedID,
               let seen = result.firstIndex(where: { $0.localIdentifier == lastReviewedID }),
               seen + 1 < result.count {
                resumeStart = seen + 1
            }

            DispatchQueue.main.async {
                let start = min(resumeStart ?? startAt, max(result.count - 1, 0))
                if resumeStart != nil { self.showToast("Picking up where you left off.") }
                self.dealtIn = false
                withAnimation(Theme.settle) {
                    self.sessionSource = .album
                    self.sessionOrigin = origin
                    self.sessionActive = true
                    self.photoAssets = result
                    self.currentIndex = start
                    self.toBeDeleted = []
                    self.totalSize = 0
                    self.currentAsset = result.indices.contains(start) ? result[start] : nil
                    self.isLoadingPhotos = false
                }
            }
        }
    }

    /// Computes everything the home dashboard shows: screenshot / video
    /// counts, the "this day, years ago" time capsule set, today's burst
    /// deck, and the recent strip. Runs per visit (roadmap Phase 1).
    func loadHomeData() {
        guard !isLoadingHome else { return }
        isLoadingHome = true

        DispatchQueue.global(qos: .userInitiated).async {
            let newestFirst = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let screenshotOptions = PHFetchOptions()
            screenshotOptions.predicate = NSPredicate(
                format: "(mediaSubtypes & %d) != 0",
                PHAssetMediaSubtype.photoScreenshot.rawValue)
            screenshotOptions.sortDescriptors = newestFirst
            var screenshots: [PHAsset] = []
            PHAsset.fetchAssets(with: .image, options: screenshotOptions)
                .enumerateObjects { asset, _, _ in screenshots.append(asset) }

            // Videos with sizes for the Large Videos list — those over
            // 50 MB, or everything if none cross the bar.
            var videoItems: [VideoItem] = []
            PHAsset.fetchAssets(with: .video, options: nil)
                .enumerateObjects { asset, _, _ in
                    videoItems.append(VideoItem(asset: asset, size: LibraryScanner.fileSize(asset)))
                }
            videoItems.sort { $0.size > $1.size }
            let bigOnes = videoItems.filter { $0.size >= 50_000_000 }
            let videos = videoItems.count

            // "This day, years ago" — exactly today's month/day in each
            // prior year, oldest year first so the burst starts furthest
            // back. Feeds Memory Burst only (there's no separate raw
            // "Time Capsule" view of this anymore — it was the same data
            // as the burst, just uncapped, which read as a redundant tile).
            var capsuleByYear: [(yearsBack: Int, assets: [PHAsset])] = []
            let calendar = Calendar(identifier: .iso8601)
            let now = Date()
            for yearsBack in stride(from: 15, through: 1, by: -1) {
                guard let past = calendar.date(byAdding: .year, value: -yearsBack, to: now),
                      let day = calendar.dateInterval(of: .day, for: past) else { continue }
                let options = PHFetchOptions()
                options.predicate = NSPredicate(
                    format: "creationDate >= %@ AND creationDate < %@",
                    day.start as NSDate, day.end as NSDate)
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                var yearAssets: [PHAsset] = []
                PHAsset.fetchAssets(with: .image, options: options)
                    .enumerateObjects { asset, _, _ in yearAssets.append(asset) }
                if !yearAssets.isEmpty {
                    capsuleByYear.append((yearsBack, yearAssets))
                }
            }

            // Health-score input: screenshots that have sat for a month.
            let staleCutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            let staleScreenshots = screenshots.filter {
                ($0.creationDate ?? .distantPast) < staleCutoff
            }.count

            // The Recent strip shows the whole library, newest first —
            // no cap. The burst-fallback chain below still only ever
            // takes the first 10 of this, so it stays a small daily dose.
            let recentOptions = PHFetchOptions()
            recentOptions.sortDescriptors = newestFirst
            var recent: [PHAsset] = []
            PHAsset.fetchAssets(with: .image, options: recentOptions)
                .enumerateObjects { asset, _, _ in recent.append(asset) }

            // Burst: always has something. This day in prior years →
            // a random old month → screenshots → the newest photos.
            // The daily habit never dead-ends on "None". Capped per year so
            // a photo-heavy year doesn't crowd out the rest — the point is
            // a spread across years, not just the oldest one.
            var burst: [PHAsset] = []
            for (_, yearAssets) in capsuleByYear {
                burst.append(contentsOf: yearAssets.prefix(3))
                if burst.count >= 10 { break }
            }
            burst = Array(burst.prefix(10))
            if burst.isEmpty {
                let monthsBack = Int.random(in: 12...36)
                if let past = calendar.date(byAdding: .month, value: -monthsBack, to: now),
                   let month = calendar.dateInterval(of: .month, for: past) {
                    let options = PHFetchOptions()
                    options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@",
                                                    month.start as NSDate, month.end as NSDate)
                    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                    options.fetchLimit = 10
                    PHAsset.fetchAssets(with: .image, options: options)
                        .enumerateObjects { asset, _, _ in burst.append(asset) }
                }
            }
            if burst.isEmpty { burst = Array(screenshots.prefix(10)) }
            if burst.isEmpty { burst = Array(recent.prefix(10)) }

            // Reminder teaser ("3 photos from July 2019") — only when the
            // burst is genuinely from the past.
            var teaser: String?
            if let date = burst.first?.creationDate,
               let horizon = calendar.date(byAdding: .month, value: -6, to: now),
               date < horizon {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                teaser = "\(burst.count) photo\(burst.count == 1 ? "" : "s") from \(formatter.string(from: date))"
            }

            DispatchQueue.main.async {
                self.burstTeaser = teaser
                self.screenshotAssets = screenshots
                self.staleScreenshotCount = staleScreenshots
                self.videoCount = videos
                self.largeVideos = bigOnes.isEmpty ? videoItems : bigOnes
                self.largeVideosShowingAll = bigOnes.isEmpty
                self.burstAssets = burst
                self.recentAssets = recent
                self.isLoadingHome = false
                // Warm the strip's first screens of thumbnails.
                ThumbCache.precache(Array(recent.prefix(80)))

                // First run just finished: drop straight into the first
                // cleanup now that the burst is in hand (the burst chain
                // always yields something unless the library is empty).
                if self.pendingFirstCleanup, !self.sessionActive, !burst.isEmpty {
                    self.pendingFirstCleanup = false
                    self.startSession(.burst, assets: burst)
                } else if self.pendingFirstCleanup {
                    // Empty library — nothing to clean; just land on Home.
                    self.pendingFirstCleanup = false
                }

                // Trailing pass: size the screenshot pile without holding
                // up the paint above (sizes NSCache after first lookup).
                DispatchQueue.global(qos: .utility).async {
                    let bytes = screenshots.reduce(Int64(0)) { $0 + LibraryScanner.fileSize($1) }
                    DispatchQueue.main.async { self.screenshotBytes = bytes }
                }
            }
        }
    }

    func fetchAlbums() {
        guard !isLoadingAlbums else { return }
        isLoadingAlbums = true

        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHFetchOptions()
            let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

            let allCollections = [userAlbums, smartAlbums].flatMap { result -> [PHAssetCollection] in
                var temp: [PHAssetCollection] = []
                result.enumerateObjects { collection, _, _ in temp.append(collection) }
                return temp
            }

            let imageManager = PHImageManager.default()
            var all: [AlbumMeta] = []

            for collection in allCollections {
                if collection.assetCollectionSubtype == .smartAlbumAllHidden { continue }

                let assets = PHAsset.fetchAssets(in: collection, options: options)
                guard let firstAsset = assets.firstObject else { continue }

                let latestDate = firstAsset.creationDate ?? Date.distantPast
                let requestOptions = PHImageRequestOptions()
                requestOptions.deliveryMode = .highQualityFormat
                requestOptions.isSynchronous = true
                requestOptions.isNetworkAccessAllowed = true

                var thumbnail: UIImage?
                imageManager.requestImage(for: firstAsset,
                                          targetSize: CGSize(width: 300, height: 300),
                                          contentMode: .aspectFill,
                                          options: requestOptions) { result, _ in
                    thumbnail = result
                }

                all.append(AlbumMeta(
                    collection: collection,
                    thumbnail: thumbnail,
                    assetCount: assets.count,
                    latestDate: latestDate
                ))
            }

            let sorted = all.sorted { $0.latestDate > $1.latestDate }

            let allAssets = PHAsset.fetchAssets(with: .image, options: options)
            var allThumb: UIImage?
            if let first = allAssets.firstObject {
                let reqOptions = PHImageRequestOptions()
                reqOptions.deliveryMode = .highQualityFormat
                reqOptions.isSynchronous = true
                reqOptions.isNetworkAccessAllowed = true
                imageManager.requestImage(for: first,
                                          targetSize: CGSize(width: 300, height: 300),
                                          contentMode: .aspectFill,
                                          options: reqOptions) { result, _ in
                    allThumb = result
                }
            }

            DispatchQueue.main.async {
                self.sortedAlbums = sorted
                self.allPhotosCount = allAssets.count
                self.allPhotosThumbnail = allThumb
                self.isLoadingAlbums = false
            }
        }
    }
}

// MARK: - Delete celebration (the swallow)

struct DeleteCelebration {
    let images: [UIImage]
    let count: Int
    let freed: Int64
}

/// The payoff moment after a successful batch delete: the tossed
/// photos funnel one-by-one into a glowing point at the bottom of the
/// stage — swallowed by the spotlight — then the numbers pop.
struct DeleteBlastView: View {
    let celebration: DeleteCelebration
    let onDone: () -> Void

    @State private var swallowed = false
    @State private var glowPulse = false
    @State private var showNumber = false
    @State private var finished = false
    @State private var isSharing = false

    var body: some View {
        ZStack {
            Theme.stage.opacity(0.97).ignoresSafeArea()

            // The swallow point — a spotlight pool at the bottom.
            VStack {
                Spacer()
                RadialGradient(colors: [Theme.chipCoral.opacity(glowPulse ? 0.5 : 0.22), .clear],
                               center: .center, startRadius: 2, endRadius: 150)
                    .frame(width: 300, height: 300)
                    .scaleEffect(glowPulse ? 1.25 : 0.9)
                    .animation(.easeInOut(duration: 0.35).repeatCount(celebration.images.count + 1, autoreverses: true),
                               value: glowPulse)
                    .offset(y: 110)
            }
            .ignoresSafeArea()

            // The condemned, fanned like the review stack, dropping in
            // sequence into the light.
            ForEach(Array(celebration.images.enumerated()), id: \.offset) { index, image in
                let mid = Double(celebration.images.count - 1) / 2
                let fan = Double(index) - mid
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                    // A dark drop-shadow disappears against the near-black
                    // stage — lift the tile with a light glow instead.
                    .shadow(color: .white.opacity(0.12), radius: 12, y: 5)
                    .rotationEffect(.degrees(swallowed ? fan * 40 + 120 : fan * 7))
                    .scaleEffect(swallowed ? 0.02 : 1)
                    .offset(x: swallowed ? 0 : fan * 26,
                            y: swallowed ? 330 : -60)
                    .opacity(swallowed ? 0 : 1)
                    .animation(Theme.throwOut.delay(Double(index) * 0.11), value: swallowed)
                    .zIndex(Double(celebration.images.count - index))
            }

            if showNumber {
                VStack(spacing: 18) {
                    // The brand mark caps every delete, whichever flow
                    // it came from — one consistent payoff.
                    NeonCardMark(size: 60)

                    VStack(spacing: 6) {
                        // Space reclaimed is the headline — that's the win.
                        if celebration.freed > 0 {
                            Text("\(ByteCountFormatter.string(fromByteCount: celebration.freed, countStyle: .file)) freed")
                                .font(Theme.display(34).monospacedDigit())
                                .foregroundColor(Theme.ink)
                            Text("\(celebration.count) \(celebration.count == 1 ? "photo" : "photos") deleted")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Theme.dim)
                        } else {
                            Text("\(celebration.count) Deleted")
                                .font(Theme.display(34))
                                .foregroundColor(Theme.ink)
                        }
                        Text("In Recently Deleted for 30 days")
                            .font(.caption)
                            .foregroundColor(Theme.dim.opacity(0.8))
                            .padding(.top, 2)
                    }

                    // The win is the app's most shareable artifact —
                    // one tap turns it into a story/post with the link.
                    Button(action: presentShareSheet) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.ink)
                            .padding(.horizontal, 20)
                            .frame(height: 40)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .shadow(color: Theme.chipCoral.opacity(0.25), radius: 24)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(celebration.freed > 0
                            ? "\(ByteCountFormatter.string(fromByteCount: celebration.freed, countStyle: .file)) freed, \(celebration.count) photos deleted"
                            : "\(celebration.count) photos deleted")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to dismiss")
        .accessibilityAction(named: "Share") { presentShareSheet() }
        // Celebration is a reward, not a toll booth — tap skips straight
        // through. The guard keeps the still-pending auto-dismiss timer
        // from firing onDone a second time.
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear(perform: run)
    }

    private func finish() {
        guard !finished, !isSharing else { return }
        finished = true
        onDone()
    }

    /// System share sheet with the win + link. Sharing pauses the
    /// auto-dismiss (the timers check `isSharing`), and closing the
    /// sheet ends the celebration.
    private func presentShareSheet() {
        guard !isSharing else { return }
        isSharing = true
        let freedText = ByteCountFormatter.string(fromByteCount: celebration.freed, countStyle: .file)
        let message = celebration.freed > 0
            ? "I just freed \(freedText) of photo clutter with Leftover 🧹"
            : "I just cleaned \(celebration.count) photos with Leftover 🧹"
        let vc = UIActivityViewController(activityItems: [message, AppLink.site],
                                          applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            isSharing = false
            finish()
        }
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            isSharing = false
            return
        }
        // iPad: anchor the popover mid-screen under the numbers.
        vc.popoverPresentationController?.sourceView = root.view
        vc.popoverPresentationController?.sourceRect = CGRect(
            x: root.view.bounds.midX, y: root.view.bounds.midY, width: 1, height: 1)
        root.present(vc, animated: true)
    }

    private func run() {
        if UIAccessibility.isReduceMotionEnabled || celebration.images.isEmpty {
            swallowed = true
            withAnimation(Theme.pop) { showNumber = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { finish() }
            return
        }

        DispatchQueue.main.async {
            swallowed = true
            glowPulse = true
        }
        let swallowTime = Double(celebration.images.count) * 0.11 + 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + swallowTime) {
            Haptics.success()
            withAnimation(Theme.pop) { showNumber = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + swallowTime + 3.4) {
            finish()
        }
    }
}

struct AlbumMeta {
    let collection: PHAssetCollection
    let thumbnail: UIImage?
    let assetCount: Int
    let latestDate: Date
}

struct AlbumGridItem: View {
    let title: String
    let count: Int
    let thumbnail: UIImage?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                if let thumbnail = thumbnail {
                    Color.clear
                        .frame(height: 120)
                        .overlay(
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                        .fill(Theme.surface)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                        .overlay(ProgressView())
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.ink)

                Text("\(count) Photos")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Theme.dim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}


/// Shared caching manager for small thumbnails — the Recent strip can
/// hold an entire library, and PHCachingImageManager keeps decoded
/// thumbs warm instead of re-decoding on every scroll pass. Options
/// must match the per-request ones for the cache to be hit.
enum ThumbCache {
    static let manager = PHCachingImageManager()
    // 240px covers a 3-column grid cell (~120pt) on a 2x display without
    // visible softness, and stays cheap to decode for the smaller uses.
    static let size = CGSize(width: 240, height: 240)

    static func options() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        // .opportunistic: a degraded image lands immediately, the good
        // one follows — .fastFormat alone can fail with error 3303.
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        return options
    }

    static func precache(_ assets: [PHAsset]) {
        manager.stopCachingImagesForAllAssets()
        manager.startCachingImages(for: assets, targetSize: size,
                                   contentMode: .aspectFill, options: options())
    }
}

/// Watches the photo library for changes made outside the app (Photos
/// deletes, iCloud sync, AirDrop arrivals) so Home's counts don't go
/// stale until the next manual visit.
final class LibraryChangeMonitor: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published var changeToken = 0

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { self.changeToken += 1 }
    }
}

struct PhotoAssetImage: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .onAppear {
            fetchImage()
        }
        .id(asset.localIdentifier)
    }

    func fetchImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 800, height: 800),
                             contentMode: .aspectFit,
                             options: options) { result, _ in
            DispatchQueue.main.async {
                image = result
            }
        }
    }
}

struct PhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Theme.surface
                    .overlay(ProgressView())
            }
        }
        .onAppear {
            ThumbCache.manager.requestImage(
                for: asset,
                targetSize: ThumbCache.size,
                contentMode: .aspectFill,
                options: ThumbCache.options()
            ) { result, _ in
                guard let result else { return }
                DispatchQueue.main.async {
                    image = result
                }
            }
        }
    }
}
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
