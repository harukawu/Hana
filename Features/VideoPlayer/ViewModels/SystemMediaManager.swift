//
//  SystemMediaManager.swift
//  Hana
//
//  Created by Haruka on 2026/7/19.
//

import MediaPlayer

struct PlaybackInfo {
    let title: String
    let albumTitle: String
    let url: URL
    let currentTime: Double
    let position: Double
    let isPlaying: Bool
    let rate: Float
    let queueCount: Int
    let queueIndex: Int?
    let duration: Double?
}

@MainActor
class SystemMediaManager {
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var onPause: (@MainActor () -> Void)? = nil
    private var onPlay: (@MainActor () -> Void)? = nil
    private var onToggle: (@MainActor () -> Void)? = nil
    private var onPreviousTrack: (@MainActor () -> Void)? = nil
    private var onNextTrack: (@MainActor () -> Void)? = nil
    private var getPlaybackInfo: (@MainActor () -> PlaybackInfo?)? = nil
    
    private var commands: [MPRemoteCommand] = []
    
    func postInit(
        onPause: (@MainActor () -> Void)? = nil,
        onPlay: (@MainActor () -> Void)? = nil,
        onToggle: (@MainActor () -> Void)? = nil,
        onPreviousTrack: (@MainActor () -> Void)? = nil,
        onNextTrack: (@MainActor () -> Void)? = nil,
        getPlaybackInfo: (@MainActor () -> PlaybackInfo?)? = nil
    ) {
        self.onPause = onPause
        self.onPlay = onPlay
        self.onToggle = onToggle
        self.onPreviousTrack = onPreviousTrack
        self.onNextTrack = onNextTrack
        self.getPlaybackInfo = getPlaybackInfo
    }
    
    func activate() {
        guard commands.isEmpty else { return }
        register(commandCenter.pauseCommand, action: onPause)
        register(commandCenter.playCommand, action: onPlay)
        register(commandCenter.togglePlayPauseCommand, action: onToggle)
        register(commandCenter.previousTrackCommand, action: onPreviousTrack)
        register(commandCenter.nextTrackCommand, action: onNextTrack)
    }
    
    func deactivate() {
        commands.forEach { command in
            command.removeTarget(nil)
            command.isEnabled = false
        }
        commands.removeAll()
        clearNowPlayingInfo()
    }
    
    private func register(_ command: MPRemoteCommand, action: (@MainActor () -> Void)?) {
        command.addTarget { _ in
            Task { @MainActor in
                action?()
            }
            return .success
        }
        command.isEnabled = true
        commands.append(command)
    }
    
    // MARK: - now playing info
    private var lastRefreshTime: Duration? = nil
    
    func refreshNowPlayingInfo(currentTime: Duration, force: Bool) {
        if !force,
           let lastRefreshTime,
           abs((currentTime - lastRefreshTime).toSeconds()) < 1 {
            return
        }
        guard let playbackInfo = getPlaybackInfo?() else { return }
        
        lastRefreshTime = currentTime
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: playbackInfo.title,
            MPMediaItemPropertyMediaType: MPMediaType.anyVideo.rawValue,
            MPMediaItemPropertyAlbumTitle: playbackInfo.albumTitle,
            
            MPNowPlayingInfoPropertyAssetURL: playbackInfo.url,
//            MPNowPlayingInfoPropertyChapterCount: xxx, // may be parsed by `Media().parse`
//            MPNowPlayingInfoPropertyChapterNumber: xxx,
//            MPNowPlayingInfoPropertyCurrentPlaybackDate = Date.now,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: playbackInfo.currentTime,
            MPNowPlayingInfoPropertyExcludeFromSuggestions: false,
//            MPNowPlayingInfoPropertyIsLiveStream: xxx,
            MPNowPlayingInfoPropertyPlaybackProgress: playbackInfo.position,
            MPNowPlayingInfoPropertyPlaybackRate: playbackInfo.isPlaying ? playbackInfo.rate : 0,
            MPNowPlayingInfoPropertyPlaybackQueueCount: playbackInfo.queueCount,
        ]
        if let itemIndex = playbackInfo.queueIndex {
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = itemIndex
        }
        if let duration = playbackInfo.duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
