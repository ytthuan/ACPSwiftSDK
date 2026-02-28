import Foundation

// MARK: - JSON-RPC 2.0 Messages

/// A JSON-RPC 2.0 request (has `id` and `method`).
public struct JSONRPCRequest<Params: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCID
    public let method: String
    public let params: Params?

    public init(id: JSONRPCID, method: String, params: Params? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 notification (has `method` but no `id`).
public struct JSONRPCNotification<Params: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    public let jsonrpc: String
    public let method: String
    public let params: Params?

    public init(method: String, params: Params? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
}

/// A successful JSON-RPC 2.0 response.
public struct JSONRPCResponse<Result: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCID
    public let result: Result

    public init(id: JSONRPCID, result: Result) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
    }
}

/// A JSON-RPC 2.0 error response.
public struct JSONRPCErrorResponse: Codable, Hashable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCID?
    public let error: JSONRPCError

    public init(id: JSONRPCID?, error: JSONRPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.error = error
    }
}

// MARK: - Method Protocol

/// A typed JSON-RPC method with associated parameter and result types.
public protocol ACPMethod: Sendable {
    associatedtype Parameters: Codable & Hashable & Sendable
    associatedtype Result: Codable & Hashable & Sendable
    static var name: String { get }
}

/// A typed JSON-RPC notification with associated parameter type.
public protocol ACPNotification: Sendable {
    associatedtype Parameters: Codable & Hashable & Sendable
    static var name: String { get }
}

// MARK: - Untyped Message Envelope

/// A raw JSON-RPC message envelope for initial dispatch (before type resolution).
public struct RawMessage: Codable, Sendable {
    public let jsonrpc: String?
    public let id: JSONRPCID?
    public let method: String?
    public let params: Value?
    public let result: Value?
    public let error: JSONRPCError?

    public var isRequest: Bool { id != nil && method != nil }
    public var isResponse: Bool { id != nil && method == nil && (result != nil || error != nil) }
    public var isNotification: Bool { id == nil && method != nil }
}
