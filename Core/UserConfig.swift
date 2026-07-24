//
//  UserConfig.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation
import ObservableDefaults

@MainActor
@ObservableDefaults
class UserConfig {
    
    static let shared = UserConfig()
    
    // MARK: - Jimaku
    var jimakuURL: String = ""
    var jimakuKey: String = ""
    var loadJimakuByLLM: Bool = false
    
    // MARK: - WebDAV
    var webDavSources: [WebDavSource] = []
    
    // MARK: - Playback
    var playbackTheme: Themes = .system
    var autoplayNextVideo: Bool = true
    
    // MARK: - Subtitles
    var nativeSubtitleRendering: Bool = true
    var japaneseFont: Bool = true
    var japaneseOnly: Bool = false
    var subtitleFontSize: Double = 22
    var subtitleBottomOffset: Double = 0
    
    // MARK: - Mining
    @DefaultsKey(userDefaultsKey: "ankiMiningImageOptions")
    var imageOptions: MediaExtractor.ImageOptions = .init()
    
    @DefaultsKey(userDefaultsKey: "ankiMiningAudioOptions")
    var audioOptions: MediaExtractor.AudioOptions = .init()
}
