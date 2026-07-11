//
//  SubtitlesFullScreenView.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI
import HoshiReader

struct SubtitlesFullScreenView: View {
    private let videoTitle: String
    private let videoURL: URL
    private let subtitles: [SubtitleCue]
    private let subtitleDelay: Duration
    private let highlightedIndex: Int?
    private let selectedAudioTrackIndex: Int?
    private let onMiningStart: (@MainActor () -> Void)?
    
    @State private var selectedCueIndices: Set<Int>
    @State private var lookupRequest: SubtitleLookupRequest?
    @State private var showNoSelectionAlert = false
    @Environment(\.dismiss) private var dismiss
    
    init(
        videoTitle: String,
        videoURL: URL,
        subtitles: [SubtitleCue],
        subtitleDelay: Duration,
        initialRequest: SubtitleLookupRequest?,
        highlightedIndex: Int?,
        selectedAudioTrackIndex: Int?,
        onMiningStart: (@MainActor () -> Void)?
    ) {
        self.videoTitle = videoTitle
        self.videoURL = videoURL
        self.subtitles = subtitles
        self.subtitleDelay = subtitleDelay
        self.highlightedIndex = highlightedIndex
        self.selectedAudioTrackIndex = selectedAudioTrackIndex
        self.onMiningStart = onMiningStart
        _lookupRequest = State(initialValue: initialRequest)
        _selectedCueIndices = highlightedIndex == nil ? State(initialValue: []) : State(initialValue: [highlightedIndex!])
    }
    
    var body: some View {
        GeometryReader { geometry in
            let subtitleColumnWidth = min(
                max(geometry.size.width * 0.38, 280),
                geometry.size.width * 0.5
            )
            
            HStack(spacing: 0) {
                dictionaryPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                
                Divider()
                
                SubtitlesTableView(
                    selectedCueIndices: $selectedCueIndices,
                    subtitles: subtitles,
                    highlightedIndex: highlightedIndex
                ) { hit, text in
                    handleCharacterTap(
                        hit,
                        text: text,
                        containerFrame: geometry.frame(in: .global)
                    )
                }
                .frame(width: subtitleColumnWidth)
                .frame(maxHeight: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .padding(12)
            }
        }
        .alert("Error", isPresented: $showNoSelectionAlert) {
            Button("OK") {}
        } message: {
            Text("There should be at least one selected sentence")
        }
        
    }
    
    @ViewBuilder
    private var dictionaryPane: some View {
        if let lookupRequest {
            DictionarySearchPanel(query: lookupRequest.query, mediaProvider: self.getVideoResources)
                .id(lookupRequest.id)
        } else {
            ContentUnavailableView(
                "Select a subtitle",
                systemImage: "character.magnify",
                description: Text("Tap a character in the subtitle list to search the dictionary.")
            )
        }
    }
    
    private func handleCharacterTap(
        _ hit: TappableLabelCharacterHit,
        text: String,
        containerFrame: CGRect
    ) {
        let nsText = text as NSString
        
        guard hit.utf16Index >= 0, hit.utf16Index < nsText.length else {
            return
        }
        
        let characterRange = nsText.rangeOfComposedCharacterSequence(at: hit.utf16Index)
        let tappedCharacter = nsText.substring(with: characterRange)
        
        guard !tappedCharacter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let selectionRect = hit.characterRect.offsetBy(
            dx: -containerFrame.minX,
            dy: -containerFrame.minY
        )
        
        lookupRequest = SubtitleLookupRequest(
            sentence: text,
            query: nsText.substring(from: characterRange.location),
            selectionRect: selectionRect,
            utf16Index: characterRange.location
        )
    }
    
    @concurrent
    func getVideoResources() async throws -> (imageURL: URL, audioURL: URL, videoTitle: String, sentence: String?)? {
        let (selectedCueIndices, cues, subtitleDelay) = await MainActor.run {
            (self.selectedCueIndices, self.subtitles, self.subtitleDelay)
        }
        guard !selectedCueIndices.isEmpty else {
            await MainActor.run {
                self.showNoSelectionAlert.toggle()
            }
            return nil
        }
        let sortedIndices = Array(selectedCueIndices).sorted()
        let startTime = cues[sortedIndices.first!].startTime
        let endTime = cues[sortedIndices.last!].endTime
        let sentences = Array(sortedIndices.first!...sortedIndices.last!).map({ cues[$0].text })
        var (imageOptions, audioOptions, videoTitle) = await MainActor.run {
            (
                PersistedUserConfig.shared.imageOptions,
                PersistedUserConfig.shared.audioOptions,
                self.videoTitle
            )
        }
        audioOptions.audioTrackIndex = selectedAudioTrackIndex ?? 0
        let tempDir = FileStorage.getTempDirectory()
        let audioURL = tempDir.appending(path: UUID().uuidString).appendingPathExtension("mp3")
        let imageURL = tempDir.appending(path: UUID().uuidString).appendingPathExtension(imageOptions.format.rawValue)
        let extractor = MediaExtractor()
        try extractor.extractAudio(
            from: videoURL,
            range: startTime + subtitleDelay..<endTime + subtitleDelay,
            to: audioURL,
            options: audioOptions
        )
        try extractor.extractImage(
            from: videoURL,
            at: startTime + subtitleDelay,
            to: imageURL,
            options: imageOptions
        )
        await onMiningStart?()
        return (imageURL: imageURL, audioURL: audioURL, videoTitle: videoTitle, sentence: sentences.joined(separator: " "))
    }
}
