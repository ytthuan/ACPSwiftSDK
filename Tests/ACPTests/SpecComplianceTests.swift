import XCTest
import Foundation
@testable import ACP

final class SpecComplianceTests: XCTestCase {

    // MARK: - Helper

    /// Encode any Encodable value to a JSON dictionary for assertion.
    private func jsonDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        return try XCTUnwrap(obj as? [String: Any])
    }

    // MARK: - 1. Initialize Request

    func testInitializeRequestEncoding() throws {
        let params = Initialize.Parameters(
            protocolVersion: 1,
            clientInfo: ClientInfo(name: "TestClient", title: "Test", version: "1.0.0"),
            clientCapabilities: ClientCapabilities()
        )
        let dict = try jsonDict(params)

        // protocolVersion must be an Int, not a String
        let protocolVersion = try XCTUnwrap(dict["protocolVersion"])
        XCTAssertTrue(protocolVersion is Int || protocolVersion is NSNumber, "protocolVersion should be a number")
        XCTAssertFalse(protocolVersion is String, "protocolVersion must NOT be a String")
        XCTAssertEqual(protocolVersion as? Int, 1)

        // clientInfo fields
        let clientInfo = try XCTUnwrap(dict["clientInfo"] as? [String: Any])
        XCTAssertEqual(clientInfo["name"] as? String, "TestClient")
        XCTAssertEqual(clientInfo["version"] as? String, "1.0.0")
        XCTAssertEqual(clientInfo["title"] as? String, "Test")

        // clientCapabilities is present
        XCTAssertNotNil(dict["clientCapabilities"])
    }

    // MARK: - 2. Session New Request

    func testSessionNewRequestEncoding() throws {
        let params = SessionNew.Parameters(cwd: "/home/user", mcpServers: [])
        let dict = try jsonDict(params)

        XCTAssertEqual(dict["cwd"] as? String, "/home/user")

        let mcpServers = try XCTUnwrap(dict["mcpServers"] as? [Any])
        XCTAssertTrue(mcpServers.isEmpty, "mcpServers should be an empty array")
    }

    // MARK: - 3. Session Prompt Request

    func testSessionPromptRequestEncoding() throws {
        let params = SessionPrompt.Parameters(
            sessionId: "sess_123",
            prompt: [.text("Hello")]
        )
        let dict = try jsonDict(params)

        XCTAssertEqual(dict["sessionId"] as? String, "sess_123")

        let promptArray = try XCTUnwrap(dict["prompt"] as? [[String: Any]])
        XCTAssertEqual(promptArray.count, 1)

        let firstBlock = promptArray[0]
        XCTAssertEqual(firstBlock["type"] as? String, "text")
        XCTAssertEqual(firstBlock["text"] as? String, "Hello")
    }

    // MARK: - 4. StopReason Decoding

    func testStopReasonDecoding() throws {
        let rawValues: [(String, StopReason)] = [
            ("\"end_turn\"", .endTurn),
            ("\"max_tokens\"", .maxTokens),
            ("\"max_turn_requests\"", .maxTurnRequests),
            ("\"refusal\"", .refusal),
            ("\"cancelled\"", .cancelled),
        ]

        let decoder = JSONDecoder()
        for (json, expected) in rawValues {
            let data = Data(json.utf8)
            let decoded = try decoder.decode(StopReason.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed to decode \(json)")
        }
    }

    // MARK: - 5. ContentBlock Text Encoding

    func testContentBlockTextEncoding() throws {
        let content = TextContent(text: "Hello, world!")
        let dict = try jsonDict(content)

        XCTAssertEqual(dict["type"] as? String, "text")
        XCTAssertEqual(dict["text"] as? String, "Hello, world!")
    }

    // MARK: - 6. ContentBlock ResourceLink Encoding

    func testContentBlockResourceLinkEncoding() throws {
        let content = ResourceLinkContent(
            uri: "file:///path/to/resource",
            name: "readme.md",
            description: "A readme file",
            mimeType: "text/markdown",
            title: "README",
            size: 1024
        )
        let dict = try jsonDict(content)

        XCTAssertEqual(dict["type"] as? String, "resource_link")
        XCTAssertEqual(dict["uri"] as? String, "file:///path/to/resource")
        XCTAssertEqual(dict["name"] as? String, "readme.md")
        XCTAssertEqual(dict["title"] as? String, "README")
        XCTAssertEqual(dict["size"] as? Int, 1024)
        XCTAssertEqual(dict["mimeType"] as? String, "text/markdown")
        XCTAssertEqual(dict["description"] as? String, "A readme file")
    }

    // MARK: - 7. ContentBlock Image Encoding

    func testContentBlockImageEncoding() throws {
        let content = ImageContent(
            data: "iVBORw0KGgo=",
            mimeType: "image/png",
            uri: "https://example.com/image.png"
        )
        let dict = try jsonDict(content)

        XCTAssertEqual(dict["type"] as? String, "image")
        XCTAssertEqual(dict["data"] as? String, "iVBORw0KGgo=")
        XCTAssertEqual(dict["mimeType"] as? String, "image/png")
        XCTAssertEqual(dict["uri"] as? String, "https://example.com/image.png")
    }

    // MARK: - 8. MCPServerConfig Stdio

    func testMCPServerConfigStdio() throws {
        let config = MCPServerConfig.stdio(
            name: "fs",
            command: "/path/to/mcp",
            args: ["--stdio"]
        )
        let dict = try jsonDict(config)

        XCTAssertEqual(dict["name"] as? String, "fs")
        XCTAssertEqual(dict["command"] as? String, "/path/to/mcp")

        let args = try XCTUnwrap(dict["args"] as? [String])
        XCTAssertEqual(args, ["--stdio"])
    }

    // MARK: - 9. MCPServerConfig Http

    func testMCPServerConfigHttp() throws {
        let config = MCPServerConfig.http(
            name: "api",
            url: "https://api.example.com",
            headers: [HttpHeader(name: "Authorization", value: "Bearer token")]
        )
        let dict = try jsonDict(config)

        XCTAssertEqual(dict["type"] as? String, "http")
        XCTAssertEqual(dict["name"] as? String, "api")
        XCTAssertEqual(dict["url"] as? String, "https://api.example.com")

        let headers = try XCTUnwrap(dict["headers"] as? [[String: Any]])
        XCTAssertEqual(headers.count, 1)
        XCTAssertEqual(headers[0]["name"] as? String, "Authorization")
        XCTAssertEqual(headers[0]["value"] as? String, "Bearer token")
    }

    // MARK: - 10. PlanEntry with Content

    func testPlanEntryWithContent() throws {
        let json = """
        {
            "id": "plan_001",
            "content": "Implement the login feature",
            "title": "Login",
            "priority": "high",
            "status": "in_progress"
        }
        """.data(using: .utf8)!

        let entry = try JSONDecoder().decode(PlanEntry.self, from: json)

        XCTAssertEqual(entry.id, "plan_001")
        XCTAssertEqual(entry.content, "Implement the login feature")
        XCTAssertEqual(entry.title, "Login")
        XCTAssertEqual(entry.priority, .high)
        XCTAssertEqual(entry.status, .inProgress)
    }

    // MARK: - 11. ToolCallTerminal with terminalId

    func testToolCallTerminalWithTerminalId() throws {
        let json = """
        {"terminalId": "term_123"}
        """.data(using: .utf8)!

        let terminal = try JSONDecoder().decode(ToolCallTerminal.self, from: json)

        XCTAssertEqual(terminal.terminalId, "term_123")
    }

    // MARK: - 12. Permission Request Result Encoding

    func testPermissionRequestResultEncoding() throws {
        let result = RequestPermission.Result(outcome: .selected, optionId: "allow-once")
        let dict = try jsonDict(result)

        // ACP spec: {"outcome": {"outcome": "selected", "optionId": "allow-once"}}
        let outcomeWrapper = try XCTUnwrap(dict["outcome"] as? [String: Any])
        XCTAssertEqual(outcomeWrapper["outcome"] as? String, "selected")
        XCTAssertEqual(outcomeWrapper["optionId"] as? String, "allow-once")
    }

    // MARK: - 13. AuthMethod Decoding

    func testAuthMethodDecoding() throws {
        let json = """
        {"id": "github", "name": "GitHub", "description": "Auth via GitHub"}
        """.data(using: .utf8)!

        let method = try JSONDecoder().decode(AuthMethod.self, from: json)

        XCTAssertEqual(method.id, "github")
        XCTAssertEqual(method.name, "GitHub")
        XCTAssertEqual(method.description, "Auth via GitHub")
    }

    // MARK: - 14. CurrentModeUpdate Decoding

    func testCurrentModeUpdateDecoding() throws {
        // Spec field: currentModeId
        let specJSON = """
        {"currentModeId": "agent"}
        """.data(using: .utf8)!

        let specDecoded = try JSONDecoder().decode(CurrentModeUpdate.self, from: specJSON)
        XCTAssertEqual(specDecoded.currentModeId, "agent")

        // Legacy field: currentMode (falls back correctly)
        let legacyJSON = """
        {"currentMode": "edit"}
        """.data(using: .utf8)!

        let legacyDecoded = try JSONDecoder().decode(CurrentModeUpdate.self, from: legacyJSON)
        XCTAssertEqual(legacyDecoded.currentModeId, "edit")
    }

    // MARK: - 15. CurrentModeUpdate Encoding

    func testCurrentModeUpdateEncoding() throws {
        let update = CurrentModeUpdate(currentModeId: "agent")
        let dict = try jsonDict(update)

        // Must encode as spec field name "currentModeId", NOT "currentMode"
        XCTAssertEqual(dict["currentModeId"] as? String, "agent")
        XCTAssertNil(dict["currentMode"], "Should not encode legacy 'currentMode' key")
    }

    // MARK: - 16. ToolCallLocation with Line

    func testToolCallLocationWithLine() throws {
        let json = """
        {"path": "/tmp/test.py", "line": 42}
        """.data(using: .utf8)!

        let location = try JSONDecoder().decode(ToolCallLocation.self, from: json)

        XCTAssertEqual(location.path, "/tmp/test.py")
        XCTAssertEqual(location.line, 42)
        XCTAssertNil(location.lineStart)
        XCTAssertNil(location.lineEnd)
    }

    // MARK: - 17. PermissionOption Encoding

    func testPermissionOptionEncoding() throws {
        let option = PermissionOption(id: "allow-once", title: "Allow once", kind: .allowOnce)
        let dict = try jsonDict(option)

        // Spec field names: optionId, name, kind
        XCTAssertEqual(dict["optionId"] as? String, "allow-once")
        XCTAssertEqual(dict["name"] as? String, "Allow once")
        XCTAssertEqual(dict["kind"] as? String, "allow_once")
    }

    // MARK: - 18. PermissionOption Decoding (Spec Format)

    func testPermissionOptionDecodingSpecFormat() throws {
        let json = """
        {"optionId": "reject", "name": "Reject", "kind": "reject_once"}
        """.data(using: .utf8)!

        let option = try JSONDecoder().decode(PermissionOption.self, from: json)

        XCTAssertEqual(option.id, "reject")
        XCTAssertEqual(option.title, "Reject")
    }

    // MARK: - 19. EmbeddedResource with Annotations

    func testEmbeddedResourceWithAnnotations() throws {
        let json = """
        {
            "uri": "file:///docs/readme.md",
            "mimeType": "text/markdown",
            "text": "# Hello",
            "annotations": {
                "audience": ["user"],
                "priority": 0.8
            }
        }
        """.data(using: .utf8)!

        let resource = try JSONDecoder().decode(EmbeddedResource.self, from: json)

        XCTAssertEqual(resource.uri, "file:///docs/readme.md")
        XCTAssertEqual(resource.mimeType, "text/markdown")
        XCTAssertEqual(resource.text, "# Hello")

        let annotations = try XCTUnwrap(resource.annotations)
        XCTAssertEqual(annotations.audience, ["user"])
        XCTAssertEqual(annotations.priority, 0.8)
    }
}
