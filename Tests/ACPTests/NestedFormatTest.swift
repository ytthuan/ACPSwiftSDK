import Testing
import Foundation
@testable import ACP

@Test("Parse nested Copilot CLI format")
func nestedCopilotFormat() throws {
    let json = """
    {"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"b11c4564","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"Hello"}}}}
    """
    let (sessionId, update) = try SessionUpdate.parse(from: Data(json.utf8))
    #expect(sessionId == "b11c4564")
    if case .agentMessageChunk(let chunk) = update {
        #expect(chunk.content?.count == 1)
        if case .text(let t) = chunk.content?.first {
            #expect(t.text == "Hello")
            print("TEXT CONTENT: \(t.text)")
        } else {
            Issue.record("Expected text content block")
        }
    } else {
        Issue.record("Expected agentMessageChunk, got \(update)")
    }
}
