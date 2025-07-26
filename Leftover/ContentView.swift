import SwiftUI
import Photos
import UIKit

struct ContentView: View {
    @State private var photoAssets: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var toBeDeleted: [PHAsset] = []
    @State private var totalSize: Int64 = 0
    @State private var showDeleteButton = false
    @State private var showAlbumPicker = true
    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection? = nil
    @State private var currentAsset: PHAsset? = nil
    @State private var isDeleting = false
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""
    @State private var allPhotosThumbnail: UIImage?
    @State private var allPhotosCount: Int = 0
    @State private var sortedAlbums: [AlbumMeta] = []
    @State private var albumSearchText: String = ""
    @State private var favoritedAssets: [PHAsset] = []
    @State private var showHeartAnimation = false
    @State private var heartScale: CGFloat = 1.0
    @State private var isAddingToFavorites: Bool = true
    @State private var shakeOffset: CGFloat = 0
    @State private var heartRotation: Double = 0
    @State private var heartOpacity: Double = 1.0
    @State private var showSplashScreen = true

    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if showSplashScreen {
                splashScreenView
            } else if showAlbumPicker {
                albumPickerView
            } else if currentIndex < photoAssets.count {
                swipeCard
            } else if showDeleteButton {
                deleteConfirmation
            } else {
                ProgressView("Loading photos...")
            }

            if isDeleting {
                ProgressView("Deleting...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }

            if showSnackbar {
                VStack {
                    Spacer()
                    Text(snackbarMessage)
                        .font(.subheadline)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom))
            }
        }

        .onChange(of: currentIndex) { newIndex in
            if newIndex < photoAssets.count {
                currentAsset = photoAssets[newIndex]
            }
        }
    }
    var splashScreenView: some View {
        VStack {
            Spacer()

            VStack(spacing: 6) {
                Text("LeftOver")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundColor(.primary)

                Text("Swipe. Keep. Delete. Done.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)

            Button(action: {
                withAnimation {
                    showSplashScreen = false
                    showAlbumPicker = true
                }
            }) {
                Text("Start Organizing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            Spacer()

            VStack(spacing: 4) {
                Text("Built by Kara with care.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text("No signup. We don’t collect any data.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
        }
        .multilineTextAlignment(.center)
        .padding()
    }





    var albumPickerView: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    AlbumGridItem(
                        title: "All Photos",
                        count: allPhotosCount,
                        thumbnail: allPhotosThumbnail
                    ) {
                        self.selectedAlbum = nil
                        self.showAlbumPicker = false
                        self.loadPhotos()
                    }

                    ForEach(sortedAlbums, id: \ .collection.localIdentifier) { albumMeta in
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
                .padding()
            }
            .navigationTitle("Choose Folder")
            .onAppear {
                PHPhotoLibrary.requestAuthorization { status in
                    if status == .authorized || status == .limited {
                        fetchAlbums()
                    }
                }
            }
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
                                .cornerRadius(16)
                                .shadow(radius: 8)
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
                                            withAnimation(.easeInOut) {
                                                if value.translation.width < -100 {
                                                    toBeDeleted.append(asset)
                                                    currentIndex += 1
                                                    moveToNextPhoto()
                                                } else if value.translation.width > 100 {
                                                    currentIndex += 1
                                                    moveToNextPhoto()
                                                }
                                            }
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()

                                    guard let asset = currentAsset else { return }
                                    isAddingToFavorites = !asset.isFavorite
                                    showHeartAnimation = true

                                    if isAddingToFavorites {
                                        // Add to favorites
                                        heartOpacity = 1.0
                                        heartRotation = 0
                                        heartScale = 0.8

                                        withAnimation(.interpolatingSpring(stiffness: 100, damping: 6)) {
                                            heartScale = 1.4
                                        }
                                    } else {
                                        // Remove from favorites
                                        heartScale = 1.0
                                        heartOpacity = 0.6

                                        // Wiggle and tilt
                                        withAnimation(Animation.linear(duration: 0.15).repeatCount(4, autoreverses: true)) {
                                            shakeOffset = 6
                                            heartRotation = -10
                                        }

                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            shakeOffset = 0
                                            heartRotation = 0

                                            // Shrink and fade
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                heartScale = 0.6
                                                heartOpacity = 0.0
                                            }
                                        }
                                    }

                                    // Toggle favorite state
                                    toggleFavorite(asset)

                                    // Reset everything after animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        showHeartAnimation = false
                                        heartOpacity = 1.0
                                        heartScale = 1.0
                                        heartRotation = 0
                                        shakeOffset = 0
                                    }
                                }


                                .id(asset.localIdentifier)
                                .overlay(
                                    Group {
                                        if showHeartAnimation {
                                            Image(systemName: "heart.fill")
                                                .resizable()
                                                .foregroundColor(Color.blue)
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
                        withAnimation {
                            currentIndex -= 1
                            let asset = photoAssets[currentIndex]
                            toBeDeleted.removeAll { $0 == asset }
                            favoritedAssets.removeAll { $0 == asset }
                            currentAsset = asset
                        }
                    }) {
                        Label("Undo", systemImage: "arrow.uturn.left")
                            .font(.subheadline)
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }

//                Text("\u{2192} Swipe right to keep.  \u{2190} Swipe left to clean.")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//
//                Text("Photo \(currentIndex + 1) of \(photoAssets.count)")
//                    .font(.footnote)
//                    .foregroundColor(.secondary)
            

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        let countToShow = min(7, photoAssets.count)
                        let visibleIndices = (0..<countToShow).map { (currentIndex + $0) % photoAssets.count }

                        ForEach(visibleIndices, id: \.self) { index in
                            let asset = photoAssets[index]
                            let isCurrent = asset.localIdentifier == currentAsset?.localIdentifier

                            PhotoThumbnailView(asset: asset)
                                .frame(width: isCurrent ? 52 : 44, height: isCurrent ? 70 : 58)
                                .cornerRadius(isCurrent ? 8 : 6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: isCurrent ? 8 : 6)
                                        .stroke(isCurrent ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut) {
                                        currentIndex = index
                                        currentAsset = asset
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)

                    // 👇 ADD THIS BLOCK DIRECTLY TO THE HSTACK
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                withAnimation(.easeInOut) {
                                    if value.translation.width < -50 {
                                        // swipe left → next image
                                        if currentIndex < photoAssets.count - 1 {
                                            currentIndex += 1
                                            currentAsset = photoAssets[currentIndex]
                                        }
                                    } else if value.translation.width > 50 {
                                        // swipe right → previous image
                                        if currentIndex > 0 {
                                            currentIndex -= 1
                                            currentAsset = photoAssets[currentIndex]
                                        }
                                    }
                                }
                            }
                    )
                }


                if !toBeDeleted.isEmpty {
                    Button("Delete \(toBeDeleted.count) Now") {
                        deleteMarkedPhotos()
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top)
                }

                Spacer()
            }

            VStack {
                HStack {
                    Button(action: {
                        withAnimation {
                            resetToAlbumPicker()
                        }
                    }) {
                        Label("Albums", systemImage: "chevron.backward")
                            .font(.subheadline)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
                    .padding(.leading, 16)

                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 10)
        }
    }


    var deleteConfirmation: some View {
        VStack(spacing: 20) {
            Text("You're done swiping!")
                .font(.title2)
                .bold()

            Text("\(toBeDeleted.count) photos marked for deletion.")

            Button("Delete Now") {
                deleteMarkedPhotos()
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)

            Button("Choose Another Folder") {
                withAnimation {
                    resetToAlbumPicker()
                }
            }
            .font(.subheadline)
            .padding(.top)
            .foregroundColor(.blue)
        }
    }

  
    func toggleFavorite(_ asset: PHAsset) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = !asset.isFavorite
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    if asset.isFavorite {
                        favoritedAssets.removeAll { $0 == asset }
                    } else {
                        favoritedAssets.append(asset)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSnackbar = false
                    }
                    currentIndex += 1
                    moveToNextPhoto()
                } else {
                    print("Favorite toggle failed: \(error?.localizedDescription ?? "unknown error")")
                }
            }
        }
    }


    func favoritePhoto(_ asset: PHAsset) {
        let currentlyFavorite = asset.isFavorite
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = !currentlyFavorite
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    if currentlyFavorite {
                        favoritedAssets.removeAll { $0 == asset }
                        snackbarMessage = "Removed from Favorites"
                    } else {
                        favoritedAssets.append(asset)
                        snackbarMessage = "Added to Favorites"
                    }
//                    showSnackbar = true
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                        showSnackbar = false
//                    }
                    currentIndex += 1
                    moveToNextPhoto()
                } else {
                    print("Failed to toggle favorite: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }


    func moveToNextPhoto() {
        if currentIndex >= photoAssets.count {
            showDeleteButton = true
        } else {
            currentAsset = photoAssets[currentIndex]
        }
    }

    func deleteMarkedPhotos() {
        isDeleting = true
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(self.toBeDeleted as NSArray)
        }) { success, error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isDeleting = false
                if success {
                    let formattedSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
                    snackbarMessage = "Deleted \(toBeDeleted.count) photos, freed up \(formattedSize)"
                    showSnackbar = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSnackbar = false
                    }

                    self.toBeDeleted.removeAll()
                    self.totalSize = 0
                    self.currentIndex = 0
                    self.loadPhotos(from: self.selectedAlbum)
                } else {
                    print("❌ Error: \(error?.localizedDescription ?? "unknown")")
                }
                self.showDeleteButton = false
            }
        }
    }

    func resetToAlbumPicker() {
        self.showAlbumPicker = true
        self.photoAssets = []
        self.currentIndex = 0
        self.toBeDeleted = []
        self.totalSize = 0
        self.selectedAlbum = nil
        self.currentAsset = nil
        self.showDeleteButton = false
    }

    func loadPhotos(from album: PHAssetCollection? = nil) {
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
            self.photoAssets = result
            self.currentIndex = 0
            self.toBeDeleted = []
            self.totalSize = 0
            self.currentAsset = result.first
        }
    }

    func fetchAlbums() {
        var all: [AlbumMeta] = []

        let options = PHFetchOptions()
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)

        let allCollections = [userAlbums, smartAlbums].flatMap { result in
            var temp: [PHAssetCollection] = []
            result.enumerateObjects { collection, _, _ in temp.append(collection) }
            return temp
        }

        let imageManager = PHCachingImageManager()

        for collection in allCollections {
            let assets = PHAsset.fetchAssets(in: collection, options: options)
            guard let firstAsset = assets.firstObject else { continue }

            let latestDate = assets.firstObject?.creationDate ?? Date.distantPast
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

        self.sortedAlbums = all.sorted { $0.latestDate > $1.latestDate }

        let allAssets = PHAsset.fetchAssets(with: .image, options: options)
        self.allPhotosCount = allAssets.count
        if let first = allAssets.firstObject {
            let reqOptions = PHImageRequestOptions()
            reqOptions.deliveryMode = .fastFormat
            reqOptions.isSynchronous = true
            reqOptions.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: first,
                                                  targetSize: CGSize(width: 300, height: 300),
                                                  contentMode: .aspectFill,
                                                  options: reqOptions) { result, _ in
                self.allPhotosThumbnail = result
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
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width / 2 - 32, height: 120)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width / 2 - 32, height: 120)
                        .cornerRadius(12)
                        .overlay(ProgressView())
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(count) Photos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
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
                Color.gray.opacity(0.2)
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

