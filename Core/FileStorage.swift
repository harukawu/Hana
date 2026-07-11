//
//  FileStorage.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation

class FileStorage {
    static func getDocumentDirectory() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
    
    static func getTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }
    
    static func getVideosDirectory() throws -> URL {
        try getDocumentDirectory().appending(path: "Videos")
    }
}
