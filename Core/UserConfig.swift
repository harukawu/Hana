//
//  UserConfig.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation
import PersistedObservation

@MainActor
@PersistedObservable
class UserConfig {
    
    static let shared = UserConfig()
    private init() {}
    
    // MARK: - Jimaku
    var jimakuURL: String = ""
    var jimakuKey: String = ""
    
    // MARK: - WebDAV
    var webDavSources: [WebDavSource] = []
    
    // MARK: - Subtitles
    var nativeSubtitleRendering: Bool = true
    var japaneseOnly: Bool = false
    
    // MARK: - Mining
    @PersistedObservationTracked(key: "ankiMiningImageOptions")
    var imageOptions: MediaExtractor.ImageOptions = .init()
    
    @PersistedObservationTracked(key: "ankiMiningAudioOptions")
    var audioOptions: MediaExtractor.AudioOptions = .init()
}
