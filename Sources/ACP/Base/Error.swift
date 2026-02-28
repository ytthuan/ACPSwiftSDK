import Foundation

// MARK: - JSON-RPC 2.0 Error

/// Standard JSON-RPC 2.0 error codes.
public enum JSONRPCErrorCode: Int, Sendable {
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603
}

/// A JSON-RPC 2.0 error object.
public struct JSONRPCError: Error, Hashable, Sendable, Codable {
    public let code: Int
    public let message: String
    public let data: Value?

    public init(code: Int, message: String, data: Value? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public init(code: JSONRPCErrorCode, message: String, data: Value? = nil) {
        self.code = code.rawValue
        self.message = message
        self.data = data
    }

    public static func methodNotFound(_ method: String) -> JSONRPCError {
        JSONRPCError(code: .methodNotFound, message: "Method not found: \(method)")
    }

    public static func invalidParams(_ message: String) -> JSONRPCError {
        JSONRPCError(code: .invalidParams, message: message)
    }

    public static func internalError(_ message: String) -> JSONRPCError {
        JSONRPCError(code: .internalError, message: message)
    }
}

// MARK: - ACP Error

/// High-level errors from the ACP SDK.
public enum ACPError: Error, Sendable {
    case notConnected
    case connectionClosed
    case transportError(String)
    case timeout
    case requestFailed(JSONRPCError)
    case decodingError(String)
    case encodingError(String)
    case unexpectedResponse(String)
    case cancelled
}
