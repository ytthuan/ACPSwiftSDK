import Testing
import Foundation
@testable import ACP

// MARK: - JSONRPCID Tests

@Suite("JSONRPCID")
struct JSONRPCIDTests {
    @Test("String ID encodes correctly")
    func stringIDEncode() throws {
        let id = JSONRPCID.string("abc-123")
        let data = try JSONEncoder().encode(id)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "\"abc-123\"")
    }

    @Test("Integer ID encodes correctly")
    func intIDEncode() throws {
        let id = JSONRPCID.int(42)
        let data = try JSONEncoder().encode(id)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "42")
    }

    @Test("String ID decodes correctly")
    func stringIDDecode() throws {
        let data = Data("\"test-id\"".utf8)
        let id = try JSONDecoder().decode(JSONRPCID.self, from: data)
        #expect(id == JSONRPCID.string("test-id"))
    }

    @Test("Integer ID decodes correctly")
    func intIDDecode() throws {
        let data = Data("99".utf8)
        let id = try JSONDecoder().decode(JSONRPCID.self, from: data)
        #expect(id == JSONRPCID.int(99))
    }

    @Test("ID round-trips")
    func idRoundTrip() throws {
        let ids: [JSONRPCID] = [.string("hello"), .int(7)]
        for original in ids {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(JSONRPCID.self, from: data)
            #expect(decoded == original)
        }
    }

    @Test("IDGenerator produces sequential IDs")
    func idGenerator() {
        let gen = IDGenerator()
        let id1 = gen.next()
        let id2 = gen.next()
        #expect(id1 == JSONRPCID.int(1))
        #expect(id2 == JSONRPCID.int(2))
    }
}

// MARK: - Value Tests

@Suite("Value")
struct ValueTests {
    @Test("Null encodes/decodes")
    func nullRoundTrip() throws {
        let val: Value = .null
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        #expect(decoded == Value.null)
    }

    @Test("Bool encodes/decodes")
    func boolRoundTrip() throws {
        let val: Value = true
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        #expect(decoded == Value.bool(true))
    }

    @Test("Int encodes/decodes")
    func intRoundTrip() throws {
        let val: Value = 42
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        #expect(decoded == Value.int(42))
    }

    @Test("Double encodes/decodes")
    func doubleRoundTrip() throws {
        let val: Value = .double(3.14)
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        if case .double(let v) = decoded {
            #expect(abs(v - 3.14) < 0.001)
        } else {
            Issue.record("Expected double")
        }
    }

    @Test("String encodes/decodes")
    func stringRoundTrip() throws {
        let val: Value = "hello"
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        #expect(decoded == Value.string("hello"))
    }

    @Test("Array encodes/decodes")
    func arrayRoundTrip() throws {
        let val: Value = [1, "two", true]
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        #expect(decoded == .array([.int(1), .string("two"), .bool(true)]))
    }

    @Test("Object encodes/decodes")
    func objectRoundTrip() throws {
        let val: Value = ["key": "value", "num": 42]
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        #expect(decoded["key"] == Value.string("value"))
        #expect(decoded["num"] == Value.int(42))
    }

    @Test("Nested structure round-trips")
    func nestedRoundTrip() throws {
        let val: Value = [
            "name": "test",
            "items": [1, 2, 3],
            "meta": ["nested": true]
        ]
        let data = try JSONEncoder().encode(val)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        #expect(decoded["name"] == Value.string("test"))
        #expect(decoded["meta"]?["nested"] == Value.bool(true))
    }

    @Test("Subscript access works")
    func subscriptAccess() {
        let val: Value = ["a": ["b": 42]]
        #expect(val["a"]?["b"] == Value.int(42))
        #expect(val["missing"] == nil)
    }
}

// MARK: - JSON-RPC Messages Tests

@Suite("JSON-RPC Messages")
struct MessagesTests {
    @Test("Request encodes correctly")
    func requestEncode() throws {
        let req = JSONRPCRequest(
            id: .int(1),
            method: "initialize",
            params: ["clientInfo": ["name": "test"]]
        )
        let data = try JSONEncoder().encode(req)
        let json = try JSONDecoder().decode([String: Value].self, from: data)
        #expect(json["jsonrpc"] == Value.string("2.0"))
        #expect(json["method"] == Value.string("initialize"))
    }

    @Test("Response encodes correctly")
    func responseEncode() throws {
        let resp = JSONRPCResponse(
            id: .string("abc"),
            result: ["ok": true]
        )
        let data = try JSONEncoder().encode(resp)
        let json = try JSONDecoder().decode([String: Value].self, from: data)
        #expect(json["jsonrpc"] == Value.string("2.0"))
        #expect(json["result"]?["ok"] == Value.bool(true))
    }

    @Test("Notification has no id")
    func notificationNoId() throws {
        let notif = JSONRPCNotification<Value>(
            method: "initialized",
            params: .null
        )
        let data = try JSONEncoder().encode(notif)
        let text = String(data: data, encoding: .utf8)!
        #expect(!text.contains("\"id\""))
        #expect(text.contains("\"method\":\"initialized\""))
    }

    @Test("Error response encodes correctly")
    func errorResponseEncode() throws {
        let err = JSONRPCErrorResponse(
            id: .int(5),
            error: JSONRPCError(code: -32600, message: "Invalid Request")
        )
        let data = try JSONEncoder().encode(err)
        let json = try JSONDecoder().decode([String: Value].self, from: data)
        #expect(json["error"]?["code"] == Value.int(-32600))
    }

    @Test("RawMessage dispatches request")
    func rawMessageRequest() throws {
        let json = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#
        let data = Data(json.utf8)
        let raw = try JSONDecoder().decode(RawMessage.self, from: data)
        #expect(raw.id == JSONRPCID.int(1))
        #expect(raw.method == "initialize")
        #expect(raw.isRequest)
    }

    @Test("RawMessage dispatches notification")
    func rawMessageNotification() throws {
        let json = #"{"jsonrpc":"2.0","method":"session/update","params":{}}"#
        let data = Data(json.utf8)
        let raw = try JSONDecoder().decode(RawMessage.self, from: data)
        #expect(raw.method == "session/update")
        #expect(raw.isNotification)
    }

    @Test("RawMessage dispatches response")
    func rawMessageResponse() throws {
        let json = #"{"jsonrpc":"2.0","id":1,"result":{"ok":true}}"#
        let data = Data(json.utf8)
        let raw = try JSONDecoder().decode(RawMessage.self, from: data)
        #expect(raw.id == JSONRPCID.int(1))
        #expect(raw.isResponse)
    }
}

// MARK: - NDJSON Tests

@Suite("NDJSON")
struct NDJSONTests {
    @Test("Encode adds newline")
    func encodeNewline() throws {
        let val: Value = ["key": "val"]
        let data = try NDJSONCodec.shared.encode(val)
        let text = String(data: data, encoding: .utf8)!
        #expect(text.hasSuffix("\n"))
    }

    @Test("Decode strips newline")
    func decodeNewline() throws {
        let line = Data("{\"key\":\"val\"}\n".utf8)
        let val: [String: Value] = try NDJSONCodec.shared.decode([String: Value].self, from: line)
        #expect(val["key"] == Value.string("val"))
    }

    @Test("Buffer yields complete lines")
    func bufferYieldsLines() {
        let buffer = NDJSONBuffer()
        let chunk = Data("{\"a\":1}\n{\"b\":2}\n".utf8)
        let lines = buffer.append(chunk)
        #expect(lines.count == 2)
    }

    @Test("Buffer handles fragmented input")
    func bufferFragmented() {
        let buffer = NDJSONBuffer()
        let part1 = Data("{\"method\":\"ini".utf8)
        let part2 = Data("tialize\"}\n".utf8)
        #expect(buffer.append(part1).isEmpty)
        let lines = buffer.append(part2)
        #expect(lines.count == 1)
    }
}

// MARK: - ContentBlock Tests

@Suite("ContentBlock")
struct ContentBlockTests {
    @Test("Text block round-trips")
    func textBlock() throws {
        let block = ContentBlock.text(TextContent(text: "Hello world"))
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(ContentBlock.self, from: data)
        if case .text(let tc) = decoded {
            #expect(tc.text == "Hello world")
        } else {
            Issue.record("Expected text block")
        }
    }

    @Test("Image block round-trips")
    func imageBlock() throws {
        let block = ContentBlock.image(ImageContent(data: "base64data", mimeType: "image/png"))
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(ContentBlock.self, from: data)
        if case .image(let img) = decoded {
            #expect(img.mimeType == "image/png")
            #expect(img.data == "base64data")
        } else {
            Issue.record("Expected image block")
        }
    }

    @Test("Resource link block round-trips")
    func resourceLinkBlock() throws {
        let content = ResourceLinkContent(uri: "file:///test.swift", name: "test.swift")
        let block = ContentBlock.resourceLink(content)
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(ContentBlock.self, from: data)
        if case .resourceLink(let rl) = decoded {
            #expect(rl.uri == "file:///test.swift")
            #expect(rl.name == "test.swift")
        } else {
            Issue.record("Expected resource link block")
        }
    }
}

// MARK: - Error Tests

@Suite("Errors")
struct ErrorTests {
    @Test("JSONRPCErrorCode standard codes")
    func standardCodes() {
        #expect(JSONRPCErrorCode.parseError.rawValue == -32700)
        #expect(JSONRPCErrorCode.methodNotFound.rawValue == -32601)
    }

    @Test("JSONRPCError factory methods")
    func factoryMethods() {
        let err = JSONRPCError.methodNotFound("test")
        #expect(err.code == -32601)
        #expect(err.message.contains("test"))
    }

    @Test("ACPError cases")
    func acpErrorCases() {
        let err = ACPError.notConnected
        #expect("\(err)".contains("not") || "\(err)".contains("Connected"))
    }
}

// MARK: - TransportState Tests

@Suite("TransportState")
struct TransportStateTests {
    @Test("Equatable works for error case")
    func equatableError() {
        let s1 = TransportState.error("fail")
        let s2 = TransportState.error("fail")
        let s3 = TransportState.error("other")
        #expect(s1 == s2)
        #expect(s1 != s3)
    }

    @Test("Connected and disconnected not equal")
    func connectedDisconnected() {
        #expect(TransportState.connected != TransportState.disconnected)
    }
}
