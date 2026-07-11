//
//  VideoPlayerControlsVisibilityModel.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class VideoPlayerControlsVisibilityModel {
    private let autoHideDelay: Duration
    var isVisible = true
    private var autoHideTask: Task<Void, Never>?
    private var isAutoHideSuspended = false
    
    init(autoHideDelay: Duration = .seconds(4)) {
        self.autoHideDelay = autoHideDelay
    }
    
    func show(allowingAutoHide: Bool) {
        withAnimation(.easeOut(duration: 0.18)) {
            isVisible = true
        }
        
        if allowingAutoHide {
            scheduleAutoHide()
        }
    }
    
    func hide() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
    }
    
    func scheduleAutoHide() {
        guard isVisible, !isAutoHideSuspended else { return }
        autoHideTask?.cancel()
        autoHideTask = Task {
            try? await Task.sleep(for: autoHideDelay)
            guard !Task.isCancelled, !self.isAutoHideSuspended else { return }
            self.hide()
        }
    }
    
    func suspendAutoHide() {
        isAutoHideSuspended = true
        cancelAutoHide()
    }
    
    func resumeAutoHide(allowingAutoHide: Bool) {
        isAutoHideSuspended = false
        show(allowingAutoHide: allowingAutoHide)
    }
    
    func cancelAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }
}
