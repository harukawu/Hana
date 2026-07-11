//
//  SubtitleParser.swift
//  Hana
//
//  Created by Haruka on 2026/7/6.
//

import Foundation

struct SubtitleCue: Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    let startTime: Duration
    let endTime: Duration
    
    init(
        id: UUID = UUID(),
        text: String,
        startTime: Duration,
        endTime: Duration
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

struct SubtitleParser: Sendable {
    func parse(_ url: URL) throws -> [SubtitleCue] {
        try Self.validateFileURL(url)
        let output = try Self.probe(
            url,
            arguments: [
                "-select_streams", "s:0",
                "-show_packets",
                "-show_data",
                "-show_streams",
            ]
        )
        
        guard let stream = output.streams.first else {
            throw SubtitleParserError.noSubtitleStream
        }
        if let codecIdentifier = stream.codecIdentifier,
           TextSubtitleFormat(codecIdentifier: codecIdentifier) == nil {
            return []
        }
        let declaredFormat = stream.codecIdentifier.flatMap(
            TextSubtitleFormat.init(codecIdentifier:)
        )
        let format = try declaredFormat ?? Self.inferTextSubtitleFormat(from: output.packets)
        guard let format else {
            return []
        }
        
        return try Self.cues(from: output.packets, format: format)
    }
    
    func extractEmbeddedSubtitles(from videoURL: URL) throws -> [[SubtitleCue]] {
        try Self.validateFileURL(videoURL)
        let streamOutput = try Self.probe(
            videoURL,
            arguments: [
                "-select_streams", "s",
                "-show_streams",
            ]
        )
        
        return try streamOutput.streams.enumerated().map { subtitleOrdinal, stream in
            if let codecIdentifier = stream.codecIdentifier,
               TextSubtitleFormat(codecIdentifier: codecIdentifier) == nil {
                return []
            }
            
            let packetOutput = try Self.probe(
                videoURL,
                arguments: [
                    "-select_streams", "s:\(subtitleOrdinal)",
                    "-show_packets",
                    "-show_data",
                ]
            )
            let declaredFormat = stream.codecIdentifier.flatMap(
                TextSubtitleFormat.init(codecIdentifier:)
            )
            let format = try declaredFormat ?? Self.inferTextSubtitleFormat(from: packetOutput.packets)
            guard let format else {
                return []
            }
            return try Self.cues(from: packetOutput.packets, format: format)
        }
    }
}

private extension SubtitleParser {
    static func validateFileURL(_ url: URL) throws {
        guard url.isFileURL else {
            throw SubtitleParserError.invalidFileURL(url)
        }
    }
    
    static func probe(_ url: URL, arguments: [String]) throws -> ProbeOutput {
        let probeOutputURL = FileManager.default.temporaryDirectory
            .appending(
                path: "SubtitleParser-\(UUID().uuidString).json",
                directoryHint: .notDirectory
            )
        defer {
            try? FileManager.default.removeItem(at: probeOutputURL)
        }
        
        let fullArguments =
            ["ffprobe", "-v", "error"]
            + arguments
            + ["-of", "json", "-o", probeOutputURL.path, url.path]
        let probeResult = FFmpegCommandRunner.runFFprobe(fullArguments)
        guard probeResult == 0 else {
            throw SubtitleParserError.ffprobeFailed(probeResult)
        }
        
        let outputData = try Data(contentsOf: probeOutputURL)
        do {
            return try JSONDecoder().decode(ProbeOutput.self, from: outputData)
        } catch {
            throw SubtitleParserError.invalidProbeOutput(error)
        }
    }
    
    static func cues(
        from packets: [ProbeOutput.Packet],
        format: TextSubtitleFormat
    ) throws -> [SubtitleCue] {
        try packets.compactMap { packet in
            guard
                let timestamp = packet.presentationTime ?? packet.decodeTime,
                let duration = packet.duration,
                let data = packet.data
            else {
                return nil
            }
            
            let startTime = try Self.duration(seconds: timestamp)
            let cueDuration = try Self.duration(seconds: duration)
            let encodedText = try Self.data(fromHexDump: data)
            guard let decodedText = String(data: encodedText, encoding: .utf8) else {
                throw SubtitleParserError.invalidUTF8
            }
            
            let text = switch format {
            case .ass:
                plainText(fromASSDialogue: decodedText)
            case .subRip:
                normalizeSRTMarkup(in: decodedText)
            }
            return SubtitleCue(
                text: text,
                startTime: startTime,
                endTime: startTime + cueDuration
            )
        }
    }
    
    static func inferTextSubtitleFormat(
        from packets: [ProbeOutput.Packet]
    ) throws -> TextSubtitleFormat? {
        for packet in packets {
            guard let data = packet.data else {
                continue
            }
            
            let encodedText = try Self.data(fromHexDump: data)
            guard let text = String(data: encodedText, encoding: .utf8) else {
                return nil
            }
            return isASSDialogue(text) ? .ass : .subRip
        }
        return nil
    }
    
    static func isASSDialogue(_ text: String) -> Bool {
        let fields = text.split(
            separator: ",",
            maxSplits: 8,
            omittingEmptySubsequences: false
        )
        return fields.count == 9
            && Int(fields[0]) != nil
            && Int(fields[1]) != nil
    }
}

enum SubtitleParserError: Error, LocalizedError, Sendable {
    case invalidFileURL(URL)
    case noSubtitleStream
    case ffprobeFailed(Int)
    case invalidProbeOutput(any Error)
    case invalidTimestamp(String)
    case invalidHexDump
    case invalidUTF8
    
    var errorDescription: String? {
        switch self {
        case .invalidFileURL(let url):
            "The subtitle URL is not a local file URL: \(url)"
        case .noSubtitleStream:
            "FFmpeg did not find a subtitle stream in the file."
        case .ffprobeFailed(let code):
            "FFmpeg could not inspect the subtitle file (exit code \(code))."
        case .invalidProbeOutput(let error):
            "FFmpeg returned invalid subtitle metadata: \(error.localizedDescription)"
        case .invalidTimestamp(let timestamp):
            "FFmpeg returned an invalid subtitle timestamp: \(timestamp)"
        case .invalidHexDump:
            "FFmpeg returned malformed subtitle text data."
        case .invalidUTF8:
            "The subtitle text is not valid UTF-8."
        }
    }
}

private extension SubtitleParser {
    static func plainText(fromASSDialogue dialogue: String) -> String {
        let fields = dialogue.split(
            separator: ",",
            maxSplits: 8,
            omittingEmptySubsequences: false
        )
        let text = fields.count == 9 ? String(fields[8]) : dialogue
        return normalizeASSMarkup(in: text)
    }
    
    static func normalizeSRTMarkup(in text: String) -> String {
        normalizeHTMLMarkup(in: text)
    }
    
    static func normalizeASSMarkup(in text: String) -> String {
        var result = ""
        var index = text.startIndex
        
        while index < text.endIndex {
            let character = text[index]
            
            if character == "{",
               let closingBrace = text[index...].firstIndex(of: "}") {
                index = text.index(after: closingBrace)
                continue
            }
            
            if character == "\\",
               let escapedIndex = text.index(
                   index,
                   offsetBy: 1,
                   limitedBy: text.endIndex
               ),
               escapedIndex < text.endIndex {
                switch text[escapedIndex] {
                case "N", "n":
                    result.append("\n")
                    index = text.index(after: escapedIndex)
                    continue
                case "h":
                    result.append(" ")
                    index = text.index(after: escapedIndex)
                    continue
                case "{", "}":
                    result.append(text[escapedIndex])
                    index = text.index(after: escapedIndex)
                    continue
                case "\u{2060}":
                    result.append("\\")
                    index = text.index(after: escapedIndex)
                    continue
                default:
                    break
                }
            }
            
            result.append(character)
            index = text.index(after: index)
        }
        
        return normalizeHTMLMarkup(in: result)
    }
    
    static func normalizeHTMLMarkup(in text: String) -> String {
        var result = ""
        var index = text.startIndex
        
        while index < text.endIndex {
            if text[index] == "<",
               let closingTag = text[index...].firstIndex(of: ">") {
                let tagStart = text.index(after: index)
                let tag = text[tagStart..<closingTag]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if isSubtitleFormattingTag(tag) {
                    if tag == "br" || tag == "br/" || tag == "br /" {
                        result.append("\n")
                    }
                    index = text.index(after: closingTag)
                    continue
                }
            }
            
            result.append(text[index])
            index = text.index(after: index)
        }
        
        return result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
    
    static func isSubtitleFormattingTag(_ tag: String) -> Bool {
        let tagName = tag
            .trimmingPrefix("/")
            .split(whereSeparator: { $0 == " " || $0 == "/" })
            .first
        return tagName.map { ["b", "i", "u", "s", "font", "span", "br"].contains($0) } ?? false
    }
    
    static func duration(seconds value: String) throws -> Duration {
        let isNegative = value.hasPrefix("-")
        let unsignedValue = value.drop(while: { $0 == "-" || $0 == "+" })
        let components = unsignedValue.split(
            separator: ".",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard
            let wholeSecondsText = components.first,
            let wholeSeconds = Int64(wholeSecondsText)
        else {
            throw SubtitleParserError.invalidTimestamp(value)
        }
        
        var fractionalText = components.count == 2 ? String(components[1]) : ""
        guard fractionalText.allSatisfy(\.isNumber) else {
            throw SubtitleParserError.invalidTimestamp(value)
        }
        fractionalText = String(fractionalText.prefix(9))
        fractionalText.append(
            contentsOf: repeatElement("0", count: 9 - fractionalText.count)
        )
        guard let nanoseconds = Int64(fractionalText) else {
            throw SubtitleParserError.invalidTimestamp(value)
        }
        
        let sign: Int64 = isNegative ? -1 : 1
        return .seconds(sign * wholeSeconds) + .nanoseconds(sign * nanoseconds)
    }
    
    static func data(fromHexDump dump: String) throws -> Data {
        var bytes: [UInt8] = []
        
        for line in dump.split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":") else {
                continue
            }
            let contents = line[line.index(after: colon)...]
            let hex = contents.range(of: "  ").map {
                contents[..<$0.lowerBound]
            } ?? contents[...]
            let digits = hex.filter(\.isHexDigit)
            guard digits.count.isMultiple(of: 2) else {
                throw SubtitleParserError.invalidHexDump
            }
            
            var index = digits.startIndex
            while index < digits.endIndex {
                let nextIndex = digits.index(index, offsetBy: 2)
                guard let byte = UInt8(digits[index..<nextIndex], radix: 16) else {
                    throw SubtitleParserError.invalidHexDump
                }
                bytes.append(byte)
                index = nextIndex
            }
        }
        
        guard !bytes.isEmpty || dump.isEmpty else {
            throw SubtitleParserError.invalidHexDump
        }
        return Data(bytes)
    }
}

private struct ProbeOutput: Decodable {
    let packets: [Packet]
    let streams: [Stream]
    
    private enum CodingKeys: String, CodingKey {
        case packets
        case streams
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packets = try container.decodeIfPresent([Packet].self, forKey: .packets) ?? []
        streams = try container.decodeIfPresent([Stream].self, forKey: .streams) ?? []
    }
    
    struct Packet: Decodable {
        let presentationTime: String?
        let decodeTime: String?
        let duration: String?
        let data: String?
        
        private enum CodingKeys: String, CodingKey {
            case presentationTime = "pts_time"
            case decodeTime = "dts_time"
            case duration = "duration_time"
            case data
        }
    }
    
    struct Stream: Decodable {
        let codecName: String?
        let codecLongName: String?
        
        var codecIdentifier: String? {
            codecName ?? codecLongName
        }
        
        private enum CodingKeys: String, CodingKey {
            case codecName = "codec_name"
            case codecLongName = "codec_long_name"
        }
    }
}

private enum TextSubtitleFormat {
    case ass
    case subRip
    
    init?(codecIdentifier: String) {
        let identifier = codecIdentifier.lowercased()
        if identifier == "ass"
            || identifier == "ssa"
            || identifier.contains("advanced substation alpha") {
            self = .ass
        } else if identifier == "srt"
            || identifier == "subrip"
            || identifier.contains("subrip") {
            self = .subRip
        } else {
            return nil
        }
    }
}
