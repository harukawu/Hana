//
//  VideoPlayerGestureModifier.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import SwiftUI

struct VideoPlayerGestureModifier: ViewModifier {
    let onSingleTap: (() -> Void)?
    let onDoubleTap: ((VideoPlayerGestureZone) -> Void)?
    let onTwoFingersTap: (() -> Void)?
    let onThreeFingersTap: (() -> Void)?
    let onLeftPanBegan: (() -> Void)?
    let onLeftPanChanged: ((RelativeYTranslation) -> Void)?
    let onLeftPanEnded: (() -> Void)?
    let onRightSwipe: (() -> Void)?
    let onCheckMark: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .gesture(VideoPlayerSingleTapGesture(onSingleTap: onSingleTap))
            .gesture(VideoPlayerDoubleTapGesture(onDoubleTap: onDoubleTap))
            .gesture(VideoPlayerTwoFingersTapGesture(onTwoFingersTap: onTwoFingersTap))
            .gesture(VideoPlayerThreeFingersTapGesture(onThreeFingersTap: onThreeFingersTap))
            .gesture(VideoPlayerLeftPanGesture(onLeftPanBegan: onLeftPanBegan, onLeftPanChanged: onLeftPanChanged, onLeftPanEnded: onLeftPanEnded))
            .gesture(VideoPlayerRightSwipeGesture(onRecognized: onRightSwipe))
            .gesture(VideoPlayerCheckMarkGesture(onRecognized: onCheckMark))
    }
}

extension View {
    func videoPlayerGesture(
        onSingleTap: (() -> Void)?,
        onDoubleTap: ((VideoPlayerGestureZone) -> Void)?,
        onTwoFingersTap: (() -> Void)?,
        onThreeFingersTap: (() -> Void)?,
        onLeftPanBegan: (() -> Void)?,
        onLeftPanChanged: ((RelativeYTranslation) -> Void)?,
        onLeftPanEnded: (() -> Void)?,
        onRightSwipe: (() -> Void)?,
        onCheckMark: (() -> Void)?
    ) -> some View {
        self.modifier(
            VideoPlayerGestureModifier(
                onSingleTap: onSingleTap,
                onDoubleTap: onDoubleTap,
                onTwoFingersTap: onTwoFingersTap,
                onThreeFingersTap: onThreeFingersTap,
                onLeftPanBegan: onLeftPanBegan,
                onLeftPanChanged: onLeftPanChanged,
                onLeftPanEnded: onLeftPanEnded,
                onRightSwipe: onRightSwipe,
                onCheckMark: onCheckMark
            )
        )
    }
}
