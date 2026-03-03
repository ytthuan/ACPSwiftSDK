# AGENTS.md

> **You are a Swift SDK engineer working on `ACPSwiftSDK`.**
> Implement, build, test, and maintain this Swift Package directly. No orchestration needed.

---

## Project Overview

`ACPSwiftSDK` is a Swift Package implementing the **Agent Client Protocol (ACP)** — JSON-RPC 2.0 types, protocol models, WebSocket transport, NDJSON codec, and the `ACPClient` actor.

Used by the Remo iOS app (`import ACP`) to communicate with GitHub Copilot CLI via a WebSocket bridge.

---

## Package Structure

```
Sources/ACP/
├── Base/         → JSON-RPC 2.0 types (JSONRPCID, Value, Messages, Errors)
├── Models/       → ACP protocol models (ContentBlock, Session, SessionUpdate, ToolCall, ConfigOption)
├── Transport/    → Transport protocol, WebSocketTransport (TLS/self-signed), InMemoryTransport
├── Client/       → ACPClient actor — connect, request/response, handler registration
└── Codec/        → NDJSON codec/buffer for framing
Tests/ACPTests/   → Test suites
```

### Key Types

| Type | Purpose |
|---|---|
| `ACPClient` | Actor — main entry point for all ACP operations |
| `WebSocketTransport` | Actor — WebSocket connection with TLS, NDJSON framing |
| `ContentBlock` | 5 content types: text, image, audio, resource, resourceLink |
| `SessionUpdate` | Typed update cases + `.unknown` for forward compatibility |
| `ConfigOption` | Model/mode/thought_level pickers from agent |
| `JSONRPCID` | Int or String JSON-RPC request ID |
| `Value` | Type-safe JSON value (string, int, double, bool, null, array, object) |

---

## Coding Conventions

- All public types must be `Sendable` and `Codable`
- Use `actor` for stateful types crossing async boundaries
- Forward compatibility: handle unknown enum cases with `.unknown`
- `protocolVersion` must be `Int` (send `1` not `"1"`)
- `mcpServers` required in session/new — always send `[]`

---

## Build & Test

```bash
swift build
swift test
swift test --filter ContentBlockTests
```

---

## Agents

For implementation tasks, dispatch to `.github/agents/sdk-agent.agent.md`.
For concurrency review, dispatch to `.github/agents/concurrency-auditor.agent.md`.
For code review, dispatch to `.github/agents/code-reviewer.agent.md`.
