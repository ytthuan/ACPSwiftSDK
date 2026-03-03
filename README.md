# ACP Swift SDK

[![CI](https://github.com/ytthuan/ACPSwiftSDK/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ytthuan/ACPSwiftSDK/actions/workflows/ci.yml)

A Swift 6+ SDK for the [Agent Client Protocol (ACP)](https://agentclientprotocol.com) — the open protocol for communication between AI coding agents and their clients.

## Latest Update (v0.1.2)

- Added missing ACP client-side method support:
  - `fs/read_text_file`, `fs/write_text_file`
  - `terminal/create`, `terminal/output`, `terminal/wait_for_exit`, `terminal/kill`, `terminal/release`
- Added `authenticate` support and `authMethods` in initialize response models.
- Improved ACP schema alignment:
  - Added `uri` to image content
  - Added `title` and `size` to resource links
  - Added `description` to config options
  - Added `content` to plan entries and `terminalId` to terminal tool content
  - Added `_meta` support on content block models
- Added spec compliance tests and terminal malformed-request safety tests.
- Hardened terminal request handlers to avoid force-unwrapping crashes on malformed JSON-RPC requests.

## Features

- **Full ACP spec coverage** — initialize, session management, prompts, tool calls, permissions, config options
- **Type-safe models** — strongly typed JSON-RPC 2.0 messages, content blocks, session updates
- **Pluggable transports** — WebSocket (with TLS/self-signed cert support), in-memory (for testing)
- **Swift 6 strict concurrency** — actor-based client, `Sendable` types throughout
- **Streaming updates** — receive thought chunks, tool calls, agent messages via async handlers
- **Minimal dependencies** — only [swift-log](https://github.com/apple/swift-log)

## Requirements

- Swift 6.0+
- iOS 17+ / macOS 14+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../ACPSwiftSDK")
    // Or from a URL:
    // .package(url: "https://github.com/user/ACPSwiftSDK.git", from: "0.1.0")
]
```

Then add `"ACP"` to your target's dependencies:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "ACP", package: "ACPSwiftSDK")
])
```

## Quick Start

```swift
import ACP

// 1. Create a client
let client = ACPClient(name: "MyApp", version: "1.0")

// 2. Register handlers for streaming updates
await client.onSessionUpdate { sessionId, update in
    switch update {
    case .agentMessageChunk(let chunk):
        if let delta = chunk.delta {
            print(delta, terminator: "")
        }
    case .thoughtMessageChunk(let chunk):
        print("💭 \(chunk.thought)")
    case .toolCall(let tc):
        print("🔧 \(tc.title ?? tc.id): \(tc.status?.rawValue ?? "")")
    case .toolCallUpdate(let tcu):
        print("  → \(tcu.id): \(tcu.status?.rawValue ?? "")")
    default:
        break
    }
}

// 3. Connect via WebSocket
let transport = WebSocketTransport(url: URL(string: "ws://localhost:8765")!)
let initResult = try await client.connect(transport: transport)
print("Connected to \(initResult.agentInfo?.name ?? "agent")")

// 4. Create a session
let session = try await client.newSession()
print("Session: \(session.sessionId)")

// 5. Send a prompt
let result = try await client.prompt(text: "Hello! What can you do?")
print("\nStop reason: \(result.stopReason?.rawValue ?? "unknown")")

// 6. Disconnect
await client.disconnect()
```

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  ACP Swift SDK                                       │
│                                                      │
│  ┌──────────┐  ┌─────────────┐  ┌────────────────┐  │
│  │  Models   │  │  Transport  │  │  Client        │  │
│  │           │  │             │  │                │  │
│  │  JSON-RPC │  │  Protocol   │  │  ACPClient     │  │
│  │  Content  │  │  WebSocket  │  │  (actor)       │  │
│  │  Session  │  │  InMemory   │  │  - connect()   │  │
│  │  Updates  │  │  NDJSON     │  │  - prompt()    │  │
│  │  Tools    │  │             │  │  - handlers    │  │
│  └──────────┘  └─────────────┘  └────────────────┘  │
└──────────────────────────────────────────────────────┘
```

### Components

| Component | Description |
|---|---|
| **Base/** | JSON-RPC 2.0 types (`JSONRPCID`, `Value`, `RawMessage`), error types |
| **Models/** | ACP protocol models — `ContentBlock`, `SessionUpdate`, `ToolCall`, `ConfigOption` |
| **Transport/** | `ACPTransport` protocol, `WebSocketTransport`, `InMemoryTransport`, `NDJSONCodec` |
| **Client/** | `ACPClient` actor — connection management, request/response correlation, handler dispatch |

## API Reference

### ACPClient

```swift
public actor ACPClient {
    // Connection
    func connect(transport: any ACPTransport) async throws -> Initialize.Result
    func disconnect() async
    var isConnected: Bool { get async }

    // Sessions
    func newSession(cwd: String?, mcpServers: [MCPServerConfig]?) async throws -> SessionNew.Result
    func loadSession(sessionId: String, cwd: String?) async throws -> SessionLoad.Result

    // Prompting
    func prompt(text: String) async throws -> SessionPrompt.Result
    func prompt(sessionId: String, content: [ContentBlock]) async throws -> SessionPrompt.Result
    func cancel() async throws

    // Configuration
    func setMode(_ mode: String) async throws -> SessionSetMode.Result
    func setConfigOption(configId: String, value: String) async throws -> SessionSetConfigOption.Result

    // Session management
    func listSessions() async throws -> SessionList.Result
    func deleteSession(sessionId: String) async throws -> SessionDelete.Result

    // Handlers
    func onSessionUpdate(_ handler: @escaping @Sendable (String, SessionUpdate) async -> Void)
    func onRawNotification(_ method: String, handler: @escaping @Sendable (Data) async throws -> Void)
    func onPermissionRequest(_ handler: @escaping @Sendable (JSONRPCID, RequestPermission.Parameters) async throws -> RequestPermission.Result)
}
```

### SessionUpdate

```swift
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
```

### ContentBlock

```swift
public enum ContentBlock: Hashable, Sendable {
    case text(TextContent)
    case image(ImageContent)
    case audio(AudioContent)
    case resource(ResourceContent)
    case resourceLink(ResourceLinkContent)

    // Convenience factory
    static func text(_ text: String) -> ContentBlock
}
```

### Transports

```swift
// WebSocket with optional TLS
let ws = WebSocketTransport(
    url: URL(string: "wss://server:8765")!,
    trustSelfSigned: true
)

// In-memory for testing
let (client, server) = await InMemoryTransport.createPair()
```

## Testing

```bash
swift test
```

The test suite includes:
- **CoreTypesTests** — JSON-RPC, Value, NDJSON, ContentBlock, Error types
- **IntegrationTests** — Transport, session methods, update parsing, tool calls
- **EndToEndTests** — Full conversation flow with mock ACP server
- **SpecComplianceTests** — ACP schema/encoding compliance checks
- **TerminalHandlerMissingParamsTests** — malformed terminal request regression coverage

## Releasing

Stable releases are published from tags in the format `vMAJOR.MINOR.PATCH`.

Quick steps:

```bash
swift build
swift test
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

The `Release` workflow validates tag format, confirms the tag commit is on `main`, runs build/tests, and creates a GitHub Release with auto-generated notes.

Full runbook: [RELEASING.md](RELEASING.md)

## Protocol Reference

This SDK implements the [Agent Client Protocol](https://agentclientprotocol.com):

| Method | Direction | Purpose |
|---|---|---|
| `initialize` | Client → Agent | Negotiate protocol version & capabilities |
| `session/new` | Client → Agent | Create a new conversation session |
| `session/load` | Client → Agent | Resume an existing session |
| `session/prompt` | Client → Agent | Send user message |
| `session/cancel` | Client → Agent | Cancel ongoing prompt turn |
| `session/set_mode` | Client → Agent | Switch agent operating mode |
| `session/set_config_option` | Client → Agent | Change model/mode/thinking config |
| `session/update` | Agent → Client | Stream session updates (10 types) |
| `session/request_permission` | Agent → Client | Ask user to approve tool execution |

## License

See [LICENSE](../LICENSE) in the repository root.
