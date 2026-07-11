//
//  Jimaku.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation

enum JimakuSearchError: LocalizedError {
    case invalidServer
    case invalidResponse
    case invalidApiKey
    case exceedLimit(String?)
    case invalidResponseData
    case other
    
    var errorDescription: String? {
        switch self {
        case .invalidServer:
            return "Invalid Subtitle Server"
        case .invalidResponse:
            return "Invalid Response"
        case .invalidApiKey:
            return "Invalid credential key. Please check in Settings"
        case .exceedLimit(let time):
            if let time = time {
                return "You have hit the rate limit. Please try after \(time) seconds"
            }
            return "You have hit the rate limit."
        case .invalidResponseData:
            return "Data from server is invalid. Pleasae contact with developer"
        case .other:
            return "An unexpected error occured when connecting to server when searching"
        }
    }
}

enum JimakuGetFilesError: LocalizedError {
    case invalidResponse
    case invalidID
    case invalidApiKey
    case notFound
    case exceedLimit(String?)
    case invalidResponseData
    case other
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid Response"
        case .invalidID:
            return "The id of selected video title is invalid"
        case .invalidApiKey:
            return "Invalid credential key. Please check in Settings"
        case .notFound:
            return "Subtitles of current video is not found"
        case .exceedLimit(let time):
            if let time = time {
                return "You have hit the rate limit. Please try after \(time) seconds"
            }
            return "You have hit the rate limit."
        case .invalidResponseData:
            return "Data from server is invalid. Pleasae contact with developer"
        case .other:
            return "An unexpected error occured when connecting to server when getting files"
        }
    }
}

struct JimakuSearchResult: Identifiable, Hashable {
    let id: Int
    let name: String
    let jaName: String?
    
    var displayName: String {
        jaName ?? name
    }
}

struct JimakuSubtitleFile: Identifiable, Hashable {
    let url: URL
    let name: String
    
    var id: URL { url }
}
