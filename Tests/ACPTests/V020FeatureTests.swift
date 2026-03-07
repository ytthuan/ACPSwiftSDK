import Testing
import Foundation
@testable import ACP

// MARK: - v0.2.0 Model Tests

@Suite("v0.2.0 Model Tests")
struct V020ModelTests {

    // MARK: - ExitPlanMode

    @Test("ExitPlanMode parameters encode correctly")
    func exitPlanModeParametersEncode() throws {
        let params = ExitPlanMode.Parameters(
            summary: "Refactored auth module",
            actions: [
                PlanAction(actionId: "apply", label: "Apply Changes", description: "Apply all pending changes"),
                PlanAction(actionId: "discard", label: "Discard", description: nil)
            ],
            recommendedAction: "apply"
        )
        let data = try JSONEncoder().encode(params)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"summary\":\"Refactored auth module\"") || json.contains("Refactored auth module"))
        #expect(json.contains("apply"))
        #expect(json.contains("discard"))
        #expect(json.contains("recommendedAction"))
    }

    @Test("ExitPlanMode parameters encode with nil optionals")
    func exitPlanModeParametersEncodeMinimal() throws {
        let params = ExitPlanMode.Parameters(summary: "Done")
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(ExitPlanMode.Parameters.self, from: data)
        #expect(decoded.summary == "Done")
        #expect(decoded.actions == nil)
        #expect(decoded.recommendedAction == nil)
    }

    @Test("ExitPlanMode result decodes correctly")
    func exitPlanModeResultDecode() throws {
        let json = """
        {"selectedAction":"apply","feedback":"Looks good, proceed"}
        """
        let result = try JSONDecoder().decode(ExitPlanMode.Result.self, from: Data(json.utf8))
        #expect(result.selectedAction == "apply")
        #expect(result.feedback == "Looks good, proceed")
    }

    @Test("ExitPlanMode result decodes without feedback")
    func exitPlanModeResultDecodeNoFeedback() throws {
        let json = """
        {"selectedAction":"discard"}
        """
        let result = try JSONDecoder().decode(ExitPlanMode.Result.self, from: Data(json.utf8))
        #expect(result.selectedAction == "discard")
        #expect(result.feedback == nil)
    }

    @Test("ExitPlanMode result round-trips")
    func exitPlanModeResultRoundTrip() throws {
        let original = ExitPlanMode.Result(selectedAction: "apply", feedback: "Ship it!")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExitPlanMode.Result.self, from: data)
        #expect(decoded == original)
    }

    @Test("ExitPlanMode method name is correct")
    func exitPlanModeMethodName() {
        #expect(ExitPlanMode.name == "exitPlanMode.request")
    }

    // MARK: - PlanAction

    @Test("PlanAction conforms to Identifiable with actionId as id")
    func planActionIdentifiable() {
        let action = PlanAction(actionId: "execute_all", label: "Execute All", description: "Run all steps")
        #expect(action.id == "execute_all")
        #expect(action.id == action.actionId)
    }

    @Test("PlanAction encodes and decodes correctly")
    func planActionRoundTrip() throws {
        let original = PlanAction(actionId: "step1", label: "Step 1", description: "First step")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PlanAction.self, from: data)
        #expect(decoded == original)
        #expect(decoded.actionId == "step1")
        #expect(decoded.label == "Step 1")
        #expect(decoded.description == "First step")
    }

    @Test("PlanAction decodes with only actionId")
    func planActionMinimal() throws {
        let json = #"{"actionId":"cleanup"}"#
        let action = try JSONDecoder().decode(PlanAction.self, from: Data(json.utf8))
        #expect(action.actionId == "cleanup")
        #expect(action.label == nil)
        #expect(action.description == nil)
    }

    @Test("PlanAction is Hashable")
    func planActionHashable() {
        let a = PlanAction(actionId: "a", label: "A", description: nil)
        let b = PlanAction(actionId: "b", label: "B", description: nil)
        let set: Set<PlanAction> = [a, b, a]
        #expect(set.count == 2)
    }

    // MARK: - Elicitation

    @Test("Elicitation parameters encode with requestedSchema")
    func elicitationParametersEncode() throws {
        let schema: Value = .object([
            "type": .string("object"),
            "properties": .object([
                "confirm": .object([
                    "type": .string("boolean"),
                    "description": .string("Do you want to proceed?")
                ])
            ])
        ])
        let params = Elicitation.Parameters(
            sessionId: "sess_abc",
            message: "Please confirm the action",
            requestedSchema: schema,
            _meta: .object(["timeout": .int(30)])
        )
        let data = try JSONEncoder().encode(params)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("sess_abc"))
        #expect(json.contains("Please confirm the action"))
        #expect(json.contains("requestedSchema"))
        #expect(json.contains("_meta"))
    }

    @Test("Elicitation parameters encode without optional fields")
    func elicitationParametersMinimal() throws {
        let params = Elicitation.Parameters(message: "Continue?")
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(Elicitation.Parameters.self, from: data)
        #expect(decoded.message == "Continue?")
        #expect(decoded.sessionId == nil)
        #expect(decoded.requestedSchema == nil)
        #expect(decoded._meta == nil)
    }

    @Test("Elicitation parameters round-trip")
    func elicitationParametersRoundTrip() throws {
        let original = Elicitation.Parameters(
            sessionId: "s1",
            message: "Do you approve?",
            requestedSchema: .object(["type": .string("boolean")]),
            _meta: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Elicitation.Parameters.self, from: data)
        #expect(decoded == original)
    }

    @Test("Elicitation result decodes accept action")
    func elicitationResultAccept() throws {
        let json = #"{"action":"accept","content":{"confirm":true}}"#
        let result = try JSONDecoder().decode(Elicitation.Result.self, from: Data(json.utf8))
        #expect(result.action == .accept)
        #expect(result.content == .object(["confirm": .bool(true)]))
    }

    @Test("Elicitation result decodes decline action")
    func elicitationResultDecline() throws {
        let json = #"{"action":"decline"}"#
        let result = try JSONDecoder().decode(Elicitation.Result.self, from: Data(json.utf8))
        #expect(result.action == .decline)
        #expect(result.content == nil)
    }

    @Test("Elicitation result decodes cancel action")
    func elicitationResultCancel() throws {
        let json = #"{"action":"cancel"}"#
        let result = try JSONDecoder().decode(Elicitation.Result.self, from: Data(json.utf8))
        #expect(result.action == .cancel)
        #expect(result.content == nil)
    }

    @Test("Elicitation result round-trips")
    func elicitationResultRoundTrip() throws {
        let original = Elicitation.Result(action: .accept, content: .string("yes"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Elicitation.Result.self, from: data)
        #expect(decoded == original)
    }

    @Test("Elicitation method name is correct")
    func elicitationMethodName() {
        #expect(Elicitation.name == "elicitation/create")
    }

    @Test("ElicitationAction raw values are correct")
    func elicitationActionRawValues() {
        #expect(ElicitationAction.accept.rawValue == "accept")
        #expect(ElicitationAction.decline.rawValue == "decline")
        #expect(ElicitationAction.cancel.rawValue == "cancel")
    }

    @Test("ElicitationAction decodes from JSON string")
    func elicitationActionDecode() throws {
        let json = #""accept""#
        let action = try JSONDecoder().decode(ElicitationAction.self, from: Data(json.utf8))
        #expect(action == .accept)
    }

    // MARK: - ToolsList / ToolInfo

    @Test("ToolsList result decodes tools array")
    func toolsListResultDecode() throws {
        let json = """
        {"tools":[{"name":"bash","description":"Execute shell commands","inputSchema":{"type":"object","properties":{"command":{"type":"string"}}}},{"name":"read_file","description":"Read a file"}]}
        """
        let result = try JSONDecoder().decode(ToolsList.Result.self, from: Data(json.utf8))
        #expect(result.tools.count == 2)
        #expect(result.tools[0].name == "bash")
        #expect(result.tools[0].description == "Execute shell commands")
        #expect(result.tools[0].inputSchema != nil)
        #expect(result.tools[1].name == "read_file")
        #expect(result.tools[1].description == "Read a file")
        #expect(result.tools[1].inputSchema == nil)
    }

    @Test("ToolsList result decodes empty tools array")
    func toolsListResultDecodeEmpty() throws {
        let json = #"{"tools":[]}"#
        let result = try JSONDecoder().decode(ToolsList.Result.self, from: Data(json.utf8))
        #expect(result.tools.isEmpty)
    }

    @Test("ToolInfo conforms to Identifiable with name as id")
    func toolInfoIdentifiable() {
        let tool = ToolInfo(name: "bash", description: "Shell", inputSchema: nil)
        #expect(tool.id == "bash")
        #expect(tool.id == tool.name)
    }

    @Test("ToolInfo encodes and decodes correctly")
    func toolInfoRoundTrip() throws {
        let schema: Value = .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object(["type": .string("string")])
            ])
        ])
        let original = ToolInfo(name: "read_file", description: "Read a file from disk", inputSchema: schema)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolInfo.self, from: data)
        #expect(decoded == original)
        #expect(decoded.name == "read_file")
        #expect(decoded.description == "Read a file from disk")
        #expect(decoded.inputSchema != nil)
    }

    @Test("ToolInfo decodes with only name")
    func toolInfoMinimal() throws {
        let json = #"{"name":"search"}"#
        let tool = try JSONDecoder().decode(ToolInfo.self, from: Data(json.utf8))
        #expect(tool.name == "search")
        #expect(tool.description == nil)
        #expect(tool.inputSchema == nil)
    }

    @Test("ToolsList method name is correct")
    func toolsListMethodName() {
        #expect(ToolsList.name == "tools/list")
    }

    @Test("ToolsList parameters encode with sessionId")
    func toolsListParametersEncode() throws {
        let params = ToolsList.Parameters(sessionId: "sess_xyz")
        let data = try JSONEncoder().encode(params)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("sess_xyz"))
    }

    @Test("ToolsList parameters encode without sessionId")
    func toolsListParametersEncodeNil() throws {
        let params = ToolsList.Parameters()
        let data = try JSONEncoder().encode(params)
        let decoded = try JSONDecoder().decode(ToolsList.Parameters.self, from: data)
        #expect(decoded.sessionId == nil)
    }

    // MARK: - SessionSummary / SessionContext

    @Test("SessionSummary decodes with context")
    func sessionSummaryWithContext() throws {
        let json = """
        {
            "sessionId": "sess_001",
            "title": "Refactor Auth",
            "createdAt": "2025-01-15T10:00:00Z",
            "updatedAt": "2025-01-15T11:30:00Z",
            "context": {
                "cwd": "/Users/dev/project",
                "repository": "acme/app",
                "branch": "feature/auth"
            }
        }
        """
        let summary = try JSONDecoder().decode(SessionSummary.self, from: Data(json.utf8))
        #expect(summary.sessionId == "sess_001")
        #expect(summary.title == "Refactor Auth")
        #expect(summary.createdAt == "2025-01-15T10:00:00Z")
        #expect(summary.updatedAt == "2025-01-15T11:30:00Z")
        #expect(summary.context != nil)
        #expect(summary.context?.cwd == "/Users/dev/project")
        #expect(summary.context?.repository == "acme/app")
        #expect(summary.context?.branch == "feature/auth")
    }

    @Test("SessionSummary decodes without context (backward compat)")
    func sessionSummaryWithoutContext() throws {
        let json = """
        {"sessionId":"sess_002","title":"Quick Fix"}
        """
        let summary = try JSONDecoder().decode(SessionSummary.self, from: Data(json.utf8))
        #expect(summary.sessionId == "sess_002")
        #expect(summary.title == "Quick Fix")
        #expect(summary.context == nil)
        #expect(summary.createdAt == nil)
        #expect(summary.updatedAt == nil)
    }

    @Test("SessionSummary decodes with minimal fields")
    func sessionSummaryMinimal() throws {
        let json = #"{"sessionId":"sess_003"}"#
        let summary = try JSONDecoder().decode(SessionSummary.self, from: Data(json.utf8))
        #expect(summary.sessionId == "sess_003")
        #expect(summary.title == nil)
        #expect(summary.context == nil)
    }

    @Test("SessionSummary round-trips with context")
    func sessionSummaryRoundTrip() throws {
        let original = SessionSummary(
            sessionId: "sess_rt",
            title: "Test Session",
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T01:00:00Z",
            context: SessionContext(cwd: "/tmp", repository: "test/repo", branch: "main")
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionSummary.self, from: data)
        #expect(decoded == original)
    }

    @Test("SessionContext encodes and decodes correctly")
    func sessionContextRoundTrip() throws {
        let original = SessionContext(cwd: "/home/user/project", repository: "org/repo", branch: "develop")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionContext.self, from: data)
        #expect(decoded == original)
        #expect(decoded.cwd == "/home/user/project")
        #expect(decoded.repository == "org/repo")
        #expect(decoded.branch == "develop")
    }

    @Test("SessionContext decodes with all nil fields")
    func sessionContextAllNil() throws {
        let json = #"{}"#
        let ctx = try JSONDecoder().decode(SessionContext.self, from: Data(json.utf8))
        #expect(ctx.cwd == nil)
        #expect(ctx.repository == nil)
        #expect(ctx.branch == nil)
    }

    @Test("SessionContext decodes with partial fields")
    func sessionContextPartial() throws {
        let json = #"{"cwd":"/tmp"}"#
        let ctx = try JSONDecoder().decode(SessionContext.self, from: Data(json.utf8))
        #expect(ctx.cwd == "/tmp")
        #expect(ctx.repository == nil)
        #expect(ctx.branch == nil)
    }
}

// MARK: - Bridge API Model Tests

@Suite("Bridge API Model Tests")
struct BridgeModelTests {

    // MARK: - BridgeHealth

    @Test("BridgeHealth decodes with snake_case keys")
    func bridgeHealthDecode() throws {
        let json = """
        {"status":"ok","version":"0.2.0","copilot_cli_version":"1.0.2","uptime_secs":3600}
        """
        let health = try JSONDecoder().decode(BridgeHealth.self, from: Data(json.utf8))
        #expect(health.status == "ok")
        #expect(health.version == "0.2.0")
        #expect(health.copilotCliVersion == "1.0.2")
        #expect(health.uptimeSecs == 3600)
    }

    @Test("BridgeHealth decodes with null copilot_cli_version")
    func bridgeHealthNullCopilot() throws {
        let json = """
        {"status":"ok","version":"0.2.0","copilot_cli_version":null,"uptime_secs":100}
        """
        let health = try JSONDecoder().decode(BridgeHealth.self, from: Data(json.utf8))
        #expect(health.status == "ok")
        #expect(health.version == "0.2.0")
        #expect(health.copilotCliVersion == nil)
        #expect(health.uptimeSecs == 100)
    }

    @Test("BridgeHealth round-trips correctly")
    func bridgeHealthRoundTrip() throws {
        let original = BridgeHealth(status: "ok", version: "0.3.0", copilotCliVersion: "2.0.0", uptimeSecs: 7200)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(BridgeHealth.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - CopilotInfo

    @Test("CopilotInfo decodes with features array")
    func copilotInfoDecode() throws {
        let json = """
        {"version":"1.0.2","path":"/usr/local/bin/copilot","mode":"stdio","ga":true,"features":["ga","reasoning_effort","exit_plan_mode"]}
        """
        let info = try JSONDecoder().decode(CopilotInfo.self, from: Data(json.utf8))
        #expect(info.version == "1.0.2")
        #expect(info.path == "/usr/local/bin/copilot")
        #expect(info.mode == "stdio")
        #expect(info.ga == true)
        #expect(info.features?.count == 3)
        #expect(info.features?.contains("exit_plan_mode") == true)
    }

    @Test("CopilotInfo decodes with minimal fields")
    func copilotInfoMinimal() throws {
        let json = #"{"version":"0.9.0"}"#
        let info = try JSONDecoder().decode(CopilotInfo.self, from: Data(json.utf8))
        #expect(info.version == "0.9.0")
        #expect(info.path == nil)
        #expect(info.mode == nil)
        #expect(info.ga == nil)
        #expect(info.features == nil)
    }

    @Test("CopilotInfo round-trips correctly")
    func copilotInfoRoundTrip() throws {
        let original = CopilotInfo(
            version: "1.0.0",
            path: "/opt/copilot",
            mode: "stdio",
            ga: false,
            features: ["basic"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CopilotInfo.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - CopilotUsage

    @Test("CopilotUsage decodes with nested model usage")
    func copilotUsageDecode() throws {
        let json = """
        {
            "totalSessions": 42,
            "totalTurns": 256,
            "totalFilesEdited": 89,
            "modelUsage": [
                {"model": "gpt-4o", "count": 150},
                {"model": "claude-sonnet", "count": 106}
            ],
            "sessionsByMonth": [
                {"month": "2025-01", "sessions": 20, "turns": 120},
                {"month": "2025-02", "sessions": 22, "turns": 136}
            ],
            "totalToolExecutions": 512,
            "eventTypeCounts": {"prompt": 256, "tool_call": 512}
        }
        """
        let usage = try JSONDecoder().decode(CopilotUsage.self, from: Data(json.utf8))
        #expect(usage.totalSessions == 42)
        #expect(usage.totalTurns == 256)
        #expect(usage.totalFilesEdited == 89)
        #expect(usage.modelUsage?.count == 2)
        #expect(usage.modelUsage?[0].model == "gpt-4o")
        #expect(usage.modelUsage?[0].count == 150)
        #expect(usage.modelUsage?[1].model == "claude-sonnet")
        #expect(usage.sessionsByMonth?.count == 2)
        #expect(usage.sessionsByMonth?[0].month == "2025-01")
        #expect(usage.sessionsByMonth?[0].sessions == 20)
        #expect(usage.sessionsByMonth?[0].turns == 120)
        #expect(usage.totalToolExecutions == 512)
        #expect(usage.eventTypeCounts?["prompt"] == 256)
    }

    @Test("CopilotUsage decodes with required fields only")
    func copilotUsageMinimal() throws {
        let json = #"{"totalSessions":5,"totalTurns":10,"totalFilesEdited":2}"#
        let usage = try JSONDecoder().decode(CopilotUsage.self, from: Data(json.utf8))
        #expect(usage.totalSessions == 5)
        #expect(usage.totalTurns == 10)
        #expect(usage.totalFilesEdited == 2)
        #expect(usage.modelUsage == nil)
        #expect(usage.sessionsByMonth == nil)
        #expect(usage.totalToolExecutions == nil)
        #expect(usage.eventTypeCounts == nil)
    }

    @Test("CopilotUsage round-trips correctly")
    func copilotUsageRoundTrip() throws {
        let original = CopilotUsage(
            totalSessions: 10,
            totalTurns: 50,
            totalFilesEdited: 15,
            modelUsage: [CopilotUsage.ModelUsageEntry(model: "gpt-4o", count: 50)],
            sessionsByMonth: [CopilotUsage.MonthlySessionEntry(month: "2025-03", sessions: 10, turns: 50)],
            totalToolExecutions: 100,
            eventTypeCounts: ["test": 42]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CopilotUsage.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - BridgeSession

    @Test("BridgeSession decodes with all fields")
    func bridgeSessionDecode() throws {
        let json = """
        {
            "id": "bs_001",
            "copilot_session_id": "cps_abc",
            "status": "active",
            "created_at": "2025-01-15T10:00:00Z",
            "last_activity": "2025-01-15T10:30:00Z",
            "prompt_count": 5,
            "message_count": 12
        }
        """
        let session = try JSONDecoder().decode(BridgeSession.self, from: Data(json.utf8))
        #expect(session.id == "bs_001")
        #expect(session.copilotSessionId == "cps_abc")
        #expect(session.status == "active")
        #expect(session.createdAt == "2025-01-15T10:00:00Z")
        #expect(session.lastActivity == "2025-01-15T10:30:00Z")
        #expect(session.promptCount == 5)
        #expect(session.messageCount == 12)
    }

    @Test("BridgeSession decodes with minimal fields")
    func bridgeSessionMinimal() throws {
        let json = #"{"id":"bs_002","status":"idle"}"#
        let session = try JSONDecoder().decode(BridgeSession.self, from: Data(json.utf8))
        #expect(session.id == "bs_002")
        #expect(session.status == "idle")
        #expect(session.copilotSessionId == nil)
        #expect(session.createdAt == nil)
        #expect(session.lastActivity == nil)
        #expect(session.promptCount == nil)
        #expect(session.messageCount == nil)
    }

    @Test("BridgeSession round-trips correctly")
    func bridgeSessionRoundTrip() throws {
        let original = BridgeSession(
            id: "bs_rt",
            copilotSessionId: "cps_rt",
            status: "active",
            createdAt: "2025-01-01",
            lastActivity: "2025-01-02",
            promptCount: 3,
            messageCount: 8
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BridgeSession.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - BridgeCommand

    @Test("BridgeCommand decodes correctly")
    func bridgeCommandDecode() throws {
        let json = #"{"name":"web","description":"Search the web"}"#
        let cmd = try JSONDecoder().decode(BridgeCommand.self, from: Data(json.utf8))
        #expect(cmd.name == "web")
        #expect(cmd.description == "Search the web")
    }

    @Test("BridgeCommand decodes without description")
    func bridgeCommandMinimal() throws {
        let json = #"{"name":"help"}"#
        let cmd = try JSONDecoder().decode(BridgeCommand.self, from: Data(json.utf8))
        #expect(cmd.name == "help")
        #expect(cmd.description == nil)
    }

    @Test("BridgeCommand round-trips correctly")
    func bridgeCommandRoundTrip() throws {
        let original = BridgeCommand(name: "test", description: "Run tests")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BridgeCommand.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - BridgeStats

    @Test("BridgeStats decodes correctly")
    func bridgeStatsDecode() throws {
        let json = """
        {
            "total_sessions": 100,
            "active_sessions": 3,
            "idle_sessions": 97,
            "total_prompts": 500,
            "total_messages": 1200
        }
        """
        let stats = try JSONDecoder().decode(BridgeStats.self, from: Data(json.utf8))
        #expect(stats.totalSessions == 100)
        #expect(stats.activeSessions == 3)
        #expect(stats.idleSessions == 97)
        #expect(stats.totalPrompts == 500)
        #expect(stats.totalMessages == 1200)
    }

    @Test("BridgeStats round-trips correctly")
    func bridgeStatsRoundTrip() throws {
        let original = BridgeStats(
            totalSessions: 50,
            activeSessions: 2,
            idleSessions: 48,
            totalPrompts: 200,
            totalMessages: 600
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BridgeStats.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - HistorySession

    @Test("HistorySession decodes with all optional fields")
    func historySessionDecode() throws {
        let json = """
        {
            "id": "hs_001",
            "cwd": "/Users/dev/project",
            "repository": "acme/app",
            "branch": "main",
            "summary": "Implemented auth flow",
            "preview": "Added login and signup...",
            "created_at": "2025-01-15T10:00:00Z",
            "updated_at": "2025-01-15T11:00:00Z",
            "turn_count": 15
        }
        """
        let session = try JSONDecoder().decode(HistorySession.self, from: Data(json.utf8))
        #expect(session.id == "hs_001")
        #expect(session.cwd == "/Users/dev/project")
        #expect(session.repository == "acme/app")
        #expect(session.branch == "main")
        #expect(session.summary == "Implemented auth flow")
        #expect(session.preview == "Added login and signup...")
        #expect(session.createdAt == "2025-01-15T10:00:00Z")
        #expect(session.updatedAt == "2025-01-15T11:00:00Z")
        #expect(session.turnCount == 15)
    }

    @Test("HistorySession decodes with minimal fields")
    func historySessionMinimal() throws {
        let json = #"{"id":"hs_002"}"#
        let session = try JSONDecoder().decode(HistorySession.self, from: Data(json.utf8))
        #expect(session.id == "hs_002")
        #expect(session.cwd == nil)
        #expect(session.repository == nil)
        #expect(session.branch == nil)
        #expect(session.summary == nil)
        #expect(session.preview == nil)
        #expect(session.createdAt == nil)
        #expect(session.updatedAt == nil)
        #expect(session.turnCount == nil)
    }

    @Test("HistorySession round-trips correctly")
    func historySessionRoundTrip() throws {
        let original = HistorySession(
            id: "hs_rt",
            cwd: "/tmp",
            repository: "test/repo",
            branch: "dev",
            summary: "Test",
            preview: "Preview text",
            createdAt: "2025-01-01",
            updatedAt: "2025-01-02",
            turnCount: 5
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HistorySession.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - HistoryTurn

    @Test("HistoryTurn decodes correctly")
    func historyTurnDecode() throws {
        let json = """
        {
            "turn_index": 3,
            "user_message": "Fix the bug in auth.swift",
            "assistant_response": "I found the issue in the token validation...",
            "timestamp": "2025-01-15T10:05:00Z"
        }
        """
        let turn = try JSONDecoder().decode(HistoryTurn.self, from: Data(json.utf8))
        #expect(turn.turnIndex == 3)
        #expect(turn.userMessage == "Fix the bug in auth.swift")
        #expect(turn.assistantResponse == "I found the issue in the token validation...")
        #expect(turn.timestamp == "2025-01-15T10:05:00Z")
    }

    @Test("HistoryTurn decodes with minimal fields")
    func historyTurnMinimal() throws {
        let json = #"{"turn_index":0}"#
        let turn = try JSONDecoder().decode(HistoryTurn.self, from: Data(json.utf8))
        #expect(turn.turnIndex == 0)
        #expect(turn.userMessage == nil)
        #expect(turn.assistantResponse == nil)
        #expect(turn.timestamp == nil)
    }

    @Test("HistoryTurn round-trips correctly")
    func historyTurnRoundTrip() throws {
        let original = HistoryTurn(
            turnIndex: 7,
            userMessage: "Hello",
            assistantResponse: "Hi there!",
            timestamp: "2025-03-01T12:00:00Z"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HistoryTurn.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - HistoryStats

    @Test("HistoryStats decodes comprehensive stats")
    func historyStatsDecode() throws {
        let json = """
        {
            "total_sessions": 200,
            "total_turns": 1500,
            "total_repositories": 12,
            "total_files_edited": 450,
            "sessions_today": 5,
            "sessions_this_week": 20,
            "sessions_this_month": 60,
            "turns_today": 35,
            "turns_this_week": 140,
            "turns_this_month": 500,
            "sessions_by_day": [
                {"date": "2025-01-15", "count": 5},
                {"date": "2025-01-14", "count": 3}
            ],
            "sessions_by_month": [
                {"month": "2025-01", "count": 60}
            ],
            "turns_by_day": [
                {"date": "2025-01-15", "count": 35}
            ],
            "top_repositories": [
                {"repository": "acme/app", "count": 80},
                {"repository": "acme/lib", "count": 40}
            ],
            "top_branches": [
                {"branch": "main", "count": 100},
                {"branch": "develop", "count": 50}
            ],
            "active_hours": [
                {"hour": 9, "count": 30},
                {"hour": 14, "count": 45}
            ],
            "tools_used": [
                {"tool": "bash", "count": 200},
                {"tool": "read_file", "count": 150}
            ],
            "recent_sessions": [
                {"id": "rs_001", "summary": "Auth refactor", "created_at": "2025-01-15T10:00:00Z", "turn_count": 8}
            ],
            "average_turns_per_session": 7.5,
            "average_session_duration": 1800.0,
            "earliest_session": "2024-06-01T08:00:00Z",
            "latest_session": "2025-01-15T11:30:00Z"
        }
        """
        let stats = try JSONDecoder().decode(HistoryStats.self, from: Data(json.utf8))
        #expect(stats.totalSessions == 200)
        #expect(stats.totalTurns == 1500)
        #expect(stats.totalRepositories == 12)
        #expect(stats.totalFilesEdited == 450)
        #expect(stats.sessionsToday == 5)
        #expect(stats.sessionsThisWeek == 20)
        #expect(stats.sessionsThisMonth == 60)
        #expect(stats.turnsToday == 35)
        #expect(stats.turnsThisWeek == 140)
        #expect(stats.turnsThisMonth == 500)

        // Nested arrays
        #expect(stats.sessionsByDay?.count == 2)
        #expect(stats.sessionsByDay?[0].date == "2025-01-15")
        #expect(stats.sessionsByDay?[0].count == 5)

        #expect(stats.sessionsByMonth?.count == 1)
        #expect(stats.sessionsByMonth?[0].month == "2025-01")

        #expect(stats.turnsByDay?.count == 1)
        #expect(stats.turnsByDay?[0].count == 35)

        #expect(stats.topRepositories?.count == 2)
        #expect(stats.topRepositories?[0].repository == "acme/app")
        #expect(stats.topRepositories?[0].count == 80)

        #expect(stats.topBranches?.count == 2)
        #expect(stats.topBranches?[0].branch == "main")

        #expect(stats.activeHours?.count == 2)
        #expect(stats.activeHours?[0].hour == 9)
        #expect(stats.activeHours?[0].count == 30)

        #expect(stats.toolsUsed?.count == 2)
        #expect(stats.toolsUsed?[0].tool == "bash")

        #expect(stats.recentSessions?.count == 1)
        #expect(stats.recentSessions?[0].id == "rs_001")
        #expect(stats.recentSessions?[0].summary == "Auth refactor")
        #expect(stats.recentSessions?[0].turnCount == 8)

        #expect(stats.averageTurnsPerSession == 7.5)
        #expect(stats.averageSessionDuration == 1800.0)
        #expect(stats.earliestSession == "2024-06-01T08:00:00Z")
        #expect(stats.latestSession == "2025-01-15T11:30:00Z")
    }

    @Test("HistoryStats decodes with all nil fields")
    func historyStatsMinimal() throws {
        let json = #"{}"#
        let stats = try JSONDecoder().decode(HistoryStats.self, from: Data(json.utf8))
        #expect(stats.totalSessions == nil)
        #expect(stats.totalTurns == nil)
        #expect(stats.totalRepositories == nil)
        #expect(stats.sessionsByDay == nil)
        #expect(stats.topRepositories == nil)
        #expect(stats.activeHours == nil)
        #expect(stats.toolsUsed == nil)
        #expect(stats.recentSessions == nil)
        #expect(stats.averageTurnsPerSession == nil)
    }

    @Test("HistoryStats nested types round-trip")
    func historyStatsNestedRoundTrip() throws {
        let original = HistoryStats(
            totalSessions: 10,
            sessionsByDay: [
                HistoryStats.DayCount(date: "2025-01-15", count: 3)
            ],
            topRepositories: [
                HistoryStats.RepositoryStats(repository: "test/repo", count: 5)
            ],
            topBranches: [
                HistoryStats.BranchStats(branch: "main", count: 8)
            ],
            activeHours: [
                HistoryStats.HourCount(hour: 14, count: 20)
            ],
            toolsUsed: [
                HistoryStats.ToolUsage(tool: "bash", count: 50)
            ],
            recentSessions: [
                HistoryStats.RecentSession(id: "rs_rt", summary: "Test", createdAt: "2025-01-01", turnCount: 2)
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HistoryStats.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - v0.2.0 Handler Tests

@Suite("v0.2.0 Handler Tests")
struct V020HandlerTests {

    @Test("exitPlanMode handler receives request and sends response")
    func exitPlanModeHandler() async throws {
        let (clientTransport, serverTransport) = await InMemoryTransport.createPair()

        // Create client and register handler BEFORE connecting
        let client = ACPClient(name: "TestClient", version: "1.0")

        // Register the exit plan mode handler
        let handlerCalled = ManagedAtomic(false)
        await client.onExitPlanModeRequest { id, params in
            handlerCalled.store(true)
            #expect(params.summary == "Plan complete")
            #expect(params.actions?.count == 2)
            #expect(params.recommendedAction == "apply")
            return ExitPlanMode.Result(selectedAction: "apply", feedback: "Go ahead")
        }

        // Connect client (sends initialize, expects response)
        // We need to handle the initialize handshake on the server side
        try await clientTransport.connect()
        try await serverTransport.connect()

        // Set up server receive stream
        let serverStream = await serverTransport.receive()

        // Start connecting client in background — it will send initialize and wait for response
        let connectTask = Task {
            try await client.connect(transport: clientTransport)
        }

        // Server: receive the initialize request and respond
        var initializeRequestId: JSONRPCID?
        for try await data in serverStream {
            let json = String(data: data, encoding: .utf8) ?? ""
            if json.contains("initialize") && !json.contains("initialized") {
                // Parse the request ID
                let raw = try JSONDecoder().decode(RawMessage.self, from: data)
                initializeRequestId = raw.id
                // Send initialize response
                let response = """
                {"jsonrpc":"2.0","id":\(initializeRequestId!.jsonFragment),"result":{"protocolVersion":1,"agentInfo":{"name":"TestAgent","version":"1.0"},"agentCapabilities":{}}}
                """
                try await serverTransport.send(Data(response.utf8))
            } else if json.contains("initialized") {
                // Client sent initialized notification, handshake complete
                break
            }
        }

        // Wait for connect to complete
        _ = try await connectTask.value

        // Now server sends an exitPlanMode.request to the client
        let exitPlanRequest = """
        {"jsonrpc":"2.0","id":100,"method":"exitPlanMode.request","params":{"summary":"Plan complete","actions":[{"actionId":"apply","label":"Apply"},{"actionId":"reject","label":"Reject"}],"recommendedAction":"apply"}}
        """
        try await serverTransport.send(Data(exitPlanRequest.utf8))

        // Server: receive the client's response
        for try await data in serverStream {
            let json = String(data: data, encoding: .utf8) ?? ""
            if json.contains("selectedAction") {
                let response = try JSONDecoder().decode(JSONRPCResponse<ExitPlanMode.Result>.self, from: data)
                #expect(response.id == .int(100))
                #expect(response.result.selectedAction == "apply")
                #expect(response.result.feedback == "Go ahead")
                break
            }
        }

        #expect(handlerCalled.load())

        await client.disconnect()
    }

    @Test("elicitation handler receives request and sends response")
    func elicitationHandler() async throws {
        let (clientTransport, serverTransport) = await InMemoryTransport.createPair()

        let client = ACPClient(name: "TestClient", version: "1.0")

        // Register elicitation handler
        let handlerCalled = ManagedAtomic(false)
        await client.onElicitationRequest { id, params in
            handlerCalled.store(true)
            #expect(params.message == "Do you approve this change?")
            #expect(params.sessionId == "sess_test")
            return Elicitation.Result(action: .accept, content: .object(["approved": .bool(true)]))
        }

        try await clientTransport.connect()
        try await serverTransport.connect()

        let serverStream = await serverTransport.receive()

        // Connect with handshake
        let connectTask = Task {
            try await client.connect(transport: clientTransport)
        }

        for try await data in serverStream {
            let json = String(data: data, encoding: .utf8) ?? ""
            if json.contains("initialize") && !json.contains("initialized") {
                let raw = try JSONDecoder().decode(RawMessage.self, from: data)
                let response = """
                {"jsonrpc":"2.0","id":\(raw.id!.jsonFragment),"result":{"protocolVersion":1,"agentInfo":{"name":"TestAgent","version":"1.0"},"agentCapabilities":{}}}
                """
                try await serverTransport.send(Data(response.utf8))
            } else if json.contains("initialized") {
                break
            }
        }

        _ = try await connectTask.value

        // Server sends elicitation/create request
        let elicitationRequest = """
        {"jsonrpc":"2.0","id":200,"method":"elicitation/create","params":{"sessionId":"sess_test","message":"Do you approve this change?","requestedSchema":{"type":"object","properties":{"approved":{"type":"boolean"}}}}}
        """
        try await serverTransport.send(Data(elicitationRequest.utf8))

        // Server receives client's response
        for try await data in serverStream {
            let json = String(data: data, encoding: .utf8) ?? ""
            if json.contains("action") {
                let response = try JSONDecoder().decode(JSONRPCResponse<Elicitation.Result>.self, from: data)
                #expect(response.id == .int(200))
                #expect(response.result.action == .accept)
                #expect(response.result.content != nil)
                break
            }
        }

        #expect(handlerCalled.load())

        await client.disconnect()
    }
}

// MARK: - Thread-safe Atomic Bool for Handler Tests

/// A simple thread-safe atomic boolean for test synchronization.
/// Uses `os_unfair_lock` for correctness on Darwin platforms.
private final class ManagedAtomic: @unchecked Sendable {
    private var _value: Bool
    private let lock = NSLock()

    init(_ value: Bool) {
        self._value = value
    }

    func store(_ value: Bool) {
        lock.lock()
        _value = value
        lock.unlock()
    }

    func load() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}

// MARK: - JSONRPCID Helper

private extension JSONRPCID {
    /// Returns a JSON fragment string for this ID (e.g., `42` or `"abc"`).
    var jsonFragment: String {
        switch self {
        case .int(let v): return "\(v)"
        case .string(let v): return "\"\(v)\""
        }
    }
}
