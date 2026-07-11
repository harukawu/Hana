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
    
    let userConfig = PersistedUserConfig.shared
    
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
                .modelContainer(for: VideoHistory.self)
                .task { try? clearHistories() }
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
    
    private var `7daysAgo`: Date {
        Date.now.addingTimeInterval(-7 * 24 * 3600)
    }
    
    func clearHistories() throws {
        let container = try ModelContainer(for: VideoHistory.self)
        let context = container.mainContext
        let `7daysAgo` = `7daysAgo`
        let predicate = #Predicate<VideoHistory> { history in
            history.modificationDate < `7daysAgo`
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let hitories = try context.fetch(descriptor)
        hitories.forEach { history in
            context.delete(history)
        }
        try context.save()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationMask: UIInterfaceOrientationMask = .portrait
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }
}
