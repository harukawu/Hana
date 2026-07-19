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
import MediaPlayer
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
    let userConfig: UserConfig
    var playbackSession: PlaybackSession
    let player: Player
    let hudModel: VideoPlayerHUDModel
    let controlsVisibilityModel: VideoPlayerControlsVisibilityModel
    let subtitleState: SubtitleState
    let systemMediaManager: SystemMediaManager
    
    var contentMode: VideoContentMode = .fit
    var playbackErrorMessage: String?
    var isAdvancedSettingsPresented = false
    
    init(
        item: VideoItem,
        userConfig: UserConfig,
        player: Player,
        hudModel: VideoPlayerHUDModel,
        controlsVisibilityModel: VideoPlayerControlsVisibilityModel,
        subtitleState: SubtitleState
    ) {
        self.item = item
        self.userConfig = userConfig
        self.playbackSession = .init(itemID: item.id)
        self.player = player
        self.hudModel = hudModel
        self.controlsVisibilityModel = controlsVisibilityModel
        self.systemMediaManager = SystemMediaManager()
        self.subtitleState = subtitleState
        subtitleState.postInit(
            nativeSubtitleRendering: userConfig.nativeSubtitleRendering,
            setSubtitleTrack: { [weak self] trackIndex in
                guard let self else { return }
                if let trackIndex,
                   trackIndex < self.player.subtitleTracks.count {
                    self.player.selectedSubtitleTrack = self.player.subtitleTracks[trackIndex]
                } else {
                    self.player.selectedSubtitleTrack = nil
                }
            },
            addPlayerSubtitleTrack: { [weak self] subtitleURL in
                try self?.player.addExternalTrack(
                    from: subtitleURL,
                    type: .subtitle,
                    select: false
                )
            },
            onSubtitlesChange: { [weak self] in
                self?.resetCueCache()
            }
        )
        systemMediaManager.postInit(
            onPause: { [weak self] in
                self?.pausePlayback()
            },
            onPlay: { [weak self] in
                self?.resumePlayback()
            },
            onToggle: { [weak self] in
                self?.togglePlayPause()
            },
            onPreviousTrack: { [weak self] in
                // known issue: this may be invoked before queue is fully loaded
                guard let self else { return }
                self.playPreviousVideo(before: self.item.url)
            },
            onNextTrack: { [weak self] in
                // known issue: this may be invoked before queue is fully loaded
                guard let self else { return }
                self.playNextVideo(after: self.item.url)
            },
            getPlaybackInfo: { [weak self] in
                guard let self else { return nil }
                return PlaybackInfo(
                    title: self.item.displayTitle,
                    albumTitle: self.item.url.deletingLastPathComponent().lastPathComponent,
                    url: self.item.url,
                    currentTime: self.player.currentTime.toSeconds(),
                    position: self.player.position,
                    isPlaying: self.player.isPlaying,
                    rate: self.player.rate,
                    queueCount: itemsFromSameDirectories.count,
                    queueIndex: itemsFromSameDirectories.firstIndex(of: self.item),
                    duration: self.player.duration?.toSeconds()
                )
            }
        )
    }
    // MARK: - Video Playere Core
    
    func startPlayback() {
        player.aspectRatio = contentMode.aspectRatio
        
        do {
            let media = try Media(url: item.url)
            media.addOption(":no-sub-autodetect-file")
            try player.play(media)
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
    
    func pausePlayback() {
        player.pause()
        playbackErrorMessage = nil
    }

    func resumePlayback() {
        player.resume()
        playbackErrorMessage = nil
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
        subtitleState.reset()
        setSubtitleDelay(.zero, showHUD: false)
    }
    
    var currentCueIndex: Int? {
        guard let selectedSubtitleIndex = subtitleState.selectedSubtitleTrackIndex,
              selectedSubtitleIndex < subtitleState.nativeSubtitles.count else {
            return nil
        }
        if let lastKnownCueRange,
           lastKnownCueRange.0 + subtitleDelay <= player.currentTime && lastKnownCueRange.1 + subtitleDelay > player.currentTime {
            return lastKnownCueIndex
        } else {
            let subtitles = subtitleState.nativeSubtitles[selectedSubtitleIndex]
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
        guard let selectedSubtitleIndex = subtitleState.selectedSubtitleTrackIndex,
              selectedSubtitleIndex < subtitleState.nativeSubtitles.count,
              let lastSubtitleIndex = subtitleState.nativeSubtitles[selectedSubtitleIndex].lastIndex(where: { $0.endTime + subtitleDelay < player.currentTime }) else {
            return nil
        }
        return (lastSubtitleIndex, subtitleState.nativeSubtitles[selectedSubtitleIndex][lastSubtitleIndex])
    }
    
    var nextCueInfo: (Int, SubtitleCue)? {
        guard let selectedSubtitleIndex = subtitleState.selectedSubtitleTrackIndex,
              selectedSubtitleIndex < subtitleState.nativeSubtitles.count,
              let nextSubtitleIndex = subtitleState.nativeSubtitles[selectedSubtitleIndex].firstIndex(where: { $0.startTime + subtitleDelay > player.currentTime }) else {
            return nil
        }
        return (nextSubtitleIndex, subtitleState.nativeSubtitles[selectedSubtitleIndex][nextSubtitleIndex])
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
    
    func importSubtitle(
        _ result: Result<URL, any Error>,
        securityScoped: Bool = true,
        expectedSession: PlaybackSession,
        persist: Bool = true
    ) async {
        do {
            let preparedSubtitle = try await subtitleState.prepareSubtitle(
                from: result,
                japaneseOnly: userConfig.japaneseOnly,
                securityScoped: securityScoped,
            )
            try Task.checkCancellation()
            guard playbackSession == expectedSession else { return }
            try subtitleState.importPreparedSubtitle(preparedSubtitle, persist: persist)
        } catch is CancellationError {
            return
        } catch {
            if case let .success(url) = result {
                Logger.video.error("Failed to import subtitle at \(url): \(error)")
            } else {
                Logger.video.error("Failed to import subtitle: \(error)")
            }
        }
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
        guard let selectedSubtitleTrackIndex = subtitleState.selectedSubtitleTrackIndex else { return }
        if subtitleState.hiddenSubtitleTrackIndex == nil {
            if !userConfig.nativeSubtitleRendering {
                // This bypasses the `didSet` of `viewModel.selectedSubtitleTrackIndex`
                player.selectedSubtitleTrack = nil
            }
            subtitleState.hiddenSubtitleTrackIndex = selectedSubtitleTrackIndex
            hudModel.showSubtitleHidden(true)
        } else {
            if !userConfig.nativeSubtitleRendering {
                player.selectedSubtitleTrack = player.subtitleTracks[subtitleState.hiddenSubtitleTrackIndex!]
            }
            subtitleState.hiddenSubtitleTrackIndex = nil
            hudModel.showSubtitleHidden(false)
        }
    }
    
    func handleRightSwipe() {
        guard subtitleState.selectedSubtitleTrackIndex != nil , !subtitleState.nativeSubtitles.isEmpty else { return }
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
    
    // MARK: - Playback Lifetime

    func runPlaybackSession(modelContext: ModelContext) async {
        let expectedSession = playbackSession
        let expectedItemURL = item.url
        let endEvents = player.events(
            policy: .unbounded,
            filter: { event in
                if case .endReached = event {
                    return true
                }
                return false
            }
        )
        
        // avoid non sendable `modelContext` to be sent to task isolation domain in `async let`
        let playbackOperation: @MainActor @Sendable () async -> Void = { [self] in
            await onPlaybackSessionChanged(modelContext: modelContext)
        }
        let queueOperation: @MainActor @Sendable () async -> Void = { [self] in
            await loadItemsFromSameDirectories(modelContext: modelContext)
        }

        async let playbackSetup: Void = playbackOperation()
        async let queueLoad: Void = queueOperation()

        for await _ in endEvents {
            await queueLoad
            guard userConfig.autoplayNextVideo,
                  !Task.isCancelled,
                  playbackSession == expectedSession,
                  item.url == expectedItemURL else {
                break
            }
            playNextVideo(after: expectedItemURL)
            break
        }

        await playbackSetup
        await queueLoad
    }
    
    func runAfterPlayStart(_ body: () async -> Void) async {
        for await event in player.events {
            if case let .stateChanged(playerState) = event,
               playerState == .playing {
                await body()
                break
            }
        }
    }
    
    /// invoked when playback session is changed
    ///
    /// There are multiple reasons to cause playback session change:
    /// 1. select different item in PWD queue
    /// 2. return from background
    func onPlaybackSessionChanged(
        modelContext: ModelContext
    ) async {
        let sessionSnapshot = playbackSession
        let itemSnapshot = item
        
        if !isSuspendedForBackground {
            if let persistenceTask = persistenceTasks[item.url] {
                await persistenceTask.value
            }
            // task is not immediately cancelled after `playbackSession` is changed because cancellation is managed by SwiftUI
            guard !Task.isCancelled, playbackSession == sessionSnapshot, item.id == itemSnapshot.id else { return }
            startPlayback()
        }
        
        await runAfterPlayStart {
            guard !Task.isCancelled, playbackSession == sessionSnapshot, item.id == itemSnapshot.id else { return }
            
            if isSuspendedForBackground {
                playbackSnapshotBeforeSuspended = nil
                isSuspendedForBackground = false
            }
            
            restorePlaybackDataFromHistory()
            subtitleState.reset()
            subtitleState.selectedSubtitleTrackIndex = !player.subtitleTracks.isEmpty ? 0 : nil
            
            do {
                let japaneseOnly = userConfig.japaneseOnly
                async let embeddedSubtitles = subtitleState.extractEmbeddedSubtitles(from: item.url, japaneseOnly: userConfig.japaneseOnly)
                async let persistedSubtitles = subtitleState.restorePersistedSubtitles(
                    from: item,
                    japaneseOnly: japaneseOnly
                )
                
                var subtitlesInPWD = [PreparedExternalSubtitle]()
                let (embeddedSubtitlesValue, persistedSubtitlesValue) = try await (embeddedSubtitles, persistedSubtitles)
                if subtitleState.shouldLoadSubtitlesInPWD(from: item, modelContext: modelContext) {
                    do {
                        subtitlesInPWD = try await subtitleState.prepareSubtitlesInPWD(
                            videoURL: item.url,
                            japaneseOnly: japaneseOnly,
                        )
                    } catch {
                        Logger.video.error("Failed to parse subtitles of \(self.item.url) in PWD: \(error)")
                    }
                }
                
                // task is not immediately cancelled after `playbackSession` is changed because cancellation is managed by SwiftUI
                try Task.checkCancellation()
                guard playbackSession == sessionSnapshot, item.id == itemSnapshot.id else { return }
                
                subtitleState.nativeSubtitles = embeddedSubtitlesValue
                try persistedSubtitlesValue.forEach { persistedSubtitle in
                    try self.subtitleState.importPreparedSubtitle(persistedSubtitle)
                }
                try subtitlesInPWD.forEach { subtitleInPWD in
                    try self.subtitleState.importPreparedSubtitle(subtitleInPWD)
                }
                if let selectedSubtitleIndex = item.subtitleStorage.selectedIndex
                    , selectedSubtitleIndex < subtitleState.nativeSubtitles.count {
                    subtitleState.selectedSubtitleTrackIndex = selectedSubtitleIndex
                }
                setSubtitleDelay(item.subtitleStorage.subtitleDelay, showHUD: false)
            } catch is CancellationError {
                return
            } catch {
                Logger.video.error("Failed to load subtitles: \(error)")
            }
        }
    }
    
    private func restorePlaybackDataFromHistory() {
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
    
    func runAfterPlaybackStop(_ body: () async -> Void) async {
        for await event in player.events {
            if case let .stateChanged(playerState) = event,
               playerState == .stopped {
                await body()
                break
            }
        }
    }
    
    func onPlayerViewDisappear(modelContext: ModelContext) {
        persistVideoItem(item, modelContext: modelContext)
        stopPlayback()
        systemMediaManager.deactivate()
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
                pausePlayback()
                systemMediaManager.deactivate()
                // When scene phase moves to background, states inside `player` can be lost. Record before stop playing
                playbackSnapshotBeforeSuspended = item.getSnapshot(
                    time: player.currentTime,
                    position: player.position,
                    bookmarks: bookmarks,
                    subtitleStorage: VideoSubtitleStorage(
                        subtitleData: subtitleState.externalSubtitleData,
                        selectedIndex: subtitleState.selectedSubtitleTrackIndex,
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
                systemMediaManager.activate()
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
            subtitleData: subtitleState.externalSubtitleData,
            selectedIndex: subtitleState.selectedSubtitleTrackIndex,
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
        let itemURL = item.url
        let dirURL = itemURL.deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dirURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        let standardizedItemURL = itemURL.standardizedFileURL
        var files = contents.filter { file in
            guard !file.isDirectory() else { return false }
            return file.standardizedFileURL == standardizedItemURL
                || VideoFileSupport.isVideoCandidate(file)
        }
        // Keep an already-opened video in its own queue even if its extension is unknown or it is hidden.
        if !files.contains(where: { $0.standardizedFileURL == standardizedItemURL }) {
            files.append(itemURL)
        }
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
    
    private func playPreviousVideo(before currentURL: URL) {
        // Video items created before their first history persistence have different IDs, so match by URL.
        let standardizedCurrentURL = currentURL.standardizedFileURL
        guard let currentIndex = itemsFromSameDirectories.firstIndex(where: {
            $0.url.standardizedFileURL == standardizedCurrentURL
        }) else {
            return
        }
        let previousIndex = currentIndex - 1
        guard previousIndex >= 0 else { return }
        item = itemsFromSameDirectories[previousIndex]
        hudModel.showPreviousVideo()
    }
    
    private func playNextVideo(after currentURL: URL) {
        // Video items created before their first history persistence have different IDs, so match by URL.
        let standardizedCurrentURL = currentURL.standardizedFileURL
        guard let currentIndex = itemsFromSameDirectories.firstIndex(where: {
            $0.url.standardizedFileURL == standardizedCurrentURL
        }) else {
            return
        }
        let nextIndex = currentIndex + 1
        guard nextIndex < itemsFromSameDirectories.count else { return }
        item = itemsFromSameDirectories[nextIndex]
        hudModel.showNextVideo()
    }
    
    // MARK: - System Media Manager
    
    func activateSystemMediaManager() {
        systemMediaManager.activate()
    }
    
    func refreshNowPlayingInfo(currentTime: Duration, force: Bool = false) {
        systemMediaManager.refreshNowPlayingInfo(currentTime: currentTime, force: force)
    }
}

// Metrics

private enum VideoPlayerBookmarkMetrics {
    static let duplicateToleranceSeconds = 1.0
    static let duplicatePositionTolerance = 0.002
}
