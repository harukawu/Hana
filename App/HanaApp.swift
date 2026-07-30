//
//  HanaApp.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import AVFoundation
import Foundation
import SwiftUI
import SwiftData
import SwiftVLC
import HoshiReader

@main
struct HanaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let userConfig = UserConfig.shared

    init() {
        prepareURLs()
        prepareVideoPlayer()
    }

    var body: some Scene {
        WindowGroup {
            HanaRootView()
                .environment(userConfig)
                .interfaceOrientation(.portrait)
                .modelContainer(for: [VideoHistory.self, SubtitleCache.self, MiningHistory.self])
        }
    }
}

private struct HanaRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var miningHistoryCoordinator = MiningHistoryCoordinator()

    var body: some View {
        HomeScreenView()
            .hoshiRootModifier(scenePhase: scenePhase, scheme: "hana")
            .environment(miningHistoryCoordinator)
            .task {
                for await _ in NotificationCenter.default.messages(
                    of: HoshiAnkiManager.self,
                    for: .ankiAddNoteSuccess
                ) {
                    miningHistoryCoordinator.receiveAnkiSuccess(in: modelContext)
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
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationMask: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationMask
    }
}
