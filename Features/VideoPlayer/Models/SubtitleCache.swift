//
//  SubtitleCache.swift
//  Hana
//
//  Created by Haruka on 2026/7/24.
//

import Foundation
import SwiftData

@Model
class SubtitleCache {
    @Attribute(.unique) var videoURL: URL
    @Attribute(.externalStorage) var subtitleData: Data
    var modificationDate: Date

    init(videoURL: URL, subtitleData: Data, modificationDate: Date = .now) {
        self.videoURL = videoURL
        self.subtitleData = subtitleData
        self.modificationDate = modificationDate
    }
}
