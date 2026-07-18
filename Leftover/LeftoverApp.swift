//
//  LeftoverApp.swift
//  Leftover
//
//  Created by Kara on 25/07/25.
//

import SwiftUI

/// One source of truth for every share surface (celebration pill,
/// Settings "Share Leftover" row). Swap `site` for the App Store URL
/// once the app is live so shares land on the install page.
enum AppLink {
    static let site = URL(string: "https://whysokara.github.io/Leftover/")!
    /// The friend-to-friend pitch — outcome first, trust second.
    static let invite = "I've been cleaning my camera roll with Leftover — swipe left to delete, and it finds your duplicates, screenshots, and blurry shots. Free, no account, photos never leave your phone."
}

@main
struct LeftoverApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
