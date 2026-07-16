import SwiftUI
import Photos
import PhotosUI
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
    @State private var showHeartAnimation = false
    @State private var heartScale: CGFloat = 1.0
    @State private var isAddingToFavorites: Bool = true
    @State private var shakeOffset: CGFloat = 0
    @State private var pulse = false
    @State private var heartRotation: Double = 0
    @State private var heartOpacity: Double = 1.0
    // The splash shows on every cold launch: first launch keeps the
    // Start button, returning launches auto-dissolve into home.
    @State private var showSplashScreen = true
    private let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

    @StateObject private var stats = Stats()
    @StateObject private var notifications = NotificationManager()
    @State private var sessionSource: SessionSource = .album
    @State private var sessionOrigin: SessionOrigin = .home
    @State private var sessionActive = false
    @State private var showBurstComplete = false
    @State private var showSettings = false
    @State private var isLoadingHome = false
    @State private var screenshotAssets: [PHAsset] = []
    @State private var burstAssets: [PHAsset] = []
    @State private var videoCount = 0
    @State private var recentAssets: [PHAsset] = []
    @StateObject private var libraryScanner = LibraryScanner()
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
    @State private var dealtIn = true
    @State private var burstTeaser: String? = nil
    @State private var deleteCelebration: DeleteCelebration?

    var body: some View {
        ZStack {
            Theme.stage.ignoresSafeArea()

            if showSplashScreen {
                splashScreenView
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
                        performBatchDelete(assets, freed: freed) {
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
                        performBatchDelete(assets, freed: freed) {
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
                        performBatchDelete(assets, freed: freed) {
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
                            .font(.system(size: 15, weight: .semibold))
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
                notifications.burstTeaser = burstTeaser
                notifications.streakToProtect =
                    (!stats.isBurstDoneToday && stats.streakCount >= 3) ? stats.streakCount : 0
                notifications.reschedule(burstDoneToday: stats.isBurstDoneToday)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(notifications: notifications, stats: stats)
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
            libraryScanner.scan()
        }
    }

    private func scanDetail(count: Int) -> String {
        guard libraryScanner.hasScanned else { return "Scan" }
        if count == 0 { return "None" }
        return count.formatted()
    }

    var splashScreenView: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
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
                        pulse = true
                    }

                Text("Swipe right to keep, left to delete.")
                    .font(.footnote)
                    .foregroundColor(Theme.dim.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 28)

            if isFirstLaunch {
                Button("Start") {
                    stats.hasLaunchedBefore = true
                    withAnimation(Theme.settle) {
                        showSplashScreen = false
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
                    streakCount: stats.streakCount,
                    streakPop: stats.streakJustIncremented,
                    burstDetail: stats.isBurstDoneToday
                        ? "Done today"
                        : (burstAssets.isEmpty ? "None" : burstAssets.count.formatted()),
                    burstDimmed: stats.isBurstDoneToday || burstAssets.isEmpty,
                    screenshotCount: screenshotAssets.count,
                    videoCount: videoCount,
                    duplicateDetail: scanDetail(count: libraryScanner.duplicateGroups.count),
                    similarDetail: scanDetail(count: libraryScanner.similarGroups.count),
                    blurryDetail: scanDetail(count: libraryScanner.blurryAssets.count),
                    recentAssets: recentAssets,
                    isLoading: isLoadingHome,
                    onSettings: { showSettings = true },
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
                        self.loadHomeData()
                        #if DEBUG
                        // Headless-verification hooks (simctl launch … -Leftover…).
                        let args = ProcessInfo.processInfo.arguments
                        if args.contains("-LeftoverAutoSession"), !self.sessionActive {
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

            if stats.streakJustIncremented {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Theme.cream)
                    Text("\(stats.streakCount)-day streak")
                        .font(.system(.subheadline).weight(.bold))
                        .foregroundColor(Theme.ink)
                }
            }

            if stats.freezeJustEarned {
                HStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .foregroundColor(Theme.chipBlue)
                    Text("You earned a streak freeze")
                        .font(.subheadline)
                        .foregroundColor(Theme.dim)
                }
            }

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
                    Button {
                        withAnimation(Theme.settle) {
                            showAlbumPicker = false
                        }
                    } label: {
                        Label("Home", systemImage: "chevron.backward")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.ink)
                    }
                    .accessibilityLabel("Back to home")
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
                    self.loadPhotos()
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
                        self.loadPhotos(from: albumMeta.collection)
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
                counterRow

                Spacer(minLength: 8)

                cardStack

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
            Button("Delete \(toBeDeleted.count)", role: .destructive) {
                deleteMarkedPhotos()
            }
            Button("Keep All") {
                withAnimation(Theme.settle) { exitSession() }
            }
            Button("Cancel", role: .cancel) {}
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

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.hairline)
                        .frame(height: 4)
                    Capsule()
                        .fill(Theme.cream)
                        .frame(width: max(geo.size.width * progressFraction, 4), height: 4)
                        .animation(Theme.settle, value: currentIndex)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 40)
            .accessibilityElement()
            .accessibilityLabel("Reviewed \(currentIndex) of \(photoAssets.count)")

            Button("Keep all") {
                keepAll()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityHint("Keeps every remaining photo and ends the session")
        }
    }

    private var progressFraction: CGFloat {
        photoAssets.isEmpty ? 0 : CGFloat(currentIndex) / CGFloat(photoAssets.count)
    }

    private var counterRow: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                Text("\(toBeDeleted.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .foregroundColor(Theme.toss)
            .animation(Theme.settle, value: toBeDeleted.count)
            .accessibilityElement()
            .accessibilityLabel("\(toBeDeleted.count) selected to delete")

            Spacer()

            HStack(spacing: 5) {
                Text("\(max(currentIndex - toBeDeleted.count, 0))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(Theme.keep)
            .animation(Theme.settle, value: currentIndex - toBeDeleted.count)
            .accessibilityElement()
            .accessibilityLabel("\(max(currentIndex - toBeDeleted.count, 0)) kept")
        }
        .padding(.horizontal, 6)
    }

    private var stackIndices: [Int] {
        guard currentIndex < photoAssets.count else { return [] }
        return Array(currentIndex..<min(currentIndex + 3, photoAssets.count))
    }

    private var cardStack: some View {
        ZStack {
            ForEach(stackIndices.reversed(), id: \.self) { index in
                photoCard(asset: photoAssets[index], depth: index - currentIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 470)
    }

    // One card view for every depth so a peeking card animates smoothly
    // into the top position when the stack advances.
    private func photoCard(asset: PHAsset, depth: Int) -> some View {
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
            .frame(height: 440)
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
            .overlay(
                Group {
                    if isTop && showHeartAnimation {
                        Image(systemName: "heart.fill")
                            .resizable()
                            .foregroundColor(Theme.cream)
                            .frame(width: 34, height: 34)
                            .scaleEffect(heartScale)
                            .rotationEffect(.degrees(heartRotation))
                            .offset(x: shakeOffset)
                            .opacity(heartOpacity)
                    }
                }
            )
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
            .onTapGesture(count: 2) {
                if isTop { favoriteCurrent() }
            }
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
            .accessibilityHint(isTop ? "Double tap to favorite. Swipe left to toss, right to keep." : "")
            .accessibilityAddTraits(.isImage)
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
            deleteMarkedPhotos()
        } label: {
            Text("Delete \(toBeDeleted.count)")
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.toss, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(Theme.settle, value: toBeDeleted.count)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Delete \(toBeDeleted.count) selected photos now")
    }

    private var actionDock: some View {
        HStack(spacing: 14) {
            dockButton("trash.fill", chip: Theme.chipCoral, label: "Delete") {
                throwCard(toss: true)
            }
            dockButton("arrow.uturn.left",
                       chip: currentIndex > 0 ? Theme.chipNavy : Theme.dim.opacity(0.45),
                       label: "Undo") {
                undoLast()
            }
            .disabled(currentIndex == 0)
            dockButton(currentAsset?.isFavorite == true ? "star.fill" : "star",
                       chip: currentAsset?.isFavorite == true ? Theme.chipYellow : Theme.dim.opacity(0.45),
                       label: "Favorite") {
                favoriteCurrent()
            }
            dockButton("checkmark", chip: Theme.chipTeal, label: "Keep") {
                throwCard(toss: false)
            }
        }
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
                .foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(chip))
        }
        .buttonStyle(DockButtonStyle())
        .accessibilityLabel(label)
    }

    // MARK: - Swipe actions (one code path for gestures and dock buttons)

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

    func favoriteCurrent() {
        Haptics.impact(.light)
        guard let asset = currentAsset else { return }
        isAddingToFavorites = !asset.isFavorite
        showHeartAnimation = true

        if isAddingToFavorites {
            heartOpacity = 1.0
            heartRotation = 0
            heartScale = 0.8

            withAnimation(Theme.pop) {
                heartScale = 1.2
            }
        } else {
            heartScale = 1.0
            heartOpacity = 0.6

            withAnimation(Animation.linear(duration: 0.15).repeatCount(4, autoreverses: true)) {
                shakeOffset = 6
                heartRotation = -10
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shakeOffset = 0
                heartRotation = 0

                withAnimation(.easeInOut(duration: 0.4)) {
                    heartScale = 0.6
                    heartOpacity = 0.0
                }
            }
        }

        toggleFavorite(asset)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showHeartAnimation = false
            heartOpacity = 0.7
            heartScale = 0.8
            heartRotation = 0
            shakeOffset = 0
        }
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
                LeftoverBuddy(color: Theme.chipTeal, expression: .happy, size: 64)

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
                Text(sessionEndTitle)
                    .font(Theme.title)
                    .foregroundColor(Theme.ink)

                Text("\(toBeDeleted.count) selected to delete.")
                    .font(.subheadline)
                    .foregroundColor(Theme.dim)

                Button("Delete \(toBeDeleted.count)") {
                    deleteMarkedPhotos()
                }
                .buttonStyle(TossButtonStyle())
                .padding(.horizontal)
                .padding(.top, 8)

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


    func toggleFavorite(_ asset: PHAsset) {
        let wasFavorite = asset.isFavorite

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = !wasFavorite
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    // PHAsset objects are immutable snapshots — re-fetch so
                    // isFavorite reads stay correct when this photo is revisited.
                    if let refreshed = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil).firstObject {
                        if let index = photoAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                            photoAssets[index] = refreshed
                        }
                        if currentAsset?.localIdentifier == asset.localIdentifier {
                            currentAsset = refreshed
                        }
                    }
                } else {
                    showToast("Couldn’t update favorite.")
                }
            }
        }
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
                    stats.recordDelete(count: count, freed: totalSize)
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
                    // Keep scanner products honest after any swipe delete.
                    if libraryScanner.hasScanned {
                        libraryScanner.removeAssets(withIdentifiers: tossedIDs)
                    }
                    switch sessionSource {
                    case .album:
                        self.loadPhotos(from: self.selectedAlbum)
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
    func performBatchDelete(_ assets: [PHAsset], freed: Int64, onSuccess: @escaping () -> Void) {
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
                        self.stats.recordDelete(count: assets.count, freed: freed)
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

    func loadPhotos(from album: PHAssetCollection? = nil, startAt: Int = 0, origin: SessionOrigin = .albums) {
        isLoadingPhotos = true

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

            DispatchQueue.main.async {
                let start = min(startAt, max(result.count - 1, 0))
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
                self.videoCount = videos
                self.largeVideos = bigOnes.isEmpty ? videoItems : bigOnes
                self.largeVideosShowingAll = bigOnes.isEmpty
                self.burstAssets = burst
                self.recentAssets = recent
                self.isLoadingHome = false
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
                VStack(spacing: 6) {
                    Text("\(celebration.count) Deleted")
                        .font(Theme.display(34))
                        .foregroundColor(Theme.ink)
                    if celebration.freed > 0 {
                        Text("\(ByteCountFormatter.string(fromByteCount: celebration.freed, countStyle: .file)) freed")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundColor(Theme.dim)
                    }
                }
                .shadow(color: Theme.chipCoral.opacity(0.25), radius: 24)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(celebration.count) photos deleted")
        .onAppear(perform: run)
    }

    private func run() {
        if UIAccessibility.isReduceMotionEnabled || celebration.images.isEmpty {
            swallowed = true
            withAnimation(Theme.pop) { showNumber = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onDone() }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + swallowTime + 1.6) {
            onDone()
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
                    .font(.system(.headline))
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
            let options = PHImageRequestOptions()
            // .opportunistic: a degraded image lands immediately, the good
            // one follows — .fastFormat alone can fail with error 3303.
            options.deliveryMode = .opportunistic
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 160, height: 160),
                contentMode: .aspectFill,
                options: options
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
