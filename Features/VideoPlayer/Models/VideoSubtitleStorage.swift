//
//  VideoSubtitleStorage.swift
//  Hana
//
//  Created by Haruka on 2026/7/8.
//

import Foundation

/// This struct is only used when transferring video item into video player.
/// After that, view model of video player will use its internal states to track these variable.
/// When exiting from video player, a new struct will be created and persisted to SwiftData
struct VideoSubtitleStorage: Codable, Equatable, Hashable {
    let subtitleData: [Data]
    let selectedIndex: Int?
    private let _subtitleDelay: Double
    
    var subtitleDelay: Duration {
        .seconds(_subtitleDelay)
    }
    
    init(subtitleData: [Data] = [], selectedIndex: Int? = nil, subtitleDelay: Duration = .zero) {
        self.subtitleData = subtitleData
        self.selectedIndex = selectedIndex
        self._subtitleDelay = subtitleDelay.toSeconds()
    }
}
