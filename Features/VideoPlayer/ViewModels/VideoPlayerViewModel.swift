//
//  VideoPlayerViewModel.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation
import SwiftUI
import SwiftData
import SwiftVLC
import NaturalLanguage
import OSLog


struct PlaybackSession: Equatable {
    var itemID: UUID
    var generation: Int = 0
}

@Observable
@MainActor
final class VideoPlayerViewModel {
    var item: VideoItem
    var playbackSession: PlaybackSession
    let player: Player
    let hudModel: VideoPlayerHUDModel
    let controlsVisibilityModel: VideoPlayerControlsVisibilityModel
    let userConfig = PersistedUserConfig.shared
    
    var contentMode: VideoContentMode = .fit
    var playbackErrorMessage: String?
    var isAdvancedSettingsPresented = false
    
    init(
        item: VideoItem,
        player: Player,
        hudModel: VideoPlayerHUDModel,
        controlsVisibilityModel: VideoPlayerControlsVisibilityModel
    ) {
        self.item = item
        self.playbackSession = .init(itemID: item.id)
        self.player = player
        self.hudModel = hudModel
        self.controlsVisibilityModel = controlsVisibilityModel
    }
    
    // MARK: - Video Playere Core
    
    func startPlayback() {
        player.aspectRatio = contentMode.aspectRatio
        
        do {
            try player.play(url: item.url)
            playbackErrorMessage = nil
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
    }
    
    func stopPlayback() {
        player.stop()
    }
    
    func togglePlayPause() {
        withAnimation(.spring) {
            player.togglePlayPause()
            playbackErrorMessage = nil
        }
    }
    
    func seek(by offset: Duration) {
        do {
            try player.seek(by: offset)
            playbackErrorMessage = nil
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
    }
    
    func seek(to position: Double) {
        do {
            try player.seek(to: PlaybackPosition(position))
            playbackErrorMessage = nil
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
    }
    
    func seek(to time: Duration) {
        do {
            try player.seek(to: time)
            playbackErrorMessage = nil
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
    }
    
    func setContentMode(_ mode: VideoContentMode) {
        contentMode = mode
        player.aspectRatio = mode.aspectRatio
    }
    
    func setPlaybackRate(_ rate: Float) {
        do {
            try player.setPlaybackRate(PlaybackRate(rate))
            playbackErrorMessage = nil
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Subtitle adjustment
    
    var subtitleDelay: Duration = .zero
    
    func stepSubtitleDelay(by value: Duration) {
        setSubtitleDelay(subtitleDelay + value)
    }
    
    func setSubtitleDelay(_ delay: Duration, showHUD: Bool = true) {
        subtitleDelay = delay
        
        do {
            try player.setSubtitleDelay(delay)
            playbackErrorMessage = nil
            if showHUD {
                hudModel.showSubtitleDelay(Int(player.subtitleDelay / .milliseconds(1)))
            }
        } catch {
            playbackErrorMessage = error.localizedDescription
        }
        resetCueCache()
    }
    
    var lastKnownCueIndex: Int? = nil
    var lastKnownCueRange: (Duration, Duration)? = nil
    
    func resetCueCache() {
        lastKnownCueIndex = nil
        lastKnownCueRange = nil
    }
    
    /// This is to prevent the case where `currentCueIndex` catch the index of the stale `nativeSubtitles`
    func resetSubtitleRuntimeStateForPlaybackSession() {
        selectedSubtitleTrackIndex = nil
        nativeSubtitles = []
        externalSubtitleData = []
        setSubtitleDelay(.zero, showHUD: false)
    }
    
    var currentCueIndex: Int? {
        guard let selectedSubtitleIndex = selectedSubtitleTrackIndex,
              selectedSubtitleIndex < nativeSubtitles.count else {
            return nil
        }
        if let lastKnownCueRange,
           lastKnownCueRange.0 + subtitleDelay <= player.currentTime && lastKnownCueRange.1 + subtitleDelay > player.currentTime {
            return lastKnownCueIndex
        } else {
            let subtitles = nativeSubtitles[selectedSubtitleIndex]
            let currentCueIndex = subtitles.firstIndex { subtitle in
                subtitle.startTime + subtitleDelay <= player.currentTime && subtitle.endTime + subtitleDelay > player.currentTime
            }
            if let currentCueIndex {
                let currentCue = subtitles[currentCueIndex]
                lastKnownCueIndex = currentCueIndex
                lastKnownCueRange = (currentCue.startTime, currentCue.endTime)
            }
            return currentCueIndex
        }
    }
    
    var lastCueInfo: (Int, SubtitleCue)? {
        guard let selectedSubtitleIndex = selectedSubtitleTrackIndex,
              selectedSubtitleIndex < nativeSubtitles.count,
              let lastSubtitleIndex = nativeSubtitles[selectedSubtitleIndex].lastIndex(where: { $0.endTime + subtitleDelay < player.currentTime }) else {
            return nil
        }
        return (lastSubtitleIndex, nativeSubtitles[selectedSubtitleIndex][lastSubtitleIndex])
    }
    
    var nextCueInfo: (Int, SubtitleCue)? {
        guard let selectedSubtitleIndex = selectedSubtitleTrackIndex,
              selectedSubtitleIndex < nativeSubtitles.count,
              let nextSubtitleIndex = nativeSubtitles[selectedSubtitleIndex].firstIndex(where: { $0.startTime + subtitleDelay > player.currentTime }) else {
            return nil
        }
        return (nextSubtitleIndex, nativeSubtitles[selectedSubtitleIndex][nextSubtitleIndex])
    }
    
    func showNextSubtitleNow() {
        guard let (_, nextCue) = nextCueInfo else { return }
        setSubtitleDelay(player.currentTime - nextCue.startTime)
    }
    
    func showLastSubtitleNow() {
        guard let (_, lastCue) = lastCueInfo else { return }
        setSubtitleDelay(player.currentTime - lastCue.startTime)
    }
    
    // MARK: - subtitle selection and visibility
    var showExternalSubtitleImporter = false
    var showJimakuSearchView = false
    var hiddenSubtitleTrackIndex: Int? = nil
    var selectedSubtitleTrackIndex: Int? = nil {
        didSet {
            resetCueCache()
            if !PersistedUserConfig.shared.nativeSubtitleRendering {
                if let selectedSubtitleTrackIndex,
                   selectedSubtitleTrackIndex < player.subtitleTracks.count {
                    player.selectedSubtitleTrack = player.subtitleTracks[selectedSubtitleTrackIndex]
                } else {
                    player.selectedSubtitleTrack = nil
                }
            } else {
                player.selectedSubtitleTrack = nil
            }
            hiddenSubtitleTrackIndex = nil
        }
    }
    var nativeSubtitles: [[SubtitleCue]] = []
    var externalSubtitleData: [Data] = []
    
    /// These function has two phase: first use FFmpeg to extract subtitles.
    /// then restore persisted subtitles from SwiftData
    @concurrent
    private func extractNativeSubtitles(from videoURL: URL) async throws {
        let japaneseOnly = await PersistedUserConfig.shared.japaneseOnly
        let parser = SubtitleParser()
        var extractedSubtitles = try parser.extractEmbeddedSubtitles(from: videoURL)
        if japaneseOnly {
            extractedSubtitles = extractedSubtitles.map({ subtitles in
                subtitles.filter({ Self.isJapanese(text: $0.text) })
            })
        }
        await MainActor.run {
            self.nativeSubtitles = extractedSubtitles
        }
    }
    
    private func restorePersistedSubtitles() async {
        // clear runtime state from last session
        externalSubtitleData = []
        // this is also needed to clear because the first time the video is played, `item.subtitleStorage.selectedIndex == 0` 
        setSubtitleDelay(.zero, showHUD: false)
        for singleSubtitleData in item.subtitleStorage.subtitleData {
            do {
                let tmpURL = FileStorage.getTempDirectory().appending(path: UUID().uuidString)
                try singleSubtitleData.write(to: tmpURL)
                await handleSubtitleImportResult(.success(tmpURL), securityScoped: false, persist: false)
                externalSubtitleData.append(singleSubtitleData)
            } catch {
                Logger.video.error("Failed to load persisted subtitle: \(error)")
                continue
            }
        }
        if let subtitleIndex = item.subtitleStorage.selectedIndex,
           subtitleIndex < nativeSubtitles.count {
            self.selectedSubtitleTrackIndex = subtitleIndex
            self.setSubtitleDelay(item.subtitleStorage.subtitleDelay, showHUD: false)
        }
    }
    
    /// - Parameters:
    ///     - securityScoped: get access
    ///     - persist: persist to SwiftData
    @concurrent
    func handleSubtitleImportResult(
        _ result: Result<URL, any Error>,
        securityScoped: Bool = true,
        persist: Bool = true
    ) async {
        switch result {
        case .success(let url):
            if securityScoped {
                guard url.startAccessingSecurityScopedResource() else {
                    Logger.video.error("Failed to access external subtitle file \(url)")
                    return
                }
            }
            defer { url.stopAccessingSecurityScopedResource() }
            // libVLC import file asynchronously. Therefore we should copy to a place where we have access
            let targetURL: URL
            do {
                let tempDir = FileStorage.getTempDirectory()
                let fileName = UUID().uuidString.appending(".\(url.pathExtension)")
                targetURL = tempDir.appending(path: fileName)
                try FileManager.default.copyItem(at: url, to: targetURL)
            } catch {
                Logger.video.error("Failed to copy external subtitle to cache directory: \(error)")
                return
            }
            do {
                try await player.addExternalTrack(from: targetURL, type: .subtitle, select: false)
                let japaneseOnly = await PersistedUserConfig.shared.japaneseOnly
                let parser = SubtitleParser()
                var subtitleCues: [SubtitleCue]
                do {
                    subtitleCues = try parser.parse(targetURL)
                    if japaneseOnly {
                        subtitleCues = subtitleCues.filter({ Self.isJapanese(text: $0.text) })
                    }
                } catch {
                    Logger.video.error("Failed to parse external subtitle by FFmpeg: \(error)")
                    return
                }
                await MainActor.run {
                    self.nativeSubtitles.append(subtitleCues)
                    self.selectedSubtitleTrackIndex = self.nativeSubtitles.lastIndex(where: { _ in true })
                }
                if persist {
                    do {
                        let subtitleData = try Data(contentsOf: targetURL)
                        await MainActor.run {
                            self.externalSubtitleData.append(subtitleData)
                        }
                    } catch {
                        Logger.video.error("Failed to load subtitle to data")
                    }
                }
            } catch {
                Logger.video.error("Failed to add external subtitle file \(url): \(error)")
            }
        case .failure(let error):
            Logger.video.error("Failed to import external subtitle file: \(error)")
            return
        }
    }
    
    static nonisolated func isJapanese(text: String?) -> Bool {
        guard let text else {
            return false
        }
        let dominantLanguage = NLLanguageRecognizer.dominantLanguage(for: text)
        return dominantLanguage == .japanese
    }
    
    // MARK: - Bookmark
    
    var bookmarks: [VideoPlayerBookmark] = []
    
    func handleBookmarkSelected(_ bookmark: VideoPlayerBookmark) {
        guard player.isSeekable else { return }
        seek(to: bookmark.position)
        controlsVisibilityModel.show(allowingAutoHide: player.isPlaying)
    }
    
    func handleBookmarkDeleted(_ bookmark: VideoPlayerBookmark) {
        withAnimation(.easeOut(duration: 0.16)) {
            bookmarks.removeAll { $0.id == bookmark.id }
        }
        controlsVisibilityModel.show(allowingAutoHide: player.isPlaying)
    }
    
    private func bookmark(near time: Duration, position: Double) -> VideoPlayerBookmark? {
        bookmarks.first { bookmark in
            abs((bookmark.time - time).toSeconds()) <= VideoPlayerBookmarkMetrics.duplicateToleranceSeconds
            || abs(bookmark.position - position) <= VideoPlayerBookmarkMetrics.duplicatePositionTolerance
        }
    }
    
    // MARK: - gesture handling
    var showSubtitlesFullscreenView = false
    
    func handleSingleTap() {
        if controlsVisibilityModel.isVisible {
            controlsVisibilityModel.hide()
        } else {
            controlsVisibilityModel.show(allowingAutoHide: player.isPlaying)
        }
    }
    
    func handleDoubleTap(in zone: VideoPlayerGestureZone) {
        guard player.isSeekable else { return }
        
        let defaultHanlder = {
            switch zone {
            case .left:
                self.seek(by: .seconds(-10))
                self.hudModel.showSeekBackward(seconds: 10)
            case .right:
                self.seek(by: .seconds(10))
                self.hudModel.showSeekForward(seconds: 10)
            }
        }
        switch zone {
        case .left:
            guard let (_, lastCue) = lastCueInfo else {
                defaultHanlder()
                return
            }
            seek(to: lastCue.startTime + subtitleDelay)
            hudModel.showSeekBackward(seconds: nil)
        case .right:
            guard let (_, nextCue) = nextCueInfo else {
                defaultHanlder()
                return
            }
            seek(to: nextCue.startTime + subtitleDelay)
            hudModel.showSeekForward(seconds: nil)
        }
    }
    
    // values about left pan
    static let panActivationThreshold: CGFloat = 8
    static let scaleFactor = 1.35
    var currentBrightness: CGFloat?
    
    func handleLeftPanBegan() {
        guard let screen = UIScreen.keyScreen else { return }
        let initialBrightness = screen.brightness
        currentBrightness = initialBrightness
    }
    
    func handleLeftPanChanged(relativeYTranslation: RelativeYTranslation) {
        guard let currentBrightness else { return }
        let scaledTranslation = -relativeYTranslation * Self.scaleFactor
        let clampedBrightness = min(max(currentBrightness + scaledTranslation, 0), 1)
        UIScreen.keyScreen?.brightness = clampedBrightness
        hudModel.showBrightness(value: Float(clampedBrightness))
    }
    
    func handleLeftPanEnded() {
        currentBrightness = nil
    }
    
    func handleTwoFingersTap() {
        togglePlayPause()
        hudModel.showPlayPause(isPlaying: player.isPlaying)
    }
    
    func handleThreeFingersTap() {
        guard let selectedSubtitleTrackIndex = selectedSubtitleTrackIndex else { return }
        if hiddenSubtitleTrackIndex == nil {
            if !userConfig.nativeSubtitleRendering {
                // This bypasses the `didSet` of `viewModel.selectedSubtitleTrackIndex`
                player.selectedSubtitleTrack = nil
            }
            hiddenSubtitleTrackIndex = selectedSubtitleTrackIndex
            hudModel.showSubtitleHidden(true)
        } else {
            if !userConfig.nativeSubtitleRendering {
                player.selectedSubtitleTrack = player.subtitleTracks[hiddenSubtitleTrackIndex!]
            }
            hiddenSubtitleTrackIndex = nil
            hudModel.showSubtitleHidden(false)
        }
    }
    
    func handleRightSwipe() {
        guard selectedSubtitleTrackIndex != nil , !nativeSubtitles.isEmpty else { return }
        showSubtitlesFullscreenView.toggle()
    }
    
    func handleCheckMarkBookmark() {
        guard player.isSeekable else { return }
        
        let position = min(max(player.position, 0), 1)
        guard position.isFinite else { return }
        
        let time = player.currentTime
        if let existingBookmark = bookmark(near: time, position: position) {
            hudModel.showBookmarkAlreadyExists(at: existingBookmark.time)
            return
        }
        
        let bookmark = VideoPlayerBookmark(time: time, position: position)
        withAnimation(.bouncy) {
            bookmarks.append(bookmark)
            bookmarks.sort { $0.position < $1.position }
        }
        
        hudModel.showBookmarkAdded(at: bookmark.time)
    }
    
    // MARK: - on start playing
    func runAfterPlayStart(_ body: () async -> Void) async {
        for await event in player.events {
            if case let .stateChanged(playerState) = event,
               playerState == .playing {
                await body()
                break
            }
        }
    }
    
    func prepareSubtitleTrackAfterPlayStart() async {
        await runAfterPlayStart {
            selectedSubtitleTrackIndex = !player.subtitleTracks.isEmpty ? 0 : nil
            let url = item.url
            do {
                try await extractNativeSubtitles(from: url)
            } catch {
                Logger.video.error("Failed to extract subtitles from video file \(url): \(error)")
                await MainActor.run {
                    self.nativeSubtitles = []
                }
                return
            }
            await restorePersistedSubtitles()
        }
    }
    
    func restorePlaybackDataFromHistory() async {
        await runAfterPlayStart {
            let time = item.time
            if time != .zero {
                seek(to: time)
            }
            if let audioTrackIndex = item.selectedAudioTrackIndex,
               audioTrackIndex < player.audioTracks.count {
                player.selectedAudioTrack = player.audioTracks[audioTrackIndex]
            }
            setPlaybackRate(item.playbackRate)
            bookmarks = item.bookmarks
        }
    }
    
    func runAfterPlaybackStop(_ body: () async -> Void) async {
        for await event in player.events {
            if case let .stateChanged(playerState) = event,
               playerState == .stopped {
                await body()
                break
            }
        }
    }
    
    // MARK: - Scene Phase
    var playbackSnapshotBeforeSuspended: VideoItem? = nil
    var isSuspendedForBackground = false
    private var _isAnkiMing = false
    var isAnkiMining: Bool {
        get {
            _isAnkiMing
        }
        set {
            if newValue {
                _isAnkiMing = true
                isAnkiMiningResetTask1?.cancel()
                isAnkiMiningResetTask2?.cancel()
                isAnkiMiningResetTask1 = Task {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { return }
                    _isAnkiMing = false
                }
            } else {
                isAnkiMiningResetTask2?.cancel()
                isAnkiMiningResetTask2 = Task {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { return }
                    _isAnkiMing = false
                }
            }
        }
    }
    private var isAnkiMiningResetTask1: Task<Void, Never>? = nil
    private var isAnkiMiningResetTask2: Task<Void, Never>? = nil
    
    /// Handle scene phase change
    ///
    /// There are different cases that needs to be considered
    /// 1. switch to background without Anki Mining -> stop playback, increase generation of sessison
    /// 2. use plus button to mine, and mining success -> no-op
    /// 3. use plus button to mine, but mining failed or user interrupts (e.g. user does not come back from Anki). Because of `isAnkiMiningResetTask1`, `isAnkiMining` will be set to `false` again -> stop playback, increase generation of sessison
    func onScenePhaseChange(from oldValue: ScenePhase, to newValue: ScenePhase, modelContext: ModelContext) {
        Task {
            if newValue == .background {
                if player.isPlaying {
                    togglePlayPause()
                }
                // When scene phase moves to background, states inside `player` can be lost. Record before stop playing
                playbackSnapshotBeforeSuspended = item.getSnapshot(
                    time: player.currentTime,
                    position: player.position,
                    bookmarks: bookmarks,
                    subtitleStorage: VideoSubtitleStorage(
                        subtitleData: externalSubtitleData,
                        selectedIndex: selectedSubtitleTrackIndex,
                        subtitleDelay: subtitleDelay
                    ),
                    selectedAudioTrackIndex: selectedAudioTrackIndex,
                    playbackRate: player.rate
                )
                isSuspendedForBackground = true
                persistVideoItem(item, modelContext: modelContext)
            } else if oldValue == .background && newValue != .background {
                // previous solution: load the persisted newer item from disk. The problem is, persistVideoItem is async
                // when users come back from background, the persisting job may be not ended
                // if we read from SwiftData (instead of memory), we may read an outdated state. Another solution is to await the persisting task
                //            item = .getVideoItem(from: item.url, modelContext: modelContext)
                if let playbackSnapshotBeforeSuspended {
                    if !isAnkiMining {
                        // avoid users see black screen
                        controlsVisibilityModel.show(allowingAutoHide: false)
                        stopPlayback()
                        await runAfterPlaybackStop {
                            item = playbackSnapshotBeforeSuspended
                            playbackSession.generation += 1
                        }
                    } else {
                        self.playbackSnapshotBeforeSuspended = nil
                        isSuspendedForBackground = false
                    }
                }
            }
        }
    }
    
    // MARK: - persist video history
    
    var selectedAudioTrackIndex: Int? {
        guard let selectedAudioTrack = player.selectedAudioTrack else { return nil }
        return player.audioTracks.firstIndex(of: selectedAudioTrack)
    }
    
    var persistenceTasks: [URL: Task<Void, Never>] = [:]
    
    func persistVideoItem(_ item: VideoItem, modelContext: ModelContext) {
        let currentTime = playbackSnapshotBeforeSuspended?.time ?? player.currentTime
        let position = playbackSnapshotBeforeSuspended?.position ?? player.position
        let selectedAudioTrackIndex = self.selectedAudioTrackIndex
        let playbackRate = player.rate
        let bookmarks = bookmarks
        let subtitleStorage = VideoSubtitleStorage(
            subtitleData: externalSubtitleData,
            selectedIndex: selectedSubtitleTrackIndex,
            subtitleDelay: subtitleDelay
        )
        persistenceTasks[item.url] = Task {
            let url = item.url
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            let media: Media
            let imageData: Data
            do {
                media = try Media(url: url)
                imageData = try await media.thumbnail(at: currentTime, width: 1920, height: 1080, crop: true, seekMode: .precise)
            } catch {
                Logger.video.error("Failed to generate thumbnail for file \(url): \(error)")
                return
            }
            let itemId = item.id
            let histories: [VideoHistory]
            do {
                let predicate = #Predicate<VideoHistory> { history in
                    history.id == itemId
                }
                let descriptor = FetchDescriptor(predicate: predicate)
                histories = try modelContext.fetch(descriptor)
            } catch {
                Logger.video.error("Failed to load video history of id \(itemId): \(error)")
                return
            }
            if let history = histories.first {
                history.update(
                    time: currentTime,
                    position: position,
                    bookmarks: bookmarks,
                    subtitleStorage: subtitleStorage,
                    selectedAudioTrackIndex: selectedAudioTrackIndex,
                    playbackRate: playbackRate,
                    thumbnailData: imageData
                )
            } else {
                do {
                    let history = try item.updateToHistory(
                        time: currentTime,
                        position: position,
                        bookmarks: bookmarks,
                        thumbnailData: imageData,
                        subtitleStorage: subtitleStorage,
                        selectedAudioTrackIndex: selectedAudioTrackIndex,
                        playbackRate: playbackRate
                    )
                    modelContext.insert(history)
                } catch {
                    Logger.video.error("Failed to generate bookmark for url \(url): \(error)")
                    return
                }
            }
            withAnimation(.bouncy) {
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Queue
    var itemsFromSameDirectories: [VideoItem] = []
    
    func loadItemsFromSameDirectories(modelContext: ModelContext) async {
        itemsFromSameDirectories = []
        let itemURL = item.url
        let dirURL = itemURL.deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil) else {
            return
        }
        let files = contents.filter({ !$0.isDirectory() })
        var items = [VideoItem]()
        for file in files {
            if let task = persistenceTasks[file] {
                await task.value
            }
            items.append(
                VideoItem.getVideoItem(from: file, modelContext: modelContext)
            )
        }
        items.sort { (item1: VideoItem, item2: VideoItem) in
            item1.displayTitle.localizedStandardCompare(item2.displayTitle) == .orderedAscending
        }
        // Current task can be cancelled by SwiftUI runtime when item is changed
        guard !Task.isCancelled, item.url == itemURL else { return }
        itemsFromSameDirectories = items
    }
}

// Metrics

private enum VideoPlayerBookmarkMetrics {
    static let duplicateToleranceSeconds = 1.0
    static let duplicatePositionTolerance = 0.002
}
