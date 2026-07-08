import SwiftUI
import Photos
import PhotosUI
import UIKit

enum SessionSource {
    case album, burst, screenshots, timeCapsule
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

    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            if showSplashScreen {
                splashScreenView
            } else if showAlbumPicker {
                albumPickerView
            } else if isLoadingPhotos {
                ProgressView("Opening \(selectedAlbum?.localizedTitle ?? "All Photos")…")
                    .foregroundColor(Theme.pencil)
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
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if showSnackbar {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Theme.amberFill)
                            .frame(width: 9, height: 9)
                        Text(snackbarMessage)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.photoPaper)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.darkroom, in: Capsule())
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                    .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }

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
                    .font(Theme.display(44))
                    .foregroundColor(Theme.ink)
                    .scaleEffect(pulse ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    .onAppear {
                        pulse = true
                    }

                Text("Swipe. Keep. Delete. Done.")
                    .font(.callout)
                    .foregroundColor(Theme.pencil)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 28)

            Button("Start Organizing") {
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
                        .foregroundColor(Theme.pencil)

                    Link("Kara", destination: URL(string: "https://x.com/whysokara")!)
                        .font(.footnote)
                        .foregroundColor(Theme.safelight)
                        .underline()
                }

                Text("No signup. We don’t collect any data.")
                    .font(.footnote)
                    .foregroundColor(Theme.pencil)
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
                    onRecent: { index in loadPhotos(startAt: index) },
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
                    }
                }
            }
        }
    }

    var burstCompleteView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundColor(Theme.safelight)

            Text("Today’s burst is complete")
                .font(Theme.title)
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)

            Text("You’ve kept what matters today. Come back tomorrow for a new memory.")
                .font(.subheadline)
                .foregroundColor(Theme.pencil)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if stats.streakJustIncremented {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Theme.safelight)
                    Text("\(stats.streakCount)-day streak")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(Theme.ink)
                }
            }

            if stats.freezeJustEarned {
                HStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .foregroundColor(Theme.safelight)
                    Text("You earned a streak freeze")
                        .font(.subheadline)
                        .foregroundColor(Theme.pencil)
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
            .background(Theme.paper)
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
                        .foregroundColor(Theme.pencil)
                    Spacer()
                    Button("Manage") {
                        presentLimitedLibraryPicker()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Theme.safelight)
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
                .foregroundColor(Theme.safelight)

            Text("Leftover needs your library")
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            Text("Allow photo access in Settings to start cleaning. Photos stay on your phone — nothing is uploaded, ever.")
                .font(.subheadline)
                .foregroundColor(Theme.pencil)
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
                .foregroundColor(Theme.safelight)

            Text("Nothing leftover")
                .font(Theme.title)
                .foregroundColor(Theme.ink)

            Text("This album is spotless. Nice work.")
                .font(.subheadline)
                .foregroundColor(Theme.pencil)

            Button(sessionSource == .album ? "Back to albums" : "Back home") {
                withAnimation(Theme.settle) {
                    if sessionSource == .album {
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



    var swipeCard: some View {
        ZStack {
            VStack(spacing: 12) {
                Spacer(minLength: 40)

                ZStack {
                    if let asset = currentAsset {
                        ZStack(alignment: .topTrailing) {
                            PhotoAssetImage(asset: asset)
                                .frame(height: 450)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                                .overlay(alignment: .topLeading) {
                                    DecisionStamp(isKeep: true)
                                        .opacity(min(max(Double(dragOffset.width) - 20, 0) / 100, 1))
                                        .padding(20)
                                }
                                .overlay(alignment: .topTrailing) {
                                    DecisionStamp(isKeep: false)
                                        .opacity(min(max(Double(-dragOffset.width) - 20, 0) / 100, 1))
                                        .padding(20)
                                }
                                .padding(.horizontal)
                                .transition(.scale.combined(with: .opacity))
                                .offset(x: dragOffset.width)
                                .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                                .gesture(
                                    DragGesture()
                                        .updating($dragOffset) { value, state, _ in
                                            state = value.translation
                                        }
                                        .onEnded { value in
                                            withAnimation(Theme.flick) {
                                                if value.translation.width < -100 {
                                                    Haptics.impact(.rigid)
                                                    toBeDeleted.append(asset)
                                                    totalSize += assetFileSize(asset)
                                                    currentIndex += 1
                                                    moveToNextPhoto()
                                                } else if value.translation.width > 100 {
                                                    Haptics.impact(.soft)
                                                    currentIndex += 1
                                                    moveToNextPhoto()
                                                }
                                            }
                                        }
                                )
                                .onTapGesture(count: 2) {
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

                                .id(asset.localIdentifier)
                                .accessibilityElement()
                                .accessibilityLabel(asset.isFavorite ? "Photo \(currentIndex + 1), Favorited" : "Photo \(currentIndex + 1)")
                                .accessibilityHint(asset.isFavorite ? "Double tap to remove from favorites" : "Double tap to add to favorites")
                                .accessibilityAddTraits([.isImage])

                                .overlay(
                                    Group {
                                        if showHeartAnimation {
                                            Image(systemName: "heart.fill")
                                                .resizable()
                                                .foregroundColor(Theme.safelight)
                                                .frame(width: 30, height: 30)
                                                .scaleEffect(heartScale)
                                                .rotationEffect(.degrees(heartRotation))
                                                .offset(x: shakeOffset)
                                                .opacity(heartOpacity)
                                        }
                                    }
                                )

                            if asset.isFavorite {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(Color.white.opacity(0.5))
                                    .font(.system(size: 22, weight: .regular))
                                    .padding(.top, 8)
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                }

                if currentIndex > 0 {
                    Button(action: {
                        withAnimation(Theme.settle) {
                            currentIndex -= 1
                            let asset = photoAssets[currentIndex]
                            if toBeDeleted.contains(asset) {
                                totalSize -= assetFileSize(asset)
                                toBeDeleted.removeAll { $0 == asset }
                            }
                            currentAsset = asset
                        }
                    }) {
                        Label("Undo", systemImage: "arrow.uturn.left")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.top, 8)
                    .accessibilityLabel("Undo last action")
                    .accessibilityHint("Restores the last skipped or deleted photo")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        let visibleIndices = Array(currentIndex..<min(currentIndex + 7, photoAssets.count))

                        ForEach(visibleIndices, id: \.self) { index in
                            let asset = photoAssets[index]
                            let isCurrent = asset.localIdentifier == currentAsset?.localIdentifier

                            PhotoThumbnailView(asset: asset)
                                .frame(width: isCurrent ? 52 : 44, height: isCurrent ? 70 : 58)
                                .cornerRadius(isCurrent ? 8 : 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: isCurrent ? 8 : 6)
                                        .stroke(isCurrent ? Theme.safelight : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    withAnimation(Theme.settle) {
                                        currentIndex = index
                                        currentAsset = asset
                                    }
                                }
                                .accessibilityElement()
                                .accessibilityLabel("Thumbnail of photo \(index + 1)")
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                }

                Text("\(currentIndex + 1) / \(photoAssets.count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(Theme.pencil)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))

                if !toBeDeleted.isEmpty {
                    Button("Toss \(toBeDeleted.count) photo\(toBeDeleted.count == 1 ? "" : "s")") {
                        deleteMarkedPhotos()
                    }
                    .buttonStyle(TossButtonStyle())
                    .padding(.horizontal)
                    .padding(.top)
                    .accessibilityLabel("Toss \(toBeDeleted.count) selected photo\(toBeDeleted.count > 1 ? "s" : "")")
                    .accessibilityHint("Deletes all marked photos permanently")
                }

                Spacer()
            }

            VStack {
                HStack {
                    Button(action: {
                        withAnimation(Theme.settle) {
                            if sessionSource == .album {
                                resetToAlbumPicker()
                            } else {
                                returnHome()
                            }
                        }
                    }) {
                        Label(sessionSource == .album ? "Albums" : "Home", systemImage: "chevron.backward")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.leading, 16)
                    .accessibilityLabel(sessionSource == .album ? "Back to albums" : "Back to home")

                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 10)
        }
    }


    private var sessionEndTitle: String {
        switch sessionSource {
        case .album:       return "That’s the whole album!"
        case .burst:       return "That’s today’s burst!"
        case .screenshots: return "That’s every screenshot!"
        case .timeCapsule: return "That’s the whole capsule!"
        }
    }

    var deleteConfirmation: some View {
        VStack(spacing: 16) {
            if toBeDeleted.isEmpty {
                Text(sessionEndTitle)
                    .font(Theme.title)
                    .foregroundColor(Theme.ink)

                Text("Nothing marked — nice and tidy.")
                    .font(.subheadline)
                    .foregroundColor(Theme.pencil)

                Button(sessionSource == .album ? "Choose another album" : "Back home") {
                    withAnimation(Theme.settle) {
                        if sessionSource == .album {
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

                Text("\(toBeDeleted.count) photo\(toBeDeleted.count == 1 ? "" : "s") ready to toss.")
                    .font(.subheadline)
                    .foregroundColor(Theme.pencil)

                Button("Toss \(toBeDeleted.count) photo\(toBeDeleted.count == 1 ? "" : "s")") {
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
                    Button(sessionSource == .album ? "Choose another album" : "Back home") {
                        withAnimation(Theme.settle) {
                            if sessionSource == .album {
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
                        showToast("Tossed \(count) · freed \(formattedSize)")
                    } else {
                        showToast("Tossed \(count) photo\(count == 1 ? "" : "s")")
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
                    showToast("Couldn’t toss those — your photos are untouched.")
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

    func loadPhotos(from album: PHAssetCollection? = nil, startAt: Int = 0) {
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

            DispatchQueue.main.async {
                self.screenshotAssets = screenshots
                self.videoCount = videos
                self.timeCapsuleAssets = capsule
                self.burstAssets = burst
                self.burstIsFallback = fallback
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
                        .fill(Theme.print)
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
                    .foregroundColor(Theme.pencil)
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
                Theme.print
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
