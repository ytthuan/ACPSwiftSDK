import Foundation

// MARK: - Dynamic JSON Value

/// A dynamically-typed JSON value, similar to `serde_json::Value` in Rust.
/// Supports all JSON primitives plus subscript access.
public enum Value: Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([Value])
    case object([String: Value])
}

// MARK: - Codable

extension Value: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([Value].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: Value].self) {
            self = .object(obj)
        } else {
            throw DecodingError.typeMismatch(
                Value.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Cannot decode Value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let b): try container.encode(b)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .string(let s): try container.encode(s)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        }
    }
}

// MARK: - Accessors

extension Value {
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    public var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: return nil
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var arrayValue: [Value]? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var objectValue: [String: Value]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Subscript by key for object values.
    public subscript(key: String) -> Value? {
        objectValue?[key]
    }

    /// Subscript by index for array values.
    public subscript(index: Int) -> Value? {
        guard let arr = arrayValue, index >= 0, index < arr.count else { return nil }
        return arr[index]
    }
}

// MARK: - ExpressibleBy Literals

extension Value: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

extension Value: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension Value: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension Value: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension Value: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension Value: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Value...) { self = .array(elements) }
}

extension Value: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Value)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
