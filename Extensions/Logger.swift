//
//  Logger.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import OSLog

extension Logger {
    
    static let subsystem: String = Bundle.main.bundleIdentifier!
    
    static let fileStorage = Logger(category: "fileStorage")
    static let webDav = Logger(category: "WebDAV")
    static let video = Logger(category: "Video Player")
    
    init(category: String) {
        self.init(subsystem: Self.subsystem, category: category)
    }
    
}
