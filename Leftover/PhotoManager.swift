//
//  PhotoManager.swift
//  Leftover
//
//  Created by Kara on 26/07/25.
//

import Foundation
import Photos
import UIKit

class PhotoManager: ObservableObject {
    @Published var images: [UIImage] = []
    private var assets: [PHAsset] = []

    func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                self.fetchPhotos()
            }
        }
    }

    private func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        self.assets = (0..<result.count).map { result.object(at: $0) }

        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true

        DispatchQueue.global(qos: .userInitiated).async {
            var uiImages: [UIImage] = []
            for asset in self.assets {
                imageManager.requestImage(for: asset,
                                          targetSize: CGSize(width: 600, height: 600),
                                          contentMode: .aspectFit,
                                          options: requestOptions) { image, _ in
                    if let image = image {
                        uiImages.append(image)
                    }
                }
            }

            DispatchQueue.main.async {
                self.images = uiImages
            }
        }
    }

    func deleteImage(at index: Int) {
        guard index < assets.count else { return }
        let assetToDelete = assets[index]

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([assetToDelete] as NSArray)
        } completionHandler: { success, error in
            if success {
                DispatchQueue.main.async {
                    self.images.remove(at: index)
                    self.assets.remove(at: index)
                }
            } else {
                print("Failed to delete photo: \(String(describing: error))")
            }
        }
    }

    func keepImage(at index: Int) {
        // Just remove it from view, but don't delete from library
        DispatchQueue.main.async {
            self.images.remove(at: index)
            self.assets.remove(at: index)
        }
    }
}

