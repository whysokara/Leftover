// Leftover - A Slick Swipe-to-Clean iOS App
// Built with SwiftUI + PhotoKit

import SwiftUI
import Photos

struct ContentView: View {
    @State private var photoAssets: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var toBeDeleted: [PHAsset] = []
    @State private var totalSize: Int64 = 0
    @State private var showDeleteButton = false
    @State private var showIntro = true
    @State private var currentAsset: PHAsset? = nil
    @GestureState private var dragOffset: CGSize = .zero
    @State private var isDeleting = false
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            if showIntro {
                introScreen
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
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                        .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized, .limited:
                    loadPhotos()
                case .denied, .restricted:
                    print("Permission denied")
                case .notDetermined:
                    print("Permission not determined")
                @unknown default:
                    print("Unknown authorization status")
                }
            }
        }
        .onChange(of: currentIndex) { newIndex in
            if newIndex < photoAssets.count {
                currentAsset = photoAssets[newIndex]
            }
        }
    }
    
    var introScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Leftover")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                Button(action: {
                    withAnimation {
                        showIntro = false
                        if !photoAssets.isEmpty {
                            currentAsset = photoAssets[currentIndex]
                        }
                    }
                }) {
                    Text("Start Cleaning")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Made with Love by")
                            .foregroundColor(.white)
                            .font(.footnote)
                        
                        Text("Kara")
                            .bold()
                            .foregroundColor(.blue)
                            .underline()
                            .font(.footnote)
                            .onTapGesture {
                                if let url = URL(string: "https://x.com/whysokara") {
                                    UIApplication.shared.open(url)
                                }
                            }
                    }
                    
                    Text("© \(Calendar.current.component(.year, from: Date()))")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    var swipeCard: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                if let asset = currentAsset {
                    PhotoAssetImage(asset: asset)
                        .frame(height: 450)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .padding()
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
                                            toBeDeleted.append(photoAssets[currentIndex])
                                        }
                                        currentIndex += 1
                                        
                                        if currentIndex >= photoAssets.count {
                                            showDeleteButton = true
                                        } else if currentIndex < photoAssets.count {
                                            currentAsset = photoAssets[currentIndex]
                                        }
                                    }
                                }
                        )
                        .id(asset.localIdentifier)
                }
                
                if currentIndex > 0 {
                    Button(action: {
                        withAnimation {
                            currentIndex -= 1
                            let asset = photoAssets[currentIndex]
                            toBeDeleted.removeAll { $0 == asset }
                            currentAsset = asset
                        }
                    }) {
                        Label("Undo", systemImage: "arrow.uturn.left")
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    .padding(.leading)
                    .padding(.bottom, 8)
                }
            }
            
            Text("→ Swipe right to keep.  ← Swipe left to clean.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 4)
            
            Text("Photo \(currentIndex + 1) of \(photoAssets.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !toBeDeleted.isEmpty {
                Button("Delete \(toBeDeleted.count) Now") {
                    deleteMarkedPhotos()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemRed))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)
            }
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
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemRed))
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var result: [PHAsset] = []
        assets.enumerateObjects { (asset, _, _) in result.append(asset) }
        
        DispatchQueue.main.async {
            self.photoAssets = result
            self.currentIndex = 0
            if !result.isEmpty {
                self.currentAsset = result[0]
            }
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
                    self.loadPhotos()
                } else {
                    print("❌ Error: \(error?.localizedDescription ?? "unknown")")
                }
                self.showDeleteButton = false
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
