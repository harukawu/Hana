//
//  WebDAVManager.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation
import SWXMLHash

actor WebDavManager {
    
    let source: WebDavSource
    
    init(source: WebDavSource) {
        self.source = source
    }
    
    func getWebdavFiles(from url: URL? = nil) async throws -> [WebDavFile] {
        var getFilesRequest = URLRequest(url: url ?? self.source.url)
        getFilesRequest.httpMethod = "PROPFIND"
        getFilesRequest.setValue("1", forHTTPHeaderField: "Depth")
        getFilesRequest.setValue(source.authorizationBase64, forHTTPHeaderField: "Authorization")
        
        let (bytes, response) = try await URLSession.shared.bytes(for: getFilesRequest)
        guard let response = response as? HTTPURLResponse else {
            throw WebDAVError.requestError("Invalid request type")
        }
        try validateResponse(response: response)
        var responseData = Data()
        
        for try await byte in bytes {
            responseData.append(byte)
        }
        
        guard let responseString = String(data: responseData, encoding: .utf8) else {
            throw WebDAVError.requestError("Invalid response data")
        }
        
        let xml = XMLHash.config({ config in
            config.shouldProcessNamespaces = true
        }).parse(responseString)
        
        var availableFiles: [WebDavFile] = []
        for singleFile in xml["multistatus"]["response"].all {
            guard let relativePath = singleFile["href"].element?.text else {
                continue
            }
            guard let cleanRelativePath = relativePath.removingPercentEncoding else {
                continue
            }
            let fullURL = source.url.appending(path: cleanRelativePath)
            
            let propTag = singleFile["propstat"][0]["prop"]
            
            let displayName = propTag["displayname"].element?.text ?? ""
            let hrefName = fullURL.lastPathComponent
            
            let isDirectory: Bool = propTag["resourcetype"]["collection"].element != nil
            availableFiles.append(.init(url: fullURL, disPlayName: displayName.isEmpty ? hrefName : displayName, isDirectory: isDirectory))
        }
        
        if !availableFiles.isEmpty {
            availableFiles = Array(availableFiles.dropFirst()) // the first one is the current URL
        }
        return availableFiles
    }
    
    private func validateResponse(response: HTTPURLResponse) throws {
        let statusCode = response.statusCode
        switch statusCode {
        case 200...299:
            return
            
        case 401:
            throw WebDAVError.requestError("Authentication failed. Please check your username and password.")
            
        case 403:
            throw WebDAVError.requestError("You don't have permission to access this folder.")
            
        case 404:
            throw WebDAVError.requestError("The file or folder could not be found.")
            
        case 409:
            throw WebDAVError.requestError("Conflict: Check if the parent directory exists before creating this item.")
            
        case 423:
            throw WebDAVError.requestError("This file is currently locked by another user or process.")
            
        case 507:
            throw WebDAVError.requestError("The server is out of storage space.")
            
        default:
            throw WebDAVError.requestError("An unexpected error occurred. Status code: \(statusCode)")
        }
    }
}
