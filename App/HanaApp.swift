//
//  HanaApp.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import AVFoundation
import SwiftUI
import SwiftData
import SwiftVLC
import HoshiReader

@main
struct HanaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    let userConfig = UserConfig.shared
    
    init() {
        prepareURLs()
        prepareVideoPlayer()
    }
    
    var body: some Scene {
        WindowGroup {
            HomeScreenView()
                .hoshiRootModifier(scenePhase: scenePhase, scheme: "hana")
                .environment(userConfig)
                .interfaceOrientation(.portrait)
                .modelContainer(for: [VideoHistory.self, SubtitleCache.self])
        }
    }
}

extension HanaApp {
    func prepareURLs() {
        let videosURL = try! FileStorage.getVideosDirectory()
        if !FileManager.default.fileExists(atPath: videosURL.path(percentEncoded: false)) {
            try? FileManager.default.createDirectory(at: videosURL, withIntermediateDirectories: true)
        }
    }
    
    func prepareVideoPlayer() {
        VLCInstance.prewarmShared()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationMask: UIInterfaceOrientationMask = .portrait
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }
}
