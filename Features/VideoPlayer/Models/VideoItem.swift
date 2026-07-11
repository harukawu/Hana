//
//  VideoItem.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation
import SwiftData
import OSLog

struct VideoItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let time: Duration
    let position: Double
    let bookmarks: [VideoPlayerBookmark]
    let subtitleStorage: VideoSubtitleStorage
    let selectedAudioTrackIndex: Int?
    let playbackRate: Float
    let displayTitle: String
    
    init(
        id: UUID = UUID(),
        time: Duration = .zero,
        position: Double = 0,
        bookmarks: [VideoPlayerBookmark] = [],
        subtitleStorage: VideoSubtitleStorage = .init(),
        selectedAudioTrackIndex: Int? = nil,
        playbackRate: Float = 1.0,
        url: URL,
        displayTitle: String? = nil
    ) {
        self.id = id
        self.time = time
        self.position = position
        self.bookmarks = bookmarks
        self.subtitleStorage = subtitleStorage
        self.selectedAudioTrackIndex = selectedAudioTrackIndex
        self.playbackRate = playbackRate
        self.url = url
        self.displayTitle = Self.normalizedTitle(displayTitle, fallbackURL: url)
    }
    
    func updateToHistory(
        time: Duration,
        position: Double,
        bookmarks: [VideoPlayerBookmark],
        thumbnailData: Data,
        subtitleStorage: VideoSubtitleStorage,
        selectedAudioTrackIndex: Int?,
        playbackRate: Float,
        modificationDate: Date = .now
    ) throws -> VideoHistory {
        VideoHistory(
            id: id,
            url: url,
            urlBookmark: try url.bookmarkData(),
            bookmarks: bookmarks,
            subtitleStorage: subtitleStorage,
            selectedAudioTrackIndex: selectedAudioTrackIndex,
            playbackRate: playbackRate,
            displayTitle: displayTitle,
            time: time,
            position: position,
            thumbnailData: thumbnailData,
            modificationDate: modificationDate
        )
    }
    
    /// The return value of this function can be treated as a snapshot of runtime data (in view model)
    /// it does not persist to SwiftData and no thumbnail is generated
    func getSnapshot(
        time: Duration,
        position: Double,
        bookmarks: [VideoPlayerBookmark],
        subtitleStorage: VideoSubtitleStorage,
        selectedAudioTrackIndex: Int?,
        playbackRate: Float,
    ) -> VideoItem {
        VideoItem(
            id: self.id,
            time: time,
            position: position,
            bookmarks: bookmarks,
            subtitleStorage: subtitleStorage,
            selectedAudioTrackIndex: selectedAudioTrackIndex,
            playbackRate: playbackRate,
            url: self.url,
            displayTitle: self.displayTitle
        )
    }
    
    @MainActor
    static func getVideoItem(from url: URL, modelContext: ModelContext) -> VideoItem {
        let predicate = #Predicate<VideoHistory> { history in
            history.url == url
        }
        let generateNewItem = {
            VideoItem(url: url)
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let histories = try? modelContext.fetch(descriptor) {
            if let history = histories.first {
                return history.toItem()
            } else {
                return generateNewItem()
            }
        } else {
            Logger.video.error("Failed to fetch history for url \(url)")
            return generateNewItem()
        }
    }
    
    private static func normalizedTitle(_ title: String?, fallbackURL: URL) -> String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        
        let fileTitle = fallbackURL.deletingPathExtension().lastPathComponent
        if !fileTitle.isEmpty {
            return fileTitle
        }
        
        return fallbackURL.absoluteString
    }
}

@Model
class VideoHistory {
    @Attribute(.unique) var id: UUID = UUID()
    var url: URL
    var urlBookmark: Data
    var displayTitle: String
    var _time: Double
    var position: Double
    var videoBookmarks: VideoPlayerBookmarks
    @Attribute(.externalStorage) var subtitleStorage: VideoSubtitleStorage
    var selectedAudioTrackIndex: Int?
    var playbackRate: Float
    
    @Attribute(.externalStorage) var thumbnailData: Data
    var modificationDate: Date
    
    init(
        id: UUID = UUID(),
        url: URL,
        urlBookmark: Data,
        bookmarks: [VideoPlayerBookmark],
        subtitleStorage: VideoSubtitleStorage,
        selectedAudioTrackIndex: Int?,
        playbackRate: Float,
        displayTitle: String,
        time: Duration,
        position: Double,
        thumbnailData: Data,
        modificationDate: Date
    ) {
        self.id = id
        self.url = url
        self.urlBookmark = urlBookmark
        self.videoBookmarks = .init(bookmarks: bookmarks)
        self.subtitleStorage = subtitleStorage
        self.selectedAudioTrackIndex = selectedAudioTrackIndex
        self.playbackRate = playbackRate
        self.displayTitle = displayTitle
        self._time = time.toSeconds()
        self.position = position
        self.thumbnailData = thumbnailData
        self.modificationDate = modificationDate
    }
    
    func update(
        time: Duration,
        position: Double,
        modificationDate: Date = .now,
        bookmarks: [VideoPlayerBookmark],
        subtitleStorage: VideoSubtitleStorage,
        selectedAudioTrackIndex: Int?,
        playbackRate: Float,
        thumbnailData: Data
    ) {
        self.time = time
        self.position = position
        self.videoBookmarks = .init(bookmarks: bookmarks)
        self.subtitleStorage = subtitleStorage
        self.selectedAudioTrackIndex = selectedAudioTrackIndex
        self.playbackRate = playbackRate
        self.thumbnailData = thumbnailData
        self.modificationDate = modificationDate
    }
    
    func toItem() -> VideoItem {
        VideoItem(
            id: id,
            time: time,
            position: position,
            bookmarks: videoBookmarks.bookmarks,
            subtitleStorage: subtitleStorage,
            selectedAudioTrackIndex: selectedAudioTrackIndex,
            playbackRate: playbackRate,
            url: url,
            displayTitle: displayTitle
        )
    }
    
    var time: Duration {
        get {
            .seconds(_time)
        }
        set {
            _time = newValue.toSeconds()
        }
    }
}
