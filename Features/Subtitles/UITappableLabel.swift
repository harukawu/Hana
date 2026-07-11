//
//  UITappableLabel.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import UIKit

struct TappableLabelCharacterHit {
    let utf16Index: Int
    let characterRect: CGRect
}

class UITappableLabel: UILabel {
    var onCharacterTap: ((TappableLabelCharacterHit, String) -> Void)?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(onCharacterTap: ((TappableLabelCharacterHit, String) -> Void)? = nil, recognizerName: String? = nil) {
        self.onCharacterTap = onCharacterTap
        super.init(frame: .zero)
        setupRecognizer(recognizerName: recognizerName)
    }
    
    private func setupRecognizer(recognizerName: String? = nil) {
        isUserInteractionEnabled = true
        let recognizer = UITapGestureRecognizer()
        recognizer.name = recognizerName
        recognizer.numberOfTapsRequired = 1
        recognizer.numberOfTouchesRequired = 1
        recognizer.addTarget(self, action: #selector(self.handleTap(_:)))
        addGestureRecognizer(recognizer)
    }
    
    @objc
    private func handleTap(_ sender: UITapGestureRecognizer) {
        let locationInLabel = sender.location(in: self)
        guard let text,
              let hit = getCharacterHit(locationInLabel: locationInLabel, text: text) else {
            return
        }
        
        onCharacterTap?(hit, text)
    }
    
    private func getCharacterHit(
        locationInLabel: CGPoint,
        text: String
    ) -> TappableLabelCharacterHit? {
        let textRect = textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        
        guard textRect.contains(locationInLabel) else { return nil }
        let locationInTextContainer = CGPoint(
            x: locationInLabel.x - textRect.minX,
            y: locationInLabel.y - textRect.minY
        )
        
        let textContainer = NSTextContainer(size: textRect.size)
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.lineBreakMode = lineBreakMode
        textContainer.lineFragmentPadding = 0
        
        let textContentStorage = NSTextContentStorage()
        textContentStorage.attributedString = attributedText
        
        let textLayoutManager = NSTextLayoutManager()
        textLayoutManager.textContainer = textContainer
        textContentStorage.addTextLayoutManager(textLayoutManager)
        
        textLayoutManager.ensureLayout(for: textContentStorage.documentRange)
        
        guard let textLayoutFragment = textLayoutManager.textLayoutFragment(for: locationInTextContainer) else {
            return nil
        }
        
        let layoutFragmentFrame = textLayoutFragment.layoutFragmentFrame
        let locationInLayoutFragmentFrame = CGPoint(
            x: locationInTextContainer.x - layoutFragmentFrame.minX,
            y: locationInTextContainer.y - layoutFragmentFrame.minY
        )
        
        guard let textLineFragment = textLayoutFragment.textLineFragment(
            forVerticalOffset: locationInLayoutFragmentFrame.y,
            requiresExactMatch: true
        ),
              textLineFragment.typographicBounds.contains(locationInLayoutFragmentFrame) else {
            return nil
        }
        
        let locationInLineFragment = CGPoint(
            x: locationInLayoutFragmentFrame.x - textLineFragment.typographicBounds.minX,
            y: locationInLayoutFragmentFrame.y - textLineFragment.typographicBounds.minY
        )
        
        // this index is local index. It is relative to the current layout fragment start
        let rawCharacterIndex = textLineFragment.characterIndex(for: locationInLineFragment)
        let nsTextOfCurrentLayoutFragment = (textLineFragment.attributedString.string) as NSString
        
        guard rawCharacterIndex >= 0, rawCharacterIndex < nsTextOfCurrentLayoutFragment.length else {
            return nil
        }
        
        let composedCharacterRange = nsTextOfCurrentLayoutFragment.rangeOfComposedCharacterSequence(at: rawCharacterIndex)
        let characterStart = textLineFragment.locationForCharacter(at: composedCharacterRange.location)
        let characterEnd = textLineFragment.locationForCharacter(at: NSMaxRange(composedCharacterRange))
        let typographicBounds = textLineFragment.typographicBounds
        
        let characterRectInLabel = CGRect(
            x: textRect.minX
                + layoutFragmentFrame.minX
                + typographicBounds.minX
                + min(characterStart.x, characterEnd.x),
            y: textRect.minY
                + layoutFragmentFrame.minY
                + typographicBounds.minY,
            width: max(abs(characterEnd.x - characterStart.x), 1),
            height: typographicBounds.height
        )
        
        // When there are multiple lines, we need to make sure the overlay is above and below the entire UILabel
        let popupAnchorRectInLabel = CGRect(
            x: characterRectInLabel.minX,
            y: textRect.minY,
            width: characterRectInLabel.width,
            height: textRect.height
        )
        
        // If there are more than one `NSTextLayoutFragment`.
        let textRangeOfLayoutFragment = textLayoutFragment.rangeInElement
        let utf16IndexOfLayoutFragment = textContentStorage.offset(from: textContentStorage.documentRange.location, to: textRangeOfLayoutFragment.location)
        let documentUtf16Index = utf16IndexOfLayoutFragment + composedCharacterRange.location
        
        return TappableLabelCharacterHit(
            utf16Index: documentUtf16Index,
            characterRect: convert(popupAnchorRectInLabel, to: nil)
        )
    }
    
    func resetText(text: String, highlightRange: NSRange?) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineBreakMode = lineBreakMode
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font!,
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSMutableAttributedString(string: text, attributes: attributes)
        if let highlightRange,
           highlightRange.location != NSNotFound,
           highlightRange.length > 0,
           NSMaxRange(highlightRange) <= attributedString.length {
            attributedString.addAttribute(.backgroundColor, value: UIColor.systemGray, range: highlightRange)
        }
        self.attributedText = attributedString
    }
}
