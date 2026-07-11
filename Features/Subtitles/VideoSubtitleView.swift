//
//  VideoSubtitleView.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI
import HoshiReader

struct VideoSubtitleView: View {
    let cueIndex: Int
    let subtitles: [SubtitleCue]
    let subtitleDelay: Duration
    let videoURL: URL
    let videoTitle: String
    let selectedAudioTrackIndex: Int?
    let onLookupVisibilityChanged: ((Bool) -> Void)?
    private let onMiningStart: (@MainActor () -> Void)?
    
    @State private var lookupRequest: SubtitleLookupRequest?
    @State private var highlightRange: NSRange?
    @State private var isLookupVisible = false
    
    @State private var showFullscreenCover = false
    
    init(
        cueIndex: Int,
        subtitles: [SubtitleCue],
        subtitleDelay: Duration,
        videoURL: URL,
        videoTitle: String,
        selectedAudioTrackIndex: Int?,
        onLookupVisibilityChanged: ((Bool) -> Void)?,
        onMiningStart: (@MainActor () -> Void)?
    ) {
        self.cueIndex = cueIndex
        self.subtitles = subtitles
        self.subtitleDelay = subtitleDelay
        self.videoURL = videoURL
        self.videoTitle = videoTitle
        self.selectedAudioTrackIndex = selectedAudioTrackIndex
        self.onLookupVisibilityChanged = onLookupVisibilityChanged
        self.onMiningStart = onMiningStart
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                textView(containerFrame: geometry.frame(in: .global))
                    .zIndex(100)
                
                if let lookupRequest {
                    HoshiReader::DictionaryLookupOverlay(
                        query: lookupRequest.query,
                        sentence: lookupRequest.sentence,
                        selectionRect: lookupRequest.selectionRect,
                        mediaProvider: self.getVideoResources,
                        onMatchedUTF16Length: { length in
                            handleMatch(length: length, requestID: lookupRequest.id)
                        },
                        onDismiss: {
                            dismissLookup(requestID: lookupRequest.id)
                        }
                    )
                    .id(lookupRequest.id)
                }
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .bottom
            )
        }
    }
    
    private func textView(containerFrame: CGRect) -> some View {
        VideoSubtitleText(
            text: subtitles[cueIndex].text,
            highlightRange: displayedHighlightRange,
            onCharacterTap: { hit, text in
                handleCharacterTap(
                    hit,
                    text: text,
                    containerFrame: containerFrame
                )
            },
            recognizerName: VideoPlayerGestureName.lookupTap
        )
        .shadow(color: .black, radius: 1, y: 1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            let shape = RoundedRectangle(
                cornerRadius: 3,
                style: .continuous
            )
            
            ZStack {
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(0.30)
                
                shape
                    .fill(.black.opacity(0.5))
            }
        }
        .safeAreaPadding(.bottom)
    }
}

// MARK: - Lookup
extension VideoSubtitleView {
    private var displayedHighlightRange: NSRange? {
        guard lookupRequest?.sentence == subtitles[cueIndex].text else {
            return nil
        }
        return highlightRange
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
        
        highlightRange = nil
        lookupRequest = SubtitleLookupRequest(
            sentence: text,
            query: nsText.substring(from: characterRange.location),
            selectionRect: selectionRect,
            utf16Index: characterRange.location
        )
    }
    
    private func handleMatch(length: Int, requestID: UUID) {
        guard let lookupRequest,
              lookupRequest.id == requestID,
              length > 0 else {
            return
        }
        
        let sentenceLength = (lookupRequest.sentence as NSString).length
        let availableLength = sentenceLength - lookupRequest.utf16Index
        let clampedLength = min(length, availableLength)
        
        guard clampedLength > 0 else {
            dismissLookup(requestID: requestID)
            return
        }
        
        highlightRange = NSRange(
            location: lookupRequest.utf16Index,
            length: clampedLength
        )
        setLookupVisible(true)
    }
    
    private func dismissLookup(requestID: UUID) {
        guard lookupRequest?.id == requestID else { return }
        
        lookupRequest = nil
        highlightRange = nil
        setLookupVisible(false)
    }
    
    private func setLookupVisible(_ isVisible: Bool) {
        guard isLookupVisible != isVisible else { return }
        
        isLookupVisible = isVisible
        onLookupVisibilityChanged?(isVisible)
    }
}

// MARK: - Anki support
extension VideoSubtitleView {
    @concurrent
    func getVideoResources() async throws -> (imageURL: URL, audioURL: URL, videoTitle: String, sentence: String?)? {
        var (imageOptions, audioOptions, currentCue, subtitleDelay, videoTitle) = await MainActor.run {
            (
                PersistedUserConfig.shared.imageOptions,
                PersistedUserConfig.shared.audioOptions,
                self.subtitles[cueIndex],
                self.subtitleDelay,
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
            range: currentCue.startTime + subtitleDelay..<currentCue.endTime + subtitleDelay,
            to: audioURL,
            options: audioOptions
        )
        try extractor.extractImage(
            from: videoURL,
            at: currentCue.startTime + subtitleDelay,
            to: imageURL,
            options: imageOptions
        )
        await onMiningStart?()
        return (imageURL: imageURL, audioURL: audioURL, videoTitle: videoTitle, sentence: nil)
    }
}

// MARK: - UILable Representable
struct VideoSubtitleText: UIViewRepresentable {
    let text: String
    let highlightRange: NSRange?
    let onCharacterTap: ((TappableLabelCharacterHit, String) -> Void)?
    let recognizerName: String?
    
    func makeUIView(context: Context) -> UITappableLabel {
        let label = UITappableLabel(onCharacterTap: onCharacterTap, recognizerName: recognizerName)
        label.textColor = .white
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.lineBreakMode = .byCharWrapping
        return label
    }
    
    func updateUIView(_ uiView: UITappableLabel, context: Context) {
        uiView.onCharacterTap = onCharacterTap
        uiView.resetText(text: text, highlightRange: highlightRange)
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITappableLabel, context: Context) -> CGSize? {
        let unconstrained = uiView.sizeThatFits(
            CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        
        let maximumWidth = proposal.width ?? unconstrained.width
        let finalWidth = min(maximumWidth, ceil(unconstrained.width))
        
        let fitted = uiView.sizeThatFits(
            CGSize(
                width: finalWidth,
                height: .greatestFiniteMagnitude
            )
        )
        
        return CGSize(
            width: finalWidth,
            height: ceil(fitted.height)
        )
    }
}

struct SubtitleLookupRequest: Identifiable {
    let id = UUID()
    let sentence: String
    let query: String
    let selectionRect: CGRect
    let utf16Index: Int
}
