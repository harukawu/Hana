//
//  VideoPlayerGestures.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import UIKit
import SwiftUI
import UIKit.UIGestureRecognizerSubclass


// MARK: - Gesture names
enum VideoPlayerGestureName {
    static let lookupTap = "VideoPlayerLookupTap"
    static let doubleTap = "VideoPlayerDoubleTapGesture"
    static let twoFingersTap = "VideoPlayerTwoFingersTapGesture"
    static let threeFingersTap = "VideoPlayerThreeFingersTapGesture"
    static let leftPan = "VideoPlayerLeftPanGesture"
    static let rightSwipe = "VideoPlayerRightSwipeGesture"
    static let checkmark = "VideoPlayerCheckmarkGesture"
}

// MARK: - Single Tap
struct VideoPlayerSingleTapGesture: UIGestureRecognizerRepresentable {
    let onSingleTap: (() -> Void)?
    
    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 1
        recognizer.numberOfTouchesRequired = 1
        recognizer.delegate = context.coordinator
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        onSingleTap?()
    }
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            let names: [String] = [VideoPlayerGestureName.doubleTap, VideoPlayerGestureName.twoFingersTap, VideoPlayerGestureName.lookupTap, VideoPlayerGestureName.threeFingersTap]
            return names.contains(where: { $0 == otherGestureRecognizer.name })
        }
    }
}

// MARK: - Double Tap
struct VideoPlayerDoubleTapGesture: UIGestureRecognizerRepresentable {
    let onDoubleTap: ((VideoPlayerGestureZone) -> Void)?
    
    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 2
        recognizer.numberOfTouchesRequired = 1
        recognizer.name = VideoPlayerGestureName.doubleTap
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        guard let view = recognizer.view else { return }
        let zone = gestureZone(view: view, recognizer: recognizer)
        onDoubleTap?(zone)
    }
}

// MARK: - Two Finger Tap
struct VideoPlayerTwoFingersTapGesture: UIGestureRecognizerRepresentable {
    let onTwoFingersTap: (() -> Void)?
    
    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 1
        recognizer.numberOfTouchesRequired = 2
        recognizer.name = VideoPlayerGestureName.twoFingersTap
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        onTwoFingersTap?()
    }
}

// MARK: - Three Finger Tap
struct VideoPlayerThreeFingersTapGesture: UIGestureRecognizerRepresentable {
    let onThreeFingersTap: (() -> Void)?
    
    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 1
        recognizer.numberOfTouchesRequired = 3
        recognizer.name = VideoPlayerGestureName.threeFingersTap
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        onThreeFingersTap?()
    }
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer.name == VideoPlayerGestureName.twoFingersTap
        }
    }
}

// MARK: - Left Pan Gesture

/// This should be used as the translation in y axis relative to the height of the view. Therefore, [-1, 1]
typealias RelativeYTranslation = CGFloat

struct VideoPlayerLeftPanGesture: UIGestureRecognizerRepresentable {
    let onLeftPanBegan: (() -> Void)?
    let onLeftPanChanged: ((RelativeYTranslation) -> Void)?
    let onLeftPanEnded: (() -> Void)?
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.minimumNumberOfTouches = 1
        recognizer.maximumNumberOfTouches = 1
        recognizer.name = VideoPlayerGestureName.leftPan
        recognizer.delegate = context.coordinator
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard let view = recognizer.view else { return }
        switch recognizer.state {
        case .began:
            guard gestureZone(view: view, recognizer: recognizer) == .left else { return }
            onLeftPanBegan?()
        case .changed:
            onLeftPanChanged?(
                recognizer.translation(in: view).y / max(view.bounds.height, 1)
            )
        case .ended:
            onLeftPanEnded?()
        default:
            break
        }
    }
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer.name == VideoPlayerGestureName.rightSwipe || otherGestureRecognizer.name == VideoPlayerGestureName.checkmark
        }
    }
}

// MARK: - Right swipe gesture
struct VideoPlayerRightSwipeGesture: UIGestureRecognizerRepresentable {
    let onRecognized: (() -> Void)?
    
    func makeUIGestureRecognizer(context: Context) -> UISwipeGestureRecognizer {
        let recognizer = UISwipeGestureRecognizer()
        recognizer.direction = .up
        recognizer.numberOfTouchesRequired = 1
        recognizer.name = VideoPlayerGestureName.rightSwipe
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UISwipeGestureRecognizer, context: Context) {
        guard recognizer.state == .ended,
              let view = recognizer.view,
              gestureZone(view: view, recognizer: recognizer) == .right else {
            return
        }
        onRecognized?()
    }
}

// MARK: - Check mark Gesture

struct VideoPlayerCheckMarkGesture: UIGestureRecognizerRepresentable {
    let onRecognized: (() -> Void)?
    
    func makeUIGestureRecognizer(context: Context) -> VideoPlayerCheckMarkRecognizer {
        let recognizer = VideoPlayerCheckMarkRecognizer()
        recognizer.delegate = context.coordinator
        recognizer.name = VideoPlayerGestureName.checkmark
        return recognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: VideoPlayerCheckMarkRecognizer, context: Context) {
        guard recognizer.state == .ended,
              let view = recognizer.view,
              gestureZone(view: view, recognizer: recognizer) == .right else {
            return
        }
        onRecognized?()
    }
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer.name == VideoPlayerGestureName.rightSwipe
        }
    }
}

final class VideoPlayerCheckMarkRecognizer: UIGestureRecognizer {
    private let minimumHorizontalTravel: CGFloat = 20
    private let minimumVerticalTravel: CGFloat = 16
    private let horizontalBacktrackTolerance: CGFloat = 12
    
    private var initialTouchPoint: CGPoint?
    private var lowestTouchPoint: CGPoint?
    private var trackedTouch: UITouch?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        guard trackedTouch == nil else {
            for touch in touches {
                ignore(touch, for: event)
            }
            return
        }
        
        guard touches.count == 1, let touch = touches.first else {
            state = .failed
            return
        }
        
        let location = touch.location(in: view)
        trackedTouch = touch
        initialTouchPoint = location
        lowestTouchPoint = location
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        guard let trackedTouch, touches.contains(trackedTouch) else { return }
        updateLowestPoint(with: trackedTouch.location(in: view))
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        guard let trackedTouch, touches.contains(trackedTouch) else { return }
        
        let finalPoint = trackedTouch.location(in: view)
        updateLowestPoint(with: finalPoint)
        state = isCheckMark(finalPoint: finalPoint) ? .recognized : .failed
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }
    
    override func reset() {
        super.reset()
        initialTouchPoint = nil
        lowestTouchPoint = nil
        trackedTouch = nil
    }
    
    private func updateLowestPoint(with point: CGPoint) {
        if let lowestTouchPoint, point.y <= lowestTouchPoint.y {
            return
        }
        lowestTouchPoint = point
    }
    
    private func isCheckMark(finalPoint: CGPoint) -> Bool {
        guard let initialTouchPoint, let lowestTouchPoint else { return false }
        
        let horizontalTravel = finalPoint.x - initialTouchPoint.x
        let downwardTravel = lowestTouchPoint.y - initialTouchPoint.y
        let upwardTravel = lowestTouchPoint.y - finalPoint.y
        let finishesNearOrRightOfTurn = finalPoint.x >= lowestTouchPoint.x - horizontalBacktrackTolerance
        
        return horizontalTravel >= minimumHorizontalTravel
            && downwardTravel >= minimumVerticalTravel
            && upwardTravel >= minimumVerticalTravel
            && finishesNearOrRightOfTurn
    }
}

// MARK: - Helpers
@MainActor
private func gestureZone(view: UIView, recognizer: UIGestureRecognizer) -> VideoPlayerGestureZone {
    recognizer.location(in: view).x < view.bounds.midX ? .left : .right
}
