//
//  WebDav.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation

protocol File: Hashable {
    var id: UUID {get}
    var url: URL {get}
    var disPlayName: String {get}
    var isDirectory: Bool {get}
}

struct AnyFile: Hashable {
    
    static func == (lhs: AnyFile, rhs: AnyFile) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: UUID
    let file: any File
    
    init(file: any File) {
        self.id = file.id
        self.file = file
    }
    
}

struct LocalFile: File {
    let id: UUID
    let url: URL
    let disPlayName: String
    let isDirectory: Bool
    
    init(id: UUID = UUID(), url: URL, disPlayName: String, isDirectory: Bool) {
        self.id = id
        self.url = url
        self.disPlayName = disPlayName
        self.isDirectory = isDirectory
    }
}

struct WebDavFile: File {
    let id: UUID = UUID()
    let url: URL
    let disPlayName: String
    let isDirectory: Bool
}

struct WebDavSource: Codable, Hashable {
    let name: String
    let url: URL
    let username: String
    let password: String
    var isEnabled: Bool
    
    var authorizationBase64: String {
        let authString = "\(username):\(password)"
        let authData = authString.data(using: .utf8)!
        let authBase64 = authData.base64EncodedString()
        return "Basic \(authBase64)"
    }
}

enum WebDAVError: LocalizedError {
    case invalidWebDAV
    case invalidPath(String)
    case requestError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidWebDAV:
            return "Current WebDAV source has no valid name or path"
        case .invalidPath(let path):
            return "URL: \(path) is invalid"
        case .requestError(let message):
            return message
        }
    }
}
