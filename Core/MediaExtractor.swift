//
//  MediaExtractor.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation
import FFmpegSupport

struct MediaExtractor: Sendable {
    enum ImageFormat: String, Codable, Sendable {
        case jpeg
        case png
    }
    
    struct ImageOptions: Codable, Sendable {
        var format: ImageFormat
        var maximumHeight: Int?
        var jpegQuality: Int
        
        init(
            format: ImageFormat = .jpeg,
            maximumHeight: Int? = 720,
            jpegQuality: Int = 85
        ) {
            self.format = format
            self.maximumHeight = maximumHeight
            self.jpegQuality = jpegQuality
        }
    }
    
    struct AudioOptions: Codable, Sendable {
        var bitrateKilobitsPerSecond: Int
        var channelCount: Int
        
        /// Zero-based ordinal among audio tracks (`0:a:N`), not an absolute
        /// index among every video, audio, and subtitle stream.
        var audioTrackIndex: Int
        
        var padding: Duration
        
        init(
            bitrateKilobitsPerSecond: Int = 96,
            channelCount: Int = 1,
            audioTrackIndex: Int = 0,
            padding: Duration = .zero
        ) {
            self.bitrateKilobitsPerSecond = bitrateKilobitsPerSecond
            self.channelCount = channelCount
            self.audioTrackIndex = audioTrackIndex
            self.padding = padding
        }
    }
    
    @discardableResult
    func extractImage(
        from videoURL: URL,
        at timestamp: Duration,
        to outputURL: URL,
        options: ImageOptions = .init()
    ) throws -> URL {
        try Self.validateFileURLs(input: videoURL, output: outputURL)
        guard timestamp >= .zero else {
            throw MediaExtractionError.invalidTimestamp(timestamp)
        }
        if let maximumHeight = options.maximumHeight, maximumHeight <= 0 {
            throw MediaExtractionError.invalidMaximumHeight(maximumHeight)
        }
        if case .jpeg = options.format,
           !(0...100).contains(options.jpegQuality) {
            throw MediaExtractionError.invalidImageQuality(options.jpegQuality)
        }
        try Self.validateOutputExtension(outputURL, for: options.format)
        
        var arguments = Self.baseArguments
        arguments += [
            "-an",
            "-ss", Self.ffmpegTimestamp(timestamp),
            "-i", videoURL.path,
            "-map", "0:v:0",
            "-map_metadata", "-1",
        ]
        if let maximumHeight = options.maximumHeight {
            arguments += [
                "-vf",
                "scale=-2:'min(\(maximumHeight),ih)':flags=sinc+accurate_rnd",
            ]
        }
        arguments += ["-frames:v", "1"]
        
        switch options.format {
        case .jpeg:
            arguments += [
                "-c:v", "mjpeg",
                "-q:v", String(Self.jpegQScale(for: options.jpegQuality)),
                "-f", "image2",
            ]
        case .png:
            arguments += [
                "-c:v", "png",
                "-f", "image2",
            ]
        }
        
        return try Self.runExtraction(
            operation: "Extract image",
            arguments: arguments,
            outputURL: outputURL,
            temporaryExtension: options.format.preferredExtension
        )
    }
    
    @discardableResult
    func extractAudio(
        from videoURL: URL,
        range: Range<Duration>,
        to outputURL: URL,
        options: AudioOptions = .init()
    ) throws -> URL {
        try Self.validateFileURLs(input: videoURL, output: outputURL)
        guard range.lowerBound >= .zero, range.upperBound > range.lowerBound else {
            throw MediaExtractionError.invalidAudioRange(
                start: range.lowerBound,
                end: range.upperBound
            )
        }
        guard options.padding >= .zero else {
            throw MediaExtractionError.invalidAudioPadding(options.padding)
        }
        guard (8...320).contains(options.bitrateKilobitsPerSecond) else {
            throw MediaExtractionError.invalidAudioBitrate(
                options.bitrateKilobitsPerSecond
            )
        }
        guard (1...2).contains(options.channelCount) else {
            throw MediaExtractionError.invalidChannelCount(options.channelCount)
        }
        guard options.audioTrackIndex >= 0 else {
            throw MediaExtractionError.invalidAudioTrackIndex(options.audioTrackIndex)
        }
        guard outputURL.pathExtension.lowercased() == "mp3" else {
            throw MediaExtractionError.invalidOutputExtension(
                expected: ["mp3"],
                actual: outputURL.pathExtension
            )
        }
        
        let startTime = max(.zero, range.lowerBound - options.padding)
        let endTime = range.upperBound + options.padding
        var arguments = Self.baseArguments
        arguments += [
            "-vn",
            "-ss", Self.ffmpegTimestamp(startTime),
            "-to", Self.ffmpegTimestamp(endTime),
            "-i", videoURL.path,
            "-map_metadata", "-1",
            "-map_chapters", "-1",
            "-map", "0:a:\(options.audioTrackIndex)",
            "-ac", String(options.channelCount),
            "-c:a", "libmp3lame",
            "-b:a", "\(options.bitrateKilobitsPerSecond)k",
            "-compression_level", "0",
            "-abr", "1",
            "-f", "mp3",
        ]
        
        return try Self.runExtraction(
            operation: "Extract audio",
            arguments: arguments,
            outputURL: outputURL,
            temporaryExtension: "mp3"
        )
    }
}

enum MediaExtractionError: Error, LocalizedError, Sendable {
    case invalidFileURL(URL)
    case invalidTimestamp(Duration)
    case invalidMaximumHeight(Int)
    case invalidImageQuality(Int)
    case invalidAudioRange(start: Duration, end: Duration)
    case invalidAudioPadding(Duration)
    case invalidAudioBitrate(Int)
    case invalidChannelCount(Int)
    case invalidAudioTrackIndex(Int)
    case invalidOutputExtension(expected: [String], actual: String)
    case ffmpegFailed(operation: String, exitCode: Int)
    case emptyOutput(URL)
    
    var errorDescription: String? {
        switch self {
        case .invalidFileURL(let url):
            "The URL is not a local file URL: \(url)"
        case .invalidTimestamp(let timestamp):
            "The image timestamp must not be negative: \(timestamp)"
        case .invalidMaximumHeight(let height):
            "The maximum image height must be positive: \(height)"
        case .invalidImageQuality(let quality):
            "JPEG quality must be between 0 and 100: \(quality)"
        case .invalidAudioRange(let start, let end):
            "The audio range must have a nonnegative start before its end: \(start)–\(end)"
        case .invalidAudioPadding(let padding):
            "Audio padding must not be negative: \(padding)"
        case .invalidAudioBitrate(let bitrate):
            "MP3 bitrate must be between 8 and 320 kbps: \(bitrate)"
        case .invalidChannelCount(let count):
            "Audio channel count must be 1 or 2: \(count)"
        case .invalidAudioTrackIndex(let index):
            "Audio track index must not be negative: \(index)"
        case .invalidOutputExtension(let expected, let actual):
            "Expected output extension \(expected.joined(separator: " or ")); got \(actual)."
        case .ffmpegFailed(let operation, let exitCode):
            "\(operation) failed with FFmpeg exit code \(exitCode)."
        case .emptyOutput(let url):
            "FFmpeg did not produce a nonempty file at \(url.path)."
        }
    }
}

enum FFmpegCommandRunner {
    private static let lock = NSLock()
    
    static func runFFmpeg(_ arguments: [String]) -> Int {
        lock.withLock {
            ffmpeg(arguments)
        }
    }
    
    static func runFFprobe(_ arguments: [String]) -> Int {
        lock.withLock {
            ffprobe(arguments)
        }
    }
}

private extension MediaExtractor {
    static let baseArguments = [
        "ffmpeg",
        "-hide_banner",
        "-nostdin",
        "-y",
        "-loglevel", "error",
        "-sn",
        "-dn",
    ]
    
    static func validateFileURLs(input: URL, output: URL) throws {
        guard input.isFileURL else {
            throw MediaExtractionError.invalidFileURL(input)
        }
        guard output.isFileURL else {
            throw MediaExtractionError.invalidFileURL(output)
        }
    }
    
    static func validateOutputExtension(
        _ outputURL: URL,
        for format: ImageFormat
    ) throws {
        let actual = outputURL.pathExtension.lowercased()
        guard format.validExtensions.contains(actual) else {
            throw MediaExtractionError.invalidOutputExtension(
                expected: format.validExtensions,
                actual: actual
            )
        }
    }
    
    static func runExtraction(
        operation: String,
        arguments: [String],
        outputURL: URL,
        temporaryExtension: String
    ) throws -> URL {
        let fileManager = FileManager.default
        let outputDirectory = outputURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        
        let temporaryURL = outputDirectory.appending(
            path: ".\(outputURL.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).\(temporaryExtension)",
            directoryHint: .notDirectory
        )
        defer {
            try? fileManager.removeItem(at: temporaryURL)
        }
        
        let exitCode = FFmpegCommandRunner.runFFmpeg(arguments + [temporaryURL.path])
        guard exitCode == 0 else {
            throw MediaExtractionError.ffmpegFailed(
                operation: operation,
                exitCode: exitCode
            )
        }
        
        let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values.fileSize, fileSize > 0 else {
            throw MediaExtractionError.emptyOutput(temporaryURL)
        }
        
        if fileManager.fileExists(atPath: outputURL.path) {
            _ = try fileManager.replaceItemAt(outputURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: outputURL)
        }
        return outputURL
    }
    
    static func ffmpegTimestamp(_ duration: Duration) -> String {
        let seconds = (duration / .milliseconds(1)) / 1_000
        return String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            seconds
        )
    }
    
    static func jpegQScale(for quality: Int) -> Int {
        31 - ((29 * quality + 99) / 100)
    }
}

private extension MediaExtractor.ImageFormat {
    var preferredExtension: String {
        switch self {
        case .jpeg:
            "jpg"
        case .png:
            "png"
        }
    }
    
    var validExtensions: [String] {
        switch self {
        case .jpeg:
            ["jpg", "jpeg"]
        case .png:
            ["png"]
        }
    }
}
