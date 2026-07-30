//
//  MiningHistory.swift
//  Hana
//
//  Created by Haruka on 2026/7/25.
//

import CryptoKit
import Foundation
import SwiftData

typealias MiningHistoryData = (
    sentence: String,
    clozeOffset: Int?,
    title: String,
    imageExtension: String,
    formatID: UUID,
    imageData: Data,
    audioData: Data,
    content: [String: String]
)

typealias MiningHistorySendData = (
    sentence: String,
    clozeOffset: Int?,
    title: String,
    imageExtension: String,
    formatID: UUID,
    imageURL: URL,
    audioData: Data,
    content: [String: String]
)

enum MiningError: LocalizedError {
    case writeImageFailed

    var errorDescription: String? {
        switch self {
        case .writeImageFailed:
            "Failed to write image data to disk"
        }
    }
}

enum MiningHistoryStatus: Codable {
    case queued
    case pending
    case failed
}

@Model
class MiningHistory {
    @Attribute(.unique) var id: UUID
    var fingerprint: String
    var createdAt: Date
    var lastAttemptAt: Date?
    var status: MiningHistoryStatus
    var sentence: String
    var clozeOffset: Int?
    var title: String
    var imageExtension: String
    var formatID: UUID
    @Attribute(.externalStorage) var imageData: Data
    @Attribute(.externalStorage) var audioData: Data
    @Attribute(.externalStorage) var content: [String: String]

    init(
        sentence: String,
        clozeOffset: Int?,
        title: String,
        imageExtension: String,
        formatID: UUID,
        imageData: Data,
        audioData: Data,
        content: [String : String]
    ) {
        self.id = UUID()
        self.fingerprint = Self.makeFingerprint(
            sentence: sentence,
            clozeOffset: clozeOffset,
            title: title,
            imageExtension: imageExtension,
            formatID: formatID,
            imageData: imageData,
            audioData: audioData,
            content: content
        )
        self.createdAt = .now
        self.lastAttemptAt = nil
        self.status = .queued
        self.sentence = sentence
        self.title = title
        self.imageExtension = imageExtension
        self.clozeOffset = clozeOffset
        self.formatID = formatID
        self.imageData = imageData
        self.audioData = audioData
        self.content = content
    }

    convenience init(from history: MiningHistoryData) {
        self.init(
            sentence: history.sentence,
            clozeOffset: history.clozeOffset,
            title: history.title,
            imageExtension: history.imageExtension,
            formatID: history.formatID,
            imageData: history.imageData,
            audioData: history.audioData,
            content: history.content
        )
    }

    func toTuple() throws -> MiningHistorySendData {
        let tmpDir = FileStorage.getTempDirectory()
        let imageURL = tmpDir.appending(path: UUID().uuidString).appendingPathExtension(imageExtension)
        do {
            try imageData.write(to: imageURL, options: .atomic)
        } catch {
            throw MiningError.writeImageFailed
        }
        return (
            sentence: sentence,
            clozeOffset: clozeOffset,
            title: title,
            imageExtension: imageExtension,
            formatID: formatID,
            imageURL: imageURL,
            audioData: audioData,
            content: content,
        )
    }
}

extension MiningHistory {
    @discardableResult
    static func saveIfNeeded(
        _ noteData: MiningHistoryData,
        in modelContext: ModelContext
    ) throws -> Bool {
        let history = MiningHistory(from: noteData)
        let expectedFingerPrint = history.fingerprint
        let predicate = #Predicate<MiningHistory> { his in
            his.fingerprint == expectedFingerPrint
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let storedHistories = try modelContext.fetch(descriptor)
        if !storedHistories.isEmpty {
            return true
        }

        modelContext.insert(history)
        try modelContext.save()
        return true
    }

    static func makeFingerprint(
        sentence: String,
        clozeOffset: Int?,
        title: String,
        imageExtension: String,
        formatID: UUID,
        imageData: Data,
        audioData: Data,
        content: [String: String]
    ) -> String {
        var payload = Data()

        func append(_ data: Data) {
            var length = UInt64(data.count).bigEndian
            withUnsafeBytes(of: &length) { payload.append(contentsOf: $0) }
            payload.append(data)
        }

        func append(_ value: String) {
            append(Data(value.utf8))
        }

        append(sentence)
        append(clozeOffset.map { String($0) } ?? "")
        append(title)
        append(imageExtension.lowercased())
        append(formatID.uuidString.lowercased())
        append(imageData)
        append(audioData)
        for key in content.keys.sorted() {
            append(key)
            append(content[key] ?? "")
        }

        return SHA256.hash(data: payload)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
