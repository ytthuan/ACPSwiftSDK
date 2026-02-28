import Foundation

// MARK: - Session Update Notification

/// Notification sent by the agent during a prompt turn.
/// Method: `session/update`
public enum SessionUpdateNotification: ACPNotification {
    public static let name = "session/update"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let sessionUpdate: String
        // All other fields are in the raw JSON — we parse them dynamically.
        // This struct is only used for initial dispatch.
    }
}

// MARK: - Session Update Types

/// Discriminated union of all session update types.
public enum SessionUpdate: Hashable, Sendable {
    case agentMessageChunk(AgentMessageChunk)
    case userMessageChunk(UserMessageChunk)
    case thoughtMessageChunk(ThoughtMessageChunk)
    case toolCall(ToolCall)
    case toolCallUpdate(ToolCallUpdate)
    case plan(PlanUpdate)
    case availableCommandsUpdate(AvailableCommandsUpdate)
    case currentModeUpdate(CurrentModeUpdate)
    case configOptionsUpdate(ConfigOptionsUpdate)
    case usageUpdate(UsageUpdate)
    case unknown(String, Value)
}

// MARK: - Parsing from raw JSON

extension SessionUpdate {
    /// Parse a session update from raw JSON-RPC notification data.
    /// Handles both:
    /// 1. Copilot CLI format: `{params: {sessionId, update: {sessionUpdate, ...}}}`
    /// 2. Flat format: `{params: {sessionId, sessionUpdate, ...}}`
    /// 3. Direct params without envelope
    public static func parse(from data: Data) throws -> (sessionId: String, update: SessionUpdate) {
        let decoder = JSONDecoder()

        // Try Copilot CLI format: params.update is a nested object
        struct NestedEnvelope: Codable {
            struct Params: Codable {
                let sessionId: String
                let update: RawSessionUpdate
            }
            let params: Params?
        }
        if let envelope = try? decoder.decode(NestedEnvelope.self, from: data),
           let params = envelope.params {
            var raw = params.update
            // Inject sessionId from outer params into the raw update
            raw.sessionId = params.sessionId
            let update = try raw.toTyped()
            return (params.sessionId, update)
        }

        // Try flat format: params contains sessionId + sessionUpdate at same level
        struct FlatEnvelope: Codable {
            let params: RawSessionUpdate?
        }
        if let envelope = try? decoder.decode(FlatEnvelope.self, from: data),
           let raw = envelope.params {
            let update = try raw.toTyped()
            return (raw.sessionId, update)
        }

        // Try as direct params
        let raw = try decoder.decode(RawSessionUpdate.self, from: data)
        let update = try raw.toTyped()
        return (raw.sessionId, update)
    }

    /// Parse a session update from a raw `Value`.
    public static func parse(from value: Value) throws -> (sessionId: String, update: SessionUpdate) {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        return try parse(from: data)
    }
}

// MARK: - Raw Session Update (for decoding)

struct RawSessionUpdate: Sendable {
    var sessionId: String
    let sessionUpdate: String

    // Agent message chunk — handles both single ContentBlock and array
    let content: [ContentBlock]?
    let delta: String?

    // Thought message chunk
    let thought: String?

    // Tool call
    let toolCall: ToolCall?

    // Tool call update
    let toolCallUpdate: ToolCallUpdate?

    // Plan
    let entries: [PlanEntry]?

    // Available commands
    let availableCommands: [AvailableCommand]?

    // Mode
    let currentMode: String?
    let modes: [SessionMode]?

    // Config options
    let configOptions: [ConfigOption]?

    // Usage
    let used: Int?
    let size: Int?
    let cost: UsageCost?
}

extension RawSessionUpdate: Codable {
    private enum CodingKeys: String, CodingKey {
        case sessionId, sessionUpdate, content, delta, thought
        case toolCall, toolCallUpdate, entries, availableCommands
        case currentMode, modes, configOptions, used, size, cost
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        sessionUpdate = try container.decode(String.self, forKey: .sessionUpdate)

        // content can be a single ContentBlock or an array — handle both
        if let array = try? container.decodeIfPresent([ContentBlock].self, forKey: .content) {
            content = array
        } else if let single = try? container.decodeIfPresent(ContentBlock.self, forKey: .content) {
            content = [single]
        } else {
            content = nil
        }

        delta = try container.decodeIfPresent(String.self, forKey: .delta)
        thought = try container.decodeIfPresent(String.self, forKey: .thought)
        toolCall = try container.decodeIfPresent(ToolCall.self, forKey: .toolCall)
        toolCallUpdate = try container.decodeIfPresent(ToolCallUpdate.self, forKey: .toolCallUpdate)
        entries = try container.decodeIfPresent([PlanEntry].self, forKey: .entries)
        availableCommands = try container.decodeIfPresent([AvailableCommand].self, forKey: .availableCommands)
        currentMode = try container.decodeIfPresent(String.self, forKey: .currentMode)
        modes = try container.decodeIfPresent([SessionMode].self, forKey: .modes)
        configOptions = try container.decodeIfPresent([ConfigOption].self, forKey: .configOptions)
        used = try container.decodeIfPresent(Int.self, forKey: .used)
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        cost = try container.decodeIfPresent(UsageCost.self, forKey: .cost)
    }

    func toTyped() throws -> SessionUpdate {
        switch sessionUpdate {
        case "agent_message_chunk":
            return .agentMessageChunk(AgentMessageChunk(
                content: content,
                delta: delta
            ))
        case "user_message_chunk":
            return .userMessageChunk(UserMessageChunk(
                content: content,
                delta: delta
            ))
        case "thought_message_chunk":
            return .thoughtMessageChunk(ThoughtMessageChunk(
                thought: thought ?? delta ?? ""
            ))
        case "tool_call":
            if let tc = toolCall {
                return .toolCall(tc)
            }
            // Some agents inline tool_call fields directly
            return .toolCall(ToolCall(
                id: "", title: nil, kind: nil, status: nil,
                content: nil, locations: nil, confirmationRequest: nil
            ))
        case "tool_call_update":
            if let tcu = toolCallUpdate {
                return .toolCallUpdate(tcu)
            }
            return .toolCallUpdate(ToolCallUpdate(
                id: "", status: nil, content: nil, title: nil
            ))
        case "plan":
            return .plan(PlanUpdate(entries: entries ?? []))
        case "available_commands_update":
            return .availableCommandsUpdate(AvailableCommandsUpdate(
                availableCommands: availableCommands ?? []
            ))
        case "current_mode_update":
            return .currentModeUpdate(CurrentModeUpdate(
                currentMode: currentMode ?? "",
                modes: modes
            ))
        case "config_options_update":
            return .configOptionsUpdate(ConfigOptionsUpdate(
                configOptions: configOptions ?? []
            ))
        case "usage_update":
            return .usageUpdate(UsageUpdate(
                used: used ?? 0,
                size: size ?? 0,
                cost: cost
            ))
        default:
            return .unknown(sessionUpdate, .null)
        }
    }
}

// MARK: - Agent Message Chunk

public struct AgentMessageChunk: Codable, Hashable, Sendable {
    public let content: [ContentBlock]?
    public let delta: String?
}

// MARK: - User Message Chunk

public struct UserMessageChunk: Codable, Hashable, Sendable {
    public let content: [ContentBlock]?
    public let delta: String?
}

// MARK: - Thought Message Chunk

public struct ThoughtMessageChunk: Codable, Hashable, Sendable {
    public let thought: String
}

// MARK: - Tool Call

public struct ToolCall: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String?
    public let kind: ToolKind?
    public let status: ToolCallStatus?
    public let content: [ToolCallContent]?
    public let locations: [ToolCallLocation]?
    public let confirmationRequest: ConfirmationRequest?
}

public struct ToolCallUpdate: Codable, Hashable, Sendable {
    public let id: String
    public let status: ToolCallStatus?
    public let content: [ToolCallContent]?
    public let title: String?
}

public enum ToolKind: String, Codable, Hashable, Sendable {
    case read, edit, delete, move, search, execute, think, fetch, other
}

public enum ToolCallStatus: String, Codable, Hashable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed
}

// MARK: - Tool Call Content

public enum ToolCallContent: Hashable, Sendable {
    case content(String)
    case diff(ToolCallDiff)
    case terminal(ToolCallTerminal)
}

extension ToolCallContent: Codable {
    private enum CodingKeys: String, CodingKey { case type, content, diff, terminal }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? "content"
        switch type {
        case "diff":
            self = .diff(try container.decode(ToolCallDiff.self, forKey: .diff))
        case "terminal":
            self = .terminal(try container.decode(ToolCallTerminal.self, forKey: .terminal))
        default:
            let text = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
            self = .content(text)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .content(let text):
            try container.encode("content", forKey: .type)
            try container.encode(text, forKey: .content)
        case .diff(let d):
            try container.encode("diff", forKey: .type)
            try container.encode(d, forKey: .diff)
        case .terminal(let t):
            try container.encode("terminal", forKey: .type)
            try container.encode(t, forKey: .terminal)
        }
    }
}

public struct ToolCallDiff: Codable, Hashable, Sendable {
    public let before: String?
    public let after: String?
    public let path: String?
}

public struct ToolCallTerminal: Codable, Hashable, Sendable {
    public let command: String?
    public let output: String?
    public let exitCode: Int?
}

// MARK: - Tool Call Location

public struct ToolCallLocation: Codable, Hashable, Sendable {
    public let path: String
    public let lineStart: Int?
    public let lineEnd: Int?
}

// MARK: - Confirmation Request

public struct ConfirmationRequest: Codable, Hashable, Sendable {
    public let title: String?
    public let message: String?
    public let options: [PermissionOption]
}

// MARK: - Permission Request (Agent → Client)

public enum RequestPermission: ACPMethod {
    public static let name = "session/request_permission"

    public struct Parameters: Codable, Hashable, Sendable {
        public let sessionId: String
        public let title: String?
        public let message: String?
        public let options: [PermissionOption]
    }

    public struct Result: Codable, Hashable, Sendable {
        public let outcome: PermissionOutcome
        public let optionId: String?

        public init(outcome: PermissionOutcome, optionId: String? = nil) {
            self.outcome = outcome
            self.optionId = optionId
        }
    }
}

public struct PermissionOption: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String?
    public let description: String?
    public let isDestructive: Bool?
}

public enum PermissionOutcome: String, Codable, Hashable, Sendable {
    case selected
    case cancelled
}

// MARK: - Plan Update

public struct PlanUpdate: Codable, Hashable, Sendable {
    public let entries: [PlanEntry]
}

public struct PlanEntry: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String?
    public let description: String?
    public let priority: PlanPriority?
    public let status: PlanStatus?
}

public enum PlanPriority: String, Codable, Hashable, Sendable {
    case low, medium, high
}

public enum PlanStatus: String, Codable, Hashable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed
}

// MARK: - Available Commands Update

public struct AvailableCommandsUpdate: Codable, Hashable, Sendable {
    public let availableCommands: [AvailableCommand]
}

public struct AvailableCommand: Codable, Hashable, Sendable {
    public let name: String
    public let description: String?
    public let input: AvailableCommandInput?
}

public struct AvailableCommandInput: Codable, Hashable, Sendable {
    public let hint: String?
}

// MARK: - Mode Update

public struct CurrentModeUpdate: Codable, Hashable, Sendable {
    public let currentMode: String
    public let modes: [SessionMode]?
}

// MARK: - Config Options Update

public struct ConfigOptionsUpdate: Codable, Hashable, Sendable {
    public let configOptions: [ConfigOption]
}

// MARK: - Usage Update

public struct UsageUpdate: Codable, Hashable, Sendable {
    public let used: Int
    public let size: Int
    public let cost: UsageCost?
}

public struct UsageCost: Codable, Hashable, Sendable {
    public let amount: Double?
    public let currency: String?
}
