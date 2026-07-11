//
//  VideoPlayerHUDModel.swift
//  Hana
//
//  Created by Haruka on 2026/7/7.
//

import SwiftUI

@Observable
@MainActor
final class VideoPlayerHUDModel {
    
    private(set) var hudState: VideoPlayerHUDState?
    private var autoHideTask: Task<Void, Never>?
    private let autoHideDelay: Duration = .seconds(2)
    
    func showSeekBackward(seconds: Int?) {
        show(.seekBackward(seconds: seconds))
    }
    
    func showSeekForward(seconds: Int?) {
        show(.seekForward(seconds: seconds))
    }
    
    func showPlayPause(isPlaying: Bool) {
        show(isPlaying ? .play : .pause)
    }
    
    func showBrightness(value: Float) {
        show(.brightness(value))
    }
    
    func showVolume(value: Float) {
        show(.volume(value))
    }
    
    func showSubtitleDelay(_ delay: Int) {
        show(.subtitleDelay(milliseconds: delay))
    }
    
    func showSubtitleHidden(_ isHidden: Bool) {
        show(.subtitleHidden(isHidden))
    }
    
    func showBookmarkAdded(at time: Duration) {
        show(.bookmarkAdded(time))
    }
    
    func showBookmarkAlreadyExists(at time: Duration) {
        show(.bookmarkAlreadyExists(time))
    }
    
    private func show(_ state: VideoPlayerHUDState) {
        hudState = state
        autoHideTask?.cancel()
        
        autoHideTask = Task {
            try? await Task.sleep(for: autoHideDelay)
            guard !Task.isCancelled else { return }
            self.hudState = nil
            self.autoHideTask = nil
        }
    }
    
    private func clamped(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
