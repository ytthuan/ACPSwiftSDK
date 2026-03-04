import Foundation

// MARK: - Content Blocks

/// A single content block within an ACP prompt or message.
/// Matches the ACP spec's `ContentBlock` discriminated union.
public enum ContentBlock: Hashable, Sendable {
    case text(TextContent)
    case image(ImageContent)
    case audio(AudioContent)
    case resource(ResourceContent)
    case resourceLink(ResourceLinkContent)
}

// MARK: - Codable

extension ContentBlock: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextContent(from: decoder))
        case "image":
            self = .image(try ImageContent(from: decoder))
        case "audio":
            self = .audio(try AudioContent(from: decoder))
        case "resource":
            self = .resource(try ResourceContent(from: decoder))
        case "resource_link":
            self = .resourceLink(try ResourceLinkContent(from: decoder))
        default:
            // Forward-compatible: unknown content types become text placeholders
            self = .text(TextContent(text: "[Unknown content type: \(type)]"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let c): try c.encode(to: encoder)
        case .image(let c): try c.encode(to: encoder)
        case .audio(let c): try c.encode(to: encoder)
        case .resource(let c): try c.encode(to: encoder)
        case .resourceLink(let c): try c.encode(to: encoder)
        }
    }
}

// MARK: - Annotations

public struct Annotations: Codable, Hashable, Sendable {
    public let audience: [String]?
    public let lastModified: String?
    public let priority: Double?
}

// MARK: - Content Types

public struct TextContent: Codable, Hashable, Sendable {
    public let type: String
    public let text: String
    public let annotations: Annotations?
    public let _meta: Value?

    public init(text: String, annotations: Annotations? = nil, _meta: Value? = nil) {
        self.type = "text"
        self.text = text
        self.annotations = annotations
        self._meta = _meta
    }
}

public struct ImageContent: Codable, Hashable, Sendable {
    public let type: String
    public let data: String
    public let mimeType: String
    public let uri: String?
    public let annotations: Annotations?
    public let _meta: Value?

    public init(data: String, mimeType: String, uri: String? = nil, annotations: Annotations? = nil, _meta: Value? = nil) {
        self.type = "image"
        self.data = data
        self.mimeType = mimeType
        self.uri = uri
        self.annotations = annotations
        self._meta = _meta
    }
}

public struct AudioContent: Codable, Hashable, Sendable {
    public let type: String
    public let data: String
    public let mimeType: String
    public let annotations: Annotations?
    public let _meta: Value?

    public init(data: String, mimeType: String, annotations: Annotations? = nil, _meta: Value? = nil) {
        self.type = "audio"
        self.data = data
        self.mimeType = mimeType
        self.annotations = annotations
        self._meta = _meta
    }
}

public struct ResourceContent: Codable, Hashable, Sendable {
    public let type: String
    public let resource: EmbeddedResource
    public let annotations: Annotations?
    public let _meta: Value?

    public init(resource: EmbeddedResource, annotations: Annotations? = nil, _meta: Value? = nil) {
        self.type = "resource"
        self.resource = resource
        self.annotations = annotations
        self._meta = _meta
    }
}

public struct EmbeddedResource: Codable, Hashable, Sendable {
    public let uri: String
    public let mimeType: String?
    public let text: String?
    public let blob: String?
    public let annotations: Annotations?

    public init(uri: String, mimeType: String? = nil, text: String? = nil, blob: String? = nil, annotations: Annotations? = nil) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
        self.blob = blob
        self.annotations = annotations
    }
}

public struct ResourceLinkContent: Codable, Hashable, Sendable {
    public let type: String
    public let uri: String
    /// - Important: Required by the ACP specification.
    public let name: String?
    public let description: String?
    public let mimeType: String?
    public let title: String?
    public let size: Int?
    public let _meta: Value?

    public init(uri: String, name: String? = nil, description: String? = nil, mimeType: String? = nil, title: String? = nil, size: Int? = nil, _meta: Value? = nil) {
        self.type = "resource_link"
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.title = title
        self.size = size
        self._meta = _meta
    }
}

// MARK: - Convenience

extension ContentBlock {
    /// Create a text content block.
    public static func text(_ text: String) -> ContentBlock {
        .text(TextContent(text: text))
    }

    /// Extract text content if this is a text block.
    public var textValue: String? {
        if case .text(let t) = self { return t.text }
        return nil
    }
}
