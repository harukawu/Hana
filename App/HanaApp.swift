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
                .modelContainer(for: VideoHistory.self)
                .task {
                    try? clearHistories()
                    try? await resolveMismatchedURLs()
                }
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
    
    func resolveMismatchedURLs() async throws {
        let container = try ModelContainer(for: VideoHistory.self)
        let context = container.mainContext
        let predicate = #Predicate<VideoHistory> { _ in true }
        let descriptor = FetchDescriptor(predicate: predicate)
        let hitories = try context.fetch(descriptor)
        let historyDict = Dictionary(zip(hitories.map(\.id), hitories), uniquingKeysWith: { old, new in new })
        let bookmarkDict = Dictionary(zip(hitories.map(\.id), hitories.map(\.urlBookmark)), uniquingKeysWith: { old, new in new })
        await withTaskGroup(of: (UUID, URL)?.self) { group in
            for (id, bookmark) in bookmarkDict {
                group.addTask {
                    var isStale = false
                    guard let resolvedURL = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale),
                          !isStale else {
                        return nil
                    }
                    return (id, resolvedURL)
                }
            }
            for await result in group {
                guard let result else { return }
                let (id, newURL) = result
                guard let currentHistory = historyDict[id] else { return }
                if newURL != currentHistory.url {
                    currentHistory.url = newURL
                }
            }
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
