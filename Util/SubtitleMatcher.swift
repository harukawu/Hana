//
//  SubtitleMatcher.swift
//  Hana
//
//  Created by Haruka on 2026/7/12.
//

import Foundation

struct SubtitleURLMatcher {
    
    private static let supportedSubtitleExtensions = ["srt", "ass"]
    
    private static let flags: Set<String> = [
        "default",
        "forced",
        "foreign",
        "sdh",
        "cc",
        "hi"
    ]
    
    static func isSupportedSubtitle(url: URL) -> Bool {
        supportedSubtitleExtensions.contains(url.pathExtension.lowercased())
    }
    
    /// This methods must be called after verification of the subtitle file is of supported format
    static func isMatched(videoURL: URL, subtitleURL: URL) -> Bool {
        var targetURL = subtitleURL.deletingPathExtension()
        let videoName = videoURL.stem
        while true {
            if targetURL.lastPathComponent == videoName {
                return true
            }
            let currentExtension = targetURL.pathExtension
            guard isIsoCode(currentExtension) || isSupportedFlag(currentExtension) else {
                return false
            }
            let newURL = targetURL.deletingPathExtension()
            if newURL == targetURL {
                return false
            }
            targetURL = newURL
        }
    }
    
    private static func isIsoCode(_ str: String) -> Bool {
        Locale.LanguageCode(str).isISOLanguage
    }
    
    private static func isSupportedFlag(_ flag: String) -> Bool {
        flags.contains(flag.lowercased())
    }
}

private extension URL {
    var stem: String {
        deletingPathExtension().lastPathComponent
    }
}
