import Foundation

// MARK: - JSON-RPC 2.0 ID

/// A JSON-RPC 2.0 request/response identifier — either a string or an integer.
public enum JSONRPCID: Hashable, Sendable, Codable {
    case string(String)
    case int(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(
                JSONRPCID.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected String or Int for JSON-RPC ID")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        }
    }

    public var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        }
    }
}

// MARK: - ID Generator

/// Thread-safe auto-incrementing ID generator.
public final class IDGenerator: @unchecked Sendable {
    private var counter: Int = 0
    private let lock = Foundation.NSLock()

    public init() {}

    public func next() -> JSONRPCID {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return .int(counter)
    }
}
