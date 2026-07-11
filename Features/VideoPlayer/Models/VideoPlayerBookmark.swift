//
//  VideoPlayerBookmark.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation

struct VideoPlayerBookmark: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: UUID
    let time: Duration
    let position: Double
    
    init(id: UUID = UUID(), time: Duration, position: Double) {
        self.id = id
        self.time = time
        self.position = min(max(position, 0), 1)
    }
}

struct VideoPlayerBookmarks: Codable, ExpressibleByArrayLiteral {
    var bookmarks: [VideoPlayerBookmark]
    
    init(arrayLiteral elements: VideoPlayerBookmark...) {
        bookmarks = elements
    }
    
    init(bookmarks: [VideoPlayerBookmark]) {
        self.bookmarks = bookmarks
    }
}
