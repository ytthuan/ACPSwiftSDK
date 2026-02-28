import Foundation

// MARK: - NDJSON Codec

/// Encoder/decoder for Newline-Delimited JSON (NDJSON).
/// Each message is a single JSON object terminated by `\n`.
public struct NDJSONCodec: Sendable {
    private init() {}

    public static let shared = NDJSONCodec()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [] // compact, no newlines inside
        return e
    }()

    private static let decoder = JSONDecoder()

    /// Encode a Codable value to an NDJSON line (JSON + newline).
    public func encode<T: Encodable & Sendable>(_ value: T) throws -> Data {
        var data = try Self.encoder.encode(value)
        data.append(0x0A) // '\n'
        return data
    }

    /// Decode an NDJSON line to a Codable value.
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let trimmed = data.trimmingNewlines()
        return try Self.decoder.decode(type, from: trimmed)
    }

    /// Decode raw JSON data to a `RawMessage` for dispatch.
    public func decodeRaw(from data: Data) throws -> RawMessage {
        try decode(RawMessage.self, from: data)
    }
}

// MARK: - NDJSON Buffer

/// Buffers incoming data and yields complete NDJSON lines.
/// Handles fragmented WebSocket messages where a single frame
/// may contain partial JSON or multiple JSON objects.
public final class NDJSONBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    public init() {}

    /// Append incoming data and return any complete lines.
    public func append(_ data: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(data)
        var lines: [Data] = []

        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            let trimmed = Data(lineData).trimmingWhitespace()
            if !trimmed.isEmpty {
                lines.append(trimmed)
            }
            buffer = Data(buffer[buffer.index(after: newlineIndex)...])
        }

        // Also check if the buffer contains a complete JSON object without newline
        // (some transports send single objects without trailing newline)
        if !buffer.isEmpty {
            let trimmed = buffer.trimmingWhitespace()
            if trimmed.first == UInt8(ascii: "{") && isCompleteJSON(trimmed) {
                lines.append(trimmed)
                buffer = Data()
            }
        }

        return lines
    }

    /// Check if data contains a complete JSON object by counting braces.
    private func isCompleteJSON(_ data: Data) -> Bool {
        var depth = 0
        var inString = false
        var escaped = false

        for byte in data {
            if escaped {
                escaped = false
                continue
            }
            if byte == UInt8(ascii: "\\") && inString {
                escaped = true
                continue
            }
            if byte == UInt8(ascii: "\"") {
                inString.toggle()
                continue
            }
            if inString { continue }
            if byte == UInt8(ascii: "{") { depth += 1 }
            if byte == UInt8(ascii: "}") { depth -= 1 }
            if depth == 0 && byte == UInt8(ascii: "}") { return true }
        }
        return depth == 0 && !data.isEmpty
    }

    /// Reset the buffer.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer = Data()
    }
}

// MARK: - Data Extensions

extension Data {
    func trimmingNewlines() -> Data {
        var start = startIndex
        var end = endIndex
        while start < end && (self[start] == 0x0A || self[start] == 0x0D) {
            start = index(after: start)
        }
        while end > start {
            let prev = index(before: end)
            if self[prev] == 0x0A || self[prev] == 0x0D {
                end = prev
            } else {
                break
            }
        }
        return self[start..<end]
    }

    func trimmingWhitespace() -> Data {
        var start = startIndex
        var end = endIndex
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        while start < end && whitespace.contains(self[start]) {
            start = index(after: start)
        }
        while end > start {
            let prev = index(before: end)
            if whitespace.contains(self[prev]) {
                end = prev
            } else {
                break
            }
        }
        return Data(self[start..<end])
    }
}
