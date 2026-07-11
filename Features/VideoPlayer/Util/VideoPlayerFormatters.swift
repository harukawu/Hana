//
//  VideoPlayerFormatters.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation

enum VideoPlayerFormatters {
    static func time(_ duration: Duration?) -> String {
        guard let duration else { return "--:--" }
        return time(duration)
    }
    
    static func time(_ duration: Duration) -> String {
        let totalSeconds = max(0, Int(duration.components.seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    static func remaining(currentTime: Duration, duration: Duration?) -> String {
        guard let duration else { return "--:--" }
        let remainingSeconds = max(0, Int((duration - currentTime).components.seconds))
        return "-\(time(.seconds(remainingSeconds)))"
    }
    
    static func playbackRate(_ rate: Float) -> String {
        let rounded = (rate * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(format: "%.0fx", rounded)
        }
        
        return String(format: "%.2fx", rounded)
    }
    
    static func subtitleDelay(milliseconds: Int) -> String {
        if milliseconds == 0 {
            return "0 ms"
        }
        
        return String(format: "%+d ms", milliseconds)
    }
}
