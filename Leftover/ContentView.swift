import SwiftUI
import Photos
import PhotosUI
import UIKit

enum SessionSource {
    case album, burst, screenshots, timeCapsule
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
    @State private var showSplashScreen = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

    @StateObject private var stats = Stats()
    @StateObject private var notifications = NotificationManager()
    @State private var sessionSource: SessionSource = .album
    @State private var sessionOrigin: SessionOrigin = .home
    @State private var sessionActive = false
    @State private var showBurstComplete = false
    @State private var showSettings = false
    @State private var isLoadingHome = false
    @State private var screenshotAssets: [PHAsset] = []
    @State private var timeCapsuleAssets: [PHAsset] = []
    @State private var burstAssets: [PHAsset] = []
    @State private var burstIsFallback = false
    @State private var videoCount = 0
    @State private var recentAssets: [PHAsset] = []
    @Environment(\.scenePhase) private var scenePhase

    // Swipe-card physics: offset follows the finger, then animates the
    // card off-screen (throw) or back to center (settle).
    @State private var cardOffset: CGSize = .zero
    @State private var isThrowingCard = false
    @State private var showExitAlert = false
    @State private var burstBackdrop: UIImage? = nil

    var body: some View {
        ZStack {
            Theme.stage.ignoresSafeArea()

            if showSplashScreen {
                splashScreenView
            } else if showAlbumPicker {
                albumPickerView
            } else if isLoadingPhotos {
                ProgressView("Opening \(selectedAlbum?.localizedTitle ?? "All Photos")…")
                    .foregroundColor(Theme.dim)
            } else if sessionActive && currentIndex < photoAssets.count {
                swipeCard
            } else if sessionActive && showDeleteButton {
                deleteConfirmation
            } else if sessionActive {
                emptyAlbumView
            } else if showBurstComplete {
                burstCompleteView
            } else {
                homeView
            }

            if isDeleting {
                ProgressView("Tossing…")
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
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
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
        }
        .preferredColorScheme(.dark)
        .onChange(of: currentIndex) { newIndex in
            if newIndex < photoAssets.count {
                currentAsset = photoAssets[newIndex]
            }
        }
        .onChange(of: scenePhase) { phase in
            // Reminder only fires if today's burst isn't done — refresh on
            // every backgrounding so completing a burst cancels the nudge.
            if phase == .background {
                notifications.reschedule(burstDoneToday: stats.isBurstDoneToday)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(notifications: notifications, stats: stats)
        }
    }
    var splashScreenView: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                Text("Leftover")
                    .font(Theme.display(48))
                    .foregroundColor(Theme.cream)
                    .scaleEffect(pulse ? 1.0 : 0.96)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                    .background(
                        // The spotlight — a soft cream pool behind the wordmark.
                        RadialGradient(colors: [Theme.cream.opacity(0.14), .clear],
                                       center: .center, startRadius: 10, endRadius: 220)
                            .frame(width: 440, height: 440)
                    )
                    .onAppear {
                        pulse = true
                    }

                Text("Swipe. Keep. Done.")
                    .font(.callout)
                    .foregroundColor(Theme.dim)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 28)

            Button("Start") {
                stats.hasLaunchedBefore = true
                withAnimation(Theme.settle) {
                    showSplashScreen = false
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 64)

            Spacer()

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Built by")
                        .font(.footnote)
                        .foregroundColor(Theme.dim)

                    Link("Kara", destination: URL(string: "https://x.com/whysokara")!)
                        .font(.footnote)
                        .foregroundColor(Theme.cream)
                        .underline()
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
                    burstCount: burstAssets.count,
                    burstIsFallback: burstIsFallback,
                    burstDone: stats.isBurstDoneToday,
                    burstBackdrop: burstBackdrop,
                    screenshotCount: screenshotAssets.count,
                    videoCount: videoCount,
                    timeCapsuleCount: timeCapsuleAssets.count,
                    recentAssets: recentAssets,
                    isLoading: isLoadingHome,
                    onSettings: { showSettings = true },
                    onStartBurst: { startSession(.burst, assets: burstAssets) },
                    onScreenshots: { startSession(.screenshots, assets: screenshotAssets) },
                    onTimeCapsule: { startSession(.timeCapsule, assets: timeCapsuleAssets) },
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
                        // Headless-verification hook: jump straight into an
                        // All Photos session (simctl launch … -LeftoverAutoSession).
                        if ProcessInfo.processInfo.arguments.contains("-LeftoverAutoSession"),
                           !self.sessionActive {
                            self.loadPhotos(origin: .home)
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
                .font(.system(size: 48))
                .foregroundColor(Theme.cream)
                .scaleEffect(celebrationScale)
                .shadow(color: Theme.cream.opacity(0.45), radius: 24)
                .onAppear {
                    celebrationScale = 0.4
                    withAnimation(Theme.pop) { celebrationScale = 1.0 }
                }

            Text("Done for today.")
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
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(Theme.ink)
                }
            }

            if stats.freezeJustEarned {
                HStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .foregroundColor(Theme.cream)
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        withAnimation(Theme.settle) {
                            showAlbumPicker = false
                        }
                    } label: {
                        Label("Home", systemImage: "chevron.backward")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
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
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(Theme.cream)

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
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(Theme.cream)

            Text("Nothing leftover")
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            Text("Already spotless.")
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
        .alert("Toss the \(toBeDeleted.count) you marked?", isPresented: $showExitAlert) {
            Button("Toss \(toBeDeleted.count)", role: .destructive) {
                deleteMarkedPhotos()
            }
            Button("Discard marks") {
                withAnimation(Theme.settle) { exitSession() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func dragProgress(_ distance: CGFloat) -> Double {
        Double(min(max(distance - 24, 0) / 220, 1))
    }

    private var reviewTopBar: some View {
        HStack(spacing: 14) {
            Button {
                if toBeDeleted.isEmpty {
                    withAnimation(Theme.settle) { exitSession() }
                } else {
                    showExitAlert = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("End session")

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
            .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 12, weight: .semibold))
                Text("\(toBeDeleted.count)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
            }
            .foregroundColor(Theme.toss)
            .accessibilityElement()
            .accessibilityLabel("\(toBeDeleted.count) marked to toss")

            Spacer()

            HStack(spacing: 5) {
                Text("\(max(currentIndex - toBeDeleted.count, 0))")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(Theme.keep)
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
                        .foregroundColor(Theme.cream.opacity(0.85))
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
        DragGesture()
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
            Text("Toss \(toBeDeleted.count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.toss, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Toss \(toBeDeleted.count) marked photos now")
    }

    private var actionDock: some View {
        HStack(spacing: 4) {
            dockButton("trash", tint: Theme.toss, label: "Toss this photo") {
                throwCard(toss: true)
            }
            dockButton("arrow.uturn.left",
                       tint: currentIndex > 0 ? Theme.ink : Theme.dim.opacity(0.35),
                       label: "Undo") {
                undoLast()
            }
            .disabled(currentIndex == 0)
            dockButton(currentAsset?.isFavorite == true ? "star.fill" : "star",
                       tint: Theme.cream, label: "Favorite") {
                favoriteCurrent()
            }
            dockButton("checkmark", tint: Theme.keep, label: "Keep this photo") {
                throwCard(toss: false)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
    }

    private func dockButton(_ icon: String, tint: Color, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 60, height: 52)
        }
        .buttonStyle(ScaleButtonStyle())
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
        guard currentIndex > 0 else { return }
        Haptics.impact(.light)
        withAnimation(Theme.stackAdvance) {
            currentIndex -= 1
            let asset = photoAssets[currentIndex]
            if toBeDeleted.contains(asset) {
                totalSize -= assetFileSize(asset)
                toBeDeleted.removeAll { $0 == asset }
            }
            currentAsset = asset
        }
        cardOffset = .zero
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
        case .album:       return "Album clear."
        case .burst:       return "Burst done."
        case .screenshots: return "Screenshots clear."
        case .timeCapsule: return "Capsule clear."
        }
    }

    var deleteConfirmation: some View {
        VStack(spacing: 16) {
            if toBeDeleted.isEmpty {
                Text(sessionEndTitle)
                    .font(Theme.title)
                    .foregroundColor(Theme.ink)

                Text("Nothing marked.")
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

                Text("\(toBeDeleted.count) ready to toss.")
                    .font(.subheadline)
                    .foregroundColor(Theme.dim)

                Button("Toss \(toBeDeleted.count)") {
                    deleteMarkedPhotos()
                }
                .buttonStyle(TossButtonStyle())
                .padding(.horizontal)
                .padding(.top, 8)

                if sessionSource == .burst {
                    // Backing out of a toss still finishes the burst — the
                    // habit is showing up, not deleting.
                    Button("Keep them instead") {
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
        isDeleting = true
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
                    if totalSize > 0 {
                        let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                        showToast("\(count) tossed · \(formattedSize) freed")
                    } else {
                        showToast("\(count) tossed")
                    }

                    self.toBeDeleted.removeAll()
                    self.totalSize = 0
                    self.currentIndex = 0
                    self.showDeleteButton = false
                    switch sessionSource {
                    case .album:
                        self.loadPhotos(from: self.selectedAlbum)
                    case .burst:
                        sessionActive = false
                        withAnimation(Theme.settle) { showBurstComplete = true }
                    case .screenshots, .timeCapsule:
                        withAnimation(Theme.settle) { returnHome() }
                        loadHomeData()
                    }
                } else {
                    // Also reached when the user taps "Don't Allow" on the
                    // system dialog — keep all state so they can retry.
                    showToast("Couldn’t toss. Photos untouched.")
                }
            }
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
        PHAssetResource.assetResources(for: asset)
            .compactMap { $0.value(forKey: "fileSize") as? Int64 }
            .first ?? 0
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

    /// Computes everything the home dashboard shows: screenshot / video
    /// counts, the "this week, years ago" time capsule set, today's burst
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

            let videos = PHAsset.fetchAssets(with: .video, options: nil).count

            // "This week, years ago" — the current ISO week in each prior
            // year, oldest year first so the burst starts furthest back.
            var capsule: [PHAsset] = []
            let calendar = Calendar(identifier: .iso8601)
            let now = Date()
            for yearsBack in stride(from: 15, through: 1, by: -1) {
                guard let past = calendar.date(byAdding: .year, value: -yearsBack, to: now),
                      let week = calendar.dateInterval(of: .weekOfYear, for: past) else { continue }
                let options = PHFetchOptions()
                options.predicate = NSPredicate(
                    format: "creationDate >= %@ AND creationDate < %@",
                    week.start as NSDate, week.end as NSDate)
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                PHAsset.fetchAssets(with: .image, options: options)
                    .enumerateObjects { asset, _, _ in capsule.append(asset) }
            }

            // Burst: up to 10 memories; if the week is empty, sweep the
            // newest 10 screenshots instead so the habit never dead-ends.
            let burst: [PHAsset]
            let fallback: Bool
            if capsule.isEmpty {
                burst = Array(screenshots.prefix(10))
                fallback = true
            } else {
                burst = Array(capsule.prefix(10))
                fallback = false
            }

            let recentOptions = PHFetchOptions()
            recentOptions.sortDescriptors = newestFirst
            recentOptions.fetchLimit = 9
            var recent: [PHAsset] = []
            PHAsset.fetchAssets(with: .image, options: recentOptions)
                .enumerateObjects { asset, _, _ in recent.append(asset) }

            // Backdrop for the photo-backed burst card (blurred under a scrim).
            var backdrop: UIImage?
            if let first = burst.first {
                let req = PHImageRequestOptions()
                req.deliveryMode = .fastFormat
                req.isSynchronous = true
                req.isNetworkAccessAllowed = true
                PHImageManager.default().requestImage(for: first,
                                                      targetSize: CGSize(width: 600, height: 600),
                                                      contentMode: .aspectFill,
                                                      options: req) { result, _ in
                    backdrop = result
                }
            }

            DispatchQueue.main.async {
                self.screenshotAssets = screenshots
                self.videoCount = videos
                self.timeCapsuleAssets = capsule
                self.burstAssets = burst
                self.burstIsFallback = fallback
                self.burstBackdrop = backdrop
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
                requestOptions.deliveryMode = .fastFormat
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
                reqOptions.deliveryMode = .fastFormat
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
                    .font(.system(.headline, design: .rounded))
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
            image = result
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
            options.deliveryMode = .fastFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 80, height: 80),
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                image = result
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
