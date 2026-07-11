//
//  JimakuManager.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation

class JimakuManager {
    let components: URLComponents
    static let searchPath = "/api/entries/search"
    
    let apiKey: String
    
    init(endpoint: String, apiKey: String) throws {
        let components = URLComponents(string: endpoint)
        guard let components else {
            throw JimakuSearchError.invalidServer
        }
        self.components = components
        self.apiKey = apiKey
    }
    
    /**
    - Parameters:
        - title: title of anime
     */
    func search(title: String) async throws -> [JimakuSearchResult] {
        var components = self.components
        components.path = Self.searchPath
        components.queryItems = [URLQueryItem(name: "query", value: title)]
        let url = components.url!
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "Authorization")
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw JimakuSearchError.invalidResponse
        }
        try validate(searchResponse: response)
        
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        
        var searchResult: [JimakuSearchResult] = []
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                throw JimakuSearchError.invalidResponseData
            }
            for result in jsonObject {
                guard let result = result as? [String: Any],
                      let id = result["id"] as? Int,
                      let name = result["name"] as? String,
                      let jaName = result["japanese_name"] as? String? else {
                    throw JimakuSearchError.invalidResponseData
                }
                searchResult.append(.init(id: id, name: name, jaName: jaName))
            }
        } catch {
            if error is JimakuSearchError {
                throw JimakuSearchError.invalidResponseData
            }
            throw error
        }
        return searchResult
    }
    
    func getFilesList(of id: Int) async throws -> [JimakuSubtitleFile] {
        var components = self.components
        components.path = "/api/entries/\(id)/files"
        let url = components.url!
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "Authorization")
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw JimakuGetFilesError.invalidResponse
        }
        try validate(getFilesResponse: response)
        
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        
        var files: [JimakuSubtitleFile] = []
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                throw JimakuGetFilesError.invalidResponseData
            }
            for file in jsonObject {
                guard let file = file as? [String: Any],
                      let urlStr = file["url"] as? String,
                      let url = URL(string: urlStr),
                      let name = file["name"] as? String else {
                    throw JimakuGetFilesError.invalidResponseData
                }
                files.append(.init(url: url, name: name))
            }
        } catch {
            if error is JimakuGetFilesError {
                throw JimakuGetFilesError.invalidResponseData
            }
            throw error
        }
        return files
    }
    
    static func downloadSubtitle(from url: URL) async throws -> URL {
        let (url, _) = try await URLSession.shared.download(from: url)
        return url
    }
    
    func validate(searchResponse: HTTPURLResponse) throws {
        switch searchResponse.statusCode {
        case 200:
            return
        case 401:
            throw JimakuSearchError.invalidApiKey
        case 429:
            throw JimakuSearchError.exceedLimit(searchResponse.value(forHTTPHeaderField: "x-ratelimit-reset-after"))
        default:
            throw JimakuSearchError.other
        }
    }
    
    func validate(getFilesResponse: HTTPURLResponse) throws {
        switch getFilesResponse.statusCode {
        case 200:
            return
        case 400:
            throw JimakuGetFilesError.invalidID
        case 401:
            throw JimakuGetFilesError.invalidApiKey
        case 404:
            throw JimakuGetFilesError.notFound
        case 429:
            throw JimakuGetFilesError.exceedLimit(getFilesResponse.value(forHTTPHeaderField: "x-ratelimit-reset-after"))
        default:
            throw JimakuGetFilesError.other
        }
    }
    
}
