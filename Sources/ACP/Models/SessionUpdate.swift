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
    let currentModeId: String?
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
        case currentModeId, modes, configOptions, used, size, cost
        // modeId and currentMode are decoded manually (backward compat fallbacks)
    }

    // Manual decode for backward-compat fields
    private enum ExtraKeys: String, CodingKey {
        case modeId, currentMode
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
        // Tool call: try nested "toolCall" key first, then decode flat fields
        if let nested = try? container.decodeIfPresent(ToolCall.self, forKey: .toolCall) {
            toolCall = nested
        } else {
            // CLI sends tool_call fields flat (toolCallId, title, kind, status at same level)
            toolCall = try? ToolCall(from: decoder)
        }
        if let nested = try? container.decodeIfPresent(ToolCallUpdate.self, forKey: .toolCallUpdate) {
            toolCallUpdate = nested
        } else {
            toolCallUpdate = try? ToolCallUpdate(from: decoder)
        }
        entries = try container.decodeIfPresent([PlanEntry].self, forKey: .entries)
        availableCommands = try container.decodeIfPresent([AvailableCommand].self, forKey: .availableCommands)
        // Prefer ACP spec field 'currentModeId', fall back to 'currentMode' or 'modeId'
        let extraContainer = try? decoder.container(keyedBy: ExtraKeys.self)
        currentModeId = try container.decodeIfPresent(String.self, forKey: .currentModeId)
            ?? extraContainer?.decodeIfPresent(String.self, forKey: .currentMode)
            ?? extraContainer?.decodeIfPresent(String.self, forKey: .modeId)
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
        case "thought_message_chunk", "agent_thought_chunk":
            // CLI sends content as ContentBlock, extract text from it
            let thoughtText: String
            if let t = thought {
                thoughtText = t
            } else if let d = delta {
                thoughtText = d
            } else if let blocks = content, let first = blocks.first, case .text(let t) = first {
                thoughtText = t.text
            } else {
                thoughtText = ""
            }
            return .thoughtMessageChunk(ThoughtMessageChunk(
                thought: thoughtText
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
                currentModeId: currentModeId ?? "",
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
    /// - Note: Copilot CLI streaming extension, not part of the ACP specification.
    public let delta: String?
}

// MARK: - User Message Chunk

public struct UserMessageChunk: Codable, Hashable, Sendable {
    public let content: [ContentBlock]?
    /// - Note: Copilot CLI streaming extension, not part of the ACP specification.
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
    public let rawInput: Value?
    public let rawOutput: Value?

    private enum CodingKeys: String, CodingKey {
        case id, toolCallId, title, kind, status, content, locations, confirmationRequest, rawInput, rawOutput
    }

    public init(id: String, title: String? = nil, kind: ToolKind? = nil, status: ToolCallStatus? = nil,
                content: [ToolCallContent]? = nil, locations: [ToolCallLocation]? = nil,
                confirmationRequest: ConfirmationRequest? = nil,
                rawInput: Value? = nil, rawOutput: Value? = nil) {
        self.id = id; self.title = title; self.kind = kind; self.status = status
        self.content = content; self.locations = locations; self.confirmationRequest = confirmationRequest
        self.rawInput = rawInput; self.rawOutput = rawOutput
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Accept both "id" and "toolCallId"
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .toolCallId)
            ?? ""
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.kind = try container.decodeIfPresent(ToolKind.self, forKey: .kind)
        self.status = try container.decodeIfPresent(ToolCallStatus.self, forKey: .status)
        self.content = try container.decodeIfPresent([ToolCallContent].self, forKey: .content)
        self.locations = try container.decodeIfPresent([ToolCallLocation].self, forKey: .locations)
        self.confirmationRequest = try container.decodeIfPresent(ConfirmationRequest.self, forKey: .confirmationRequest)
        self.rawInput = try container.decodeIfPresent(Value.self, forKey: .rawInput)
        self.rawOutput = try container.decodeIfPresent(Value.self, forKey: .rawOutput)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(locations, forKey: .locations)
        try container.encodeIfPresent(confirmationRequest, forKey: .confirmationRequest)
        try container.encodeIfPresent(rawInput, forKey: .rawInput)
        try container.encodeIfPresent(rawOutput, forKey: .rawOutput)
    }
}

public struct ToolCallUpdate: Codable, Hashable, Sendable {
    public let id: String
    public let status: ToolCallStatus?
    public let content: [ToolCallContent]?
    public let title: String?
    public let rawInput: Value?
    public let rawOutput: Value?

    private enum CodingKeys: String, CodingKey {
        case id, toolCallId, status, content, title, rawInput, rawOutput
    }

    public init(id: String, status: ToolCallStatus? = nil, content: [ToolCallContent]? = nil, title: String? = nil,
                rawInput: Value? = nil, rawOutput: Value? = nil) {
        self.id = id; self.status = status; self.content = content; self.title = title
        self.rawInput = rawInput; self.rawOutput = rawOutput
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .toolCallId)
            ?? ""
        self.status = try container.decodeIfPresent(ToolCallStatus.self, forKey: .status)
        self.content = try container.decodeIfPresent([ToolCallContent].self, forKey: .content)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.rawInput = try container.decodeIfPresent(Value.self, forKey: .rawInput)
        self.rawOutput = try container.decodeIfPresent(Value.self, forKey: .rawOutput)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(rawInput, forKey: .rawInput)
        try container.encodeIfPresent(rawOutput, forKey: .rawOutput)
    }
}

public enum ToolKind: String, Codable, Hashable, Sendable {
    case read, edit, delete, move, search, execute, think, fetch, switchMode = "switch_mode", other

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = ToolKind(rawValue: value) ?? .other
    }
}

public enum ToolCallStatus: String, Codable, Hashable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case failed

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = ToolCallStatus(rawValue: value) ?? .pending
    }
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
            // CLI may send content as a plain String or as a nested {type:"text", text:"..."} object
            if let text = try? container.decodeIfPresent(String.self, forKey: .content) {
                self = .content(text ?? "")
            } else {
                struct NestedText: Codable { let text: String? }
                let nested = try? container.decodeIfPresent(NestedText.self, forKey: .content)
                self = .content(nested?.text ?? "")
            }
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
    public let path: String?
    public let oldText: String?
    public let newText: String?

    private enum CodingKeys: String, CodingKey {
        case path, oldText, newText, before, after
    }

    public init(path: String? = nil, oldText: String? = nil, newText: String? = nil) {
        self.path = path; self.oldText = oldText; self.newText = newText
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decodeIfPresent(String.self, forKey: .path)
        self.oldText = try container.decodeIfPresent(String.self, forKey: .oldText)
            ?? container.decodeIfPresent(String.self, forKey: .before)
        self.newText = try container.decodeIfPresent(String.self, forKey: .newText)
            ?? container.decodeIfPresent(String.self, forKey: .after)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(oldText, forKey: .oldText)
        try container.encodeIfPresent(newText, forKey: .newText)
    }
}

public struct ToolCallTerminal: Codable, Hashable, Sendable {
    /// ACP spec: identifies the terminal instance.
    public let terminalId: String?
    public let command: String?
    public let output: String?
    public let exitCode: Int?
}

// MARK: - Tool Call Location

public struct ToolCallLocation: Codable, Hashable, Sendable {
    /// File path targeted by the tool call.
    public let path: String
    /// ACP spec: optional single line number.
    public let line: Int?
    /// Copilot CLI backward-compat: start line of the affected range.
    public let lineStart: Int?
    /// Copilot CLI backward-compat: end line of the affected range.
    public let lineEnd: Int?

    private enum CodingKeys: String, CodingKey {
        case path, line, lineStart, lineEnd
    }

    public init(path: String, line: Int? = nil, lineStart: Int? = nil, lineEnd: Int? = nil) {
        self.path = path
        self.line = line
        self.lineStart = lineStart
        self.lineEnd = lineEnd
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decode(String.self, forKey: .path)
        self.line = try container.decodeIfPresent(Int.self, forKey: .line)
        self.lineStart = try container.decodeIfPresent(Int.self, forKey: .lineStart)
        self.lineEnd = try container.decodeIfPresent(Int.self, forKey: .lineEnd)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(line, forKey: .line)
        try container.encodeIfPresent(lineStart, forKey: .lineStart)
        try container.encodeIfPresent(lineEnd, forKey: .lineEnd)
    }
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
        public let toolCall: ToolCall?
    }

    /// The outer result wraps the decision in an `outcome` object per ACP spec:
    /// `{"outcome": {"outcome": "selected", "optionId": "..."}}`
    public struct Result: Codable, Hashable, Sendable {
        public let outcome: OutcomeWrapper

        public struct OutcomeWrapper: Codable, Hashable, Sendable {
            public let outcome: PermissionOutcome
            public let optionId: String?

            public init(outcome: PermissionOutcome, optionId: String? = nil) {
                self.outcome = outcome
                self.optionId = optionId
            }
        }

        public init(outcome: PermissionOutcome, optionId: String? = nil) {
            self.outcome = OutcomeWrapper(outcome: outcome, optionId: optionId)
        }
    }
}

public enum PermissionOptionKind: String, Codable, Hashable, Sendable {
    case allowOnce = "allow_once"
    case allowAlways = "allow_always"
    case rejectOnce = "reject_once"
    case rejectAlways = "reject_always"
}

public struct PermissionOption: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String?
    public let description: String?
    public let isDestructive: Bool?
    public let kind: PermissionOptionKind?

    private enum CodingKeys: String, CodingKey {
        case id, optionId, title, name, description, isDestructive, kind
    }

    public init(id: String, title: String? = nil, description: String? = nil, isDestructive: Bool? = nil,
                kind: PermissionOptionKind? = nil) {
        self.id = id; self.title = title; self.description = description
        self.isDestructive = isDestructive; self.kind = kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .optionId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
            ?? ""
        self.title = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        let kindString = try container.decodeIfPresent(String.self, forKey: .kind)
        self.kind = kindString.flatMap { PermissionOptionKind(rawValue: $0) }
        self.isDestructive = (kindString?.contains("reject") == true) ? true
            : try container.decodeIfPresent(Bool.self, forKey: .isDestructive)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .optionId)
        try container.encodeIfPresent(title, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(isDestructive, forKey: .isDestructive)
        try container.encodeIfPresent(kind, forKey: .kind)
    }
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
    /// ACP spec required field — the task description.
    public let content: String?
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
    /// - Important: Required by the ACP specification.
    public let description: String?
    public let input: AvailableCommandInput?
}

public struct AvailableCommandInput: Codable, Hashable, Sendable {
    /// - Important: Required by the ACP specification.
    public let hint: String?
}

// MARK: - Mode Update

public struct CurrentModeUpdate: Hashable, Sendable {
    public let currentModeId: String
    public let modes: [SessionMode]?

    public init(currentModeId: String, modes: [SessionMode]? = nil) {
        self.currentModeId = currentModeId
        self.modes = modes
    }

    private enum CodingKeys: String, CodingKey {
        case currentModeId, currentMode, modeId, modes
    }
}

extension CurrentModeUpdate: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Prefer spec-compliant "currentModeId", fall back to "currentMode" or "modeId"
        currentModeId = try container.decodeIfPresent(String.self, forKey: .currentModeId)
            ?? container.decodeIfPresent(String.self, forKey: .currentMode)
            ?? container.decodeIfPresent(String.self, forKey: .modeId)
            ?? ""
        modes = try container.decodeIfPresent([SessionMode].self, forKey: .modes)
    }
}

extension CurrentModeUpdate: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentModeId, forKey: .currentModeId)
        try container.encodeIfPresent(modes, forKey: .modes)
    }
}

// MARK: - Config Options Update

public struct ConfigOptionsUpdate: Codable, Hashable, Sendable {
    public let configOptions: [ConfigOption]
}

// MARK: - Usage Update

/// - Note: Copilot CLI extension, not part of the ACP specification.
public struct UsageUpdate: Codable, Hashable, Sendable {
    public let used: Int
    public let size: Int
    public let cost: UsageCost?
}

/// - Note: Copilot CLI extension, not part of the ACP specification.
public struct UsageCost: Codable, Hashable, Sendable {
    public let amount: Double?
    public let currency: String?
}
