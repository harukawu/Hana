//
//  URL+.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation

extension URL {
    func isDirectory() -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: self.path(percentEncoded: false), isDirectory: &isDir)
        return isDir.boolValue
    }
}
