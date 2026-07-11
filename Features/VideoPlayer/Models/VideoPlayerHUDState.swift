//
//  VideoPlayerHUDModel.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation
import UIKit
import Observation

enum VideoPlayerGestureZone: Sendable {
    case left
    case right
}

enum VideoPlayerHUDState: Equatable, Sendable {
    case brightness(Float)
    case volume(Float)
    case seekBackward(seconds: Int?) // nil indicates seek backward to the last subtitle
    case seekForward(seconds: Int?)
    case subtitleDelay(milliseconds: Int)
    case subtitleHidden(Bool)
    case play
    case pause
    case bookmarkAdded(Duration)
    case bookmarkAlreadyExists(Duration)
    
    var systemImage: String {
        switch self {
        case .brightness:
            "sun.max.fill"
        case .volume(let value):
            value == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .seekBackward(let seconds):
            seconds == nil ? "gobackward" : "gobackward.10"
        case .seekForward(let seconds):
            seconds == nil ? "goforward" : "goforward.10"
        case .subtitleDelay:
            "captions.bubble"
        case .subtitleHidden(let isHidden):
            isHidden ? "eye.slash.fill" : "eye.fill"
        case .play:
            "play.fill"
        case .pause:
            "pause.fill"
        case .bookmarkAdded, .bookmarkAlreadyExists:
            "bookmark.fill"
        }
    }
    
    var title: String {
        switch self {
        case .brightness(let value), .volume(let value):
            "\(Int((value * 100).rounded()))%"
        case .seekBackward(let seconds):
            seconds == nil ? "Backward" : "-\(seconds!)s"
        case .seekForward(let seconds):
            seconds == nil ? "Forward" : "+\(seconds!)s"
        case .subtitleDelay(milliseconds: let milliseconds):
            "\(milliseconds)ms"
        case .subtitleHidden(let isHidden):
            isHidden ? "Subtitles Hidden" : "Subtitles Visible"
        case .play:
            "Play"
        case .pause:
            "Pause"
        case .bookmarkAdded(let time):
            "Bookmarked \(VideoPlayerFormatters.time(time))"
        case .bookmarkAlreadyExists(let time):
            "Already Bookmarked \(VideoPlayerFormatters.time(time))"
        }
    }
    
    var fraction: Float? {
        switch self {
        case .brightness(let value), .volume(let value):
            value
        case .seekBackward, .seekForward, .play, .pause, .subtitleDelay, .subtitleHidden,
                .bookmarkAdded, .bookmarkAlreadyExists:
            nil
        }
    }
}
