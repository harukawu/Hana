//
//  SubtitleState.swift
//  Hana
//
//  Created by Haruka on 2026/7/17.
//

import Observation
import Foundation
import NaturalLanguage
import SwiftData
import OSLog

enum SubtitleError: LocalizedError {
    case notAccessible(URL)
    
    var errorDescription: String? {
        switch self {
        case .notAccessible(let url):
            "Failed to access external subtitle file at \(url)"
        }
    }
}

struct PreparedExternalSubtitle {
    let url: URL
    let cues: [SubtitleCue]
    let data: Data
}


/// Subtitle Delay is not included in this class
@Observable
@MainActor
class SubtitleState {
    var nativeSubtitleRendering: Bool! = nil
    var setSubtitleTrack: ((Int?) -> Void)! = nil
    var addPlayerSubtitleTrack: ((URL) throws -> Void)! = nil
    var onSubtitlesChange: (() -> Void)! = nil
    
    var selectedSubtitleTrackIndex: Int? = nil {
        didSet {
            onSubtitlesChange()
            if !nativeSubtitleRendering {
                setSubtitleTrack(selectedSubtitleTrackIndex)
            } else {
                setSubtitleTrack(nil)
            }
            hiddenSubtitleTrackIndex = nil
        }
    }
    var hiddenSubtitleTrackIndex: Int? = nil
    var nativeSubtitles: [[SubtitleCue]] = []
    var externalSubtitleData: [Data] = []
    
    func postInit(
        nativeSubtitleRendering: Bool,
        setSubtitleTrack: @escaping (Int?) -> Void,
        addPlayerSubtitleTrack: @escaping ((URL) throws -> Void),
        onSubtitlesChange: @escaping (() -> Void)
    ) {
        self.nativeSubtitleRendering = nativeSubtitleRendering
        self.setSubtitleTrack = setSubtitleTrack
        self.addPlayerSubtitleTrack = addPlayerSubtitleTrack
        self.onSubtitlesChange = onSubtitlesChange
    }
    
    func reset() {
        selectedSubtitleTrackIndex = nil
        nativeSubtitles = []
        externalSubtitleData = []
        hiddenSubtitleTrackIndex = nil
    }
    
    func shouldLoadSubtitlesInPWD(
        from item: VideoItem,
        modelContext: ModelContext
    ) -> Bool {
        let itemID = item.id
        let histories: [VideoHistory]
        do {
            let predicate = #Predicate<VideoHistory> { history in
                history.id == itemID
            }
            let descriptor = FetchDescriptor(predicate: predicate)
            histories = try modelContext.fetch(descriptor)
        } catch {
            Logger.video.error("Failed to load video history of id \(itemID): \(error)")
            return false
        }
        return histories.isEmpty
    }
    
    /// Before loading, check SwiftData if this is the first time the video is loaded
    @concurrent
    func prepareSubtitlesInPWD(
        videoURL: URL,
        japaneseOnly: Bool,
    ) async throws -> [PreparedExternalSubtitle] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: videoURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        let validContents = contents
            .filter({ !$0.isDirectory() })
            .filter { url in
                SubtitleURLMatcher.isSupportedSubtitle(url: url)
                && SubtitleURLMatcher.isMatched(videoURL: videoURL, subtitleURL: url)
            }
        return try await withThrowingTaskGroup { group in
            for content in validContents {
                group.addTask {
                    try await self.prepareSubtitle(
                        from: .success(content),
                        japaneseOnly: japaneseOnly,
                        securityScoped: false
                    )
                }
            }
            var preparedSubtitles = [PreparedExternalSubtitle]()
            for try await preparedSubtitle in group {
                preparedSubtitles.append(preparedSubtitle)
            }
            return preparedSubtitles
                .sorted { subtitle1, subtitle2 in
                    subtitle1.url.lastPathComponent.localizedStandardCompare(subtitle2.url.lastPathComponent) == .orderedAscending
                }
        }
    }
    
    @concurrent
    func restorePersistedSubtitles(
        from item: VideoItem,
        japaneseOnly: Bool
    ) async throws -> [PreparedExternalSubtitle] {
        var preparedSubtitles = [PreparedExternalSubtitle]()
        for singleSubtitleData in item.subtitleStorage.subtitleData {
            let tmpURL = FileStorage.getTempDirectory().appending(path: UUID().uuidString)
            try singleSubtitleData.write(to: tmpURL)
            let preparedSubtitle = try await prepareSubtitle(from: .success(tmpURL), japaneseOnly: japaneseOnly, securityScoped: false)
            preparedSubtitles.append(preparedSubtitle)
        }
        return preparedSubtitles
    }
    
    func importPreparedSubtitle(
        _ preparedSubtitle: PreparedExternalSubtitle,
        persist: Bool = true,
    ) throws {
        // this is asynchronous under the hood. There may be problem when changing `selectedSubtitleTrackIndex`
        try addPlayerSubtitleTrack(
            preparedSubtitle.url
        )
        
        self.nativeSubtitles.append(
            preparedSubtitle.cues
        )
        if persist {
            self.externalSubtitleData.append(
                preparedSubtitle.data
            )
        }
        self.selectedSubtitleTrackIndex = self.nativeSubtitles.lastIndex(where: { _ in true })
    }
    
    /// copy subtitle url to temp directory
    @concurrent
    func prepareSubtitle(
        from result: Result<URL, any Error>,
        japaneseOnly: Bool,
        securityScoped: Bool = true,
    ) async throws -> PreparedExternalSubtitle {
        switch result {
        case .success(let url):
            if securityScoped {
                guard url.startAccessingSecurityScopedResource() else {
                    throw SubtitleError.notAccessible(url)
                }
            }
            defer { url.stopAccessingSecurityScopedResource() }
            // libVLC import file asynchronously. Therefore we should copy to a place where we have access
            let tempDir = FileStorage.getTempDirectory()
            let fileName = UUID().uuidString.appending(".\(url.pathExtension)")
            let targetURL = tempDir.appending(path: fileName)
            try FileManager.default.copyItem(at: url, to: targetURL)
            let data = try Data(contentsOf: targetURL)
            
            let parser = SubtitleParser()
            var subtitleCues: [SubtitleCue]
            subtitleCues = try parser.parse(url)
            if japaneseOnly {
                subtitleCues = subtitleCues.filter({ Self.isJapanese(text: $0.text) })
            }
            return PreparedExternalSubtitle(
                url: targetURL,
                cues: subtitleCues,
                data: data
            )
        case .failure(let error):
            throw error
        }
    }
    
    @concurrent
    func extractEmbeddedSubtitles(from videoURL: URL, japaneseOnly: Bool) async throws -> [[SubtitleCue]] {
        let parser = SubtitleParser()
        var extractedSubtitles = try parser.extractEmbeddedSubtitles(from: videoURL)
        if japaneseOnly {
            extractedSubtitles = extractedSubtitles.map({ subtitles in
                subtitles.filter({ Self.isJapanese(text: $0.text) })
            })
        }
        return extractedSubtitles
    }
    
    private static nonisolated func isJapanese(text: String?) -> Bool {
        guard let text else {
            return false
        }
        let dominantLanguage = NLLanguageRecognizer.dominantLanguage(for: text)
        return dominantLanguage == .japanese
    }
}
