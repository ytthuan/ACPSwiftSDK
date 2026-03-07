import Foundation

// MARK: - Health

/// Response from `GET /health`.
public struct BridgeHealth: Codable, Hashable, Sendable {
    public let status: String
    public let version: String
    public let copilotCliVersion: String?
    public let uptimeSecs: Int

    private enum CodingKeys: String, CodingKey {
        case status, version
        case copilotCliVersion = "copilot_cli_version"
        case uptimeSecs = "uptime_secs"
    }

    public init(
        status: String,
        version: String,
        copilotCliVersion: String? = nil,
        uptimeSecs: Int
    ) {
        self.status = status
        self.version = version
        self.copilotCliVersion = copilotCliVersion
        self.uptimeSecs = uptimeSecs
    }
}

// MARK: - Copilot Info

/// Response from `GET /api/copilot/info`.
public struct CopilotInfo: Codable, Hashable, Sendable {
    public let version: String
    public let path: String?
    public let mode: String?
    public let ga: Bool?
    public let features: [String]?

    public init(
        version: String,
        path: String? = nil,
        mode: String? = nil,
        ga: Bool? = nil,
        features: [String]? = nil
    ) {
        self.version = version
        self.path = path
        self.mode = mode
        self.ga = ga
        self.features = features
    }
}

// MARK: - Copilot Usage

/// Response from `GET /api/copilot/usage`.
public struct CopilotUsage: Codable, Hashable, Sendable {
    public let totalSessions: Int
    public let totalTurns: Int
    public let totalFilesEdited: Int
    public let modelUsage: [ModelUsageEntry]?
    public let sessionsByMonth: [MonthlySessionEntry]?
    public let totalToolExecutions: Int?
    public let eventTypeCounts: [String: Int]?

    private enum CodingKeys: String, CodingKey {
        case totalSessions, totalTurns, totalFilesEdited
        case modelUsage, sessionsByMonth
        case totalToolExecutions, eventTypeCounts
    }

    public init(
        totalSessions: Int,
        totalTurns: Int,
        totalFilesEdited: Int,
        modelUsage: [ModelUsageEntry]? = nil,
        sessionsByMonth: [MonthlySessionEntry]? = nil,
        totalToolExecutions: Int? = nil,
        eventTypeCounts: [String: Int]? = nil
    ) {
        self.totalSessions = totalSessions
        self.totalTurns = totalTurns
        self.totalFilesEdited = totalFilesEdited
        self.modelUsage = modelUsage
        self.sessionsByMonth = sessionsByMonth
        self.totalToolExecutions = totalToolExecutions
        self.eventTypeCounts = eventTypeCounts
    }

    /// A single model usage entry within `CopilotUsage`.
    public struct ModelUsageEntry: Codable, Hashable, Sendable {
        public let model: String
        public let count: Int

        public init(model: String, count: Int) {
            self.model = model
            self.count = count
        }
    }

    /// A monthly session summary within `CopilotUsage`.
    public struct MonthlySessionEntry: Codable, Hashable, Sendable {
        public let month: String
        public let sessions: Int
        public let turns: Int

        public init(month: String, sessions: Int, turns: Int) {
            self.month = month
            self.sessions = sessions
            self.turns = turns
        }
    }
}

// MARK: - Bridge Session

/// Response element from `GET /api/sessions` and `GET /api/sessions/:id`.
public struct BridgeSession: Codable, Hashable, Sendable {
    public let id: String
    public let copilotSessionId: String?
    public let status: String
    public let createdAt: String?
    public let lastActivity: String?
    public let promptCount: Int?
    public let messageCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, status
        case copilotSessionId = "copilot_session_id"
        case createdAt = "created_at"
        case lastActivity = "last_activity"
        case promptCount = "prompt_count"
        case messageCount = "message_count"
    }

    public init(
        id: String,
        copilotSessionId: String? = nil,
        status: String,
        createdAt: String? = nil,
        lastActivity: String? = nil,
        promptCount: Int? = nil,
        messageCount: Int? = nil
    ) {
        self.id = id
        self.copilotSessionId = copilotSessionId
        self.status = status
        self.createdAt = createdAt
        self.lastActivity = lastActivity
        self.promptCount = promptCount
        self.messageCount = messageCount
    }
}

// MARK: - Bridge Command

/// Response element from `GET /api/sessions/:id/commands`.
public struct BridgeCommand: Codable, Hashable, Sendable {
    public let name: String
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

// MARK: - Bridge Stats

/// Response from `GET /api/stats`.
public struct BridgeStats: Codable, Hashable, Sendable {
    public let totalSessions: Int
    public let activeSessions: Int
    public let idleSessions: Int
    public let totalPrompts: Int
    public let totalMessages: Int

    private enum CodingKeys: String, CodingKey {
        case totalSessions = "total_sessions"
        case activeSessions = "active_sessions"
        case idleSessions = "idle_sessions"
        case totalPrompts = "total_prompts"
        case totalMessages = "total_messages"
    }

    public init(
        totalSessions: Int,
        activeSessions: Int,
        idleSessions: Int,
        totalPrompts: Int,
        totalMessages: Int
    ) {
        self.totalSessions = totalSessions
        self.activeSessions = activeSessions
        self.idleSessions = idleSessions
        self.totalPrompts = totalPrompts
        self.totalMessages = totalMessages
    }
}

// MARK: - History Session

/// Response element from `GET /api/history/sessions`.
public struct HistorySession: Codable, Hashable, Sendable {
    public let id: String
    public let cwd: String?
    public let repository: String?
    public let branch: String?
    public let summary: String?
    public let preview: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let turnCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, cwd, repository, branch, summary, preview
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case turnCount = "turn_count"
    }

    public init(
        id: String,
        cwd: String? = nil,
        repository: String? = nil,
        branch: String? = nil,
        summary: String? = nil,
        preview: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        turnCount: Int? = nil
    ) {
        self.id = id
        self.cwd = cwd
        self.repository = repository
        self.branch = branch
        self.summary = summary
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.turnCount = turnCount
    }
}

// MARK: - History Turn

/// Response element from `GET /api/history/sessions/:id/turns`.
public struct HistoryTurn: Codable, Hashable, Sendable {
    public let turnIndex: Int
    public let userMessage: String?
    public let assistantResponse: String?
    public let timestamp: String?

    private enum CodingKeys: String, CodingKey {
        case turnIndex = "turn_index"
        case userMessage = "user_message"
        case assistantResponse = "assistant_response"
        case timestamp
    }

    public init(
        turnIndex: Int,
        userMessage: String? = nil,
        assistantResponse: String? = nil,
        timestamp: String? = nil
    ) {
        self.turnIndex = turnIndex
        self.userMessage = userMessage
        self.assistantResponse = assistantResponse
        self.timestamp = timestamp
    }
}

// MARK: - History Stats

/// Response from `GET /api/history/stats`.
public struct HistoryStats: Codable, Hashable, Sendable {
    public let totalSessions: Int?
    public let totalTurns: Int?
    public let totalRepositories: Int?
    public let totalFilesEdited: Int?
    public let sessionsToday: Int?
    public let sessionsThisWeek: Int?
    public let sessionsThisMonth: Int?
    public let turnsToday: Int?
    public let turnsThisWeek: Int?
    public let turnsThisMonth: Int?
    public let sessionsByDay: [DayCount]?
    public let sessionsByMonth: [MonthCount]?
    public let turnsByDay: [DayCount]?
    public let topRepositories: [RepositoryStats]?
    public let topBranches: [BranchStats]?
    public let activeHours: [HourCount]?
    public let toolsUsed: [ToolUsage]?
    public let recentSessions: [RecentSession]?
    public let averageTurnsPerSession: Double?
    public let averageSessionDuration: Double?
    public let earliestSession: String?
    public let latestSession: String?

    private enum CodingKeys: String, CodingKey {
        case totalSessions = "total_sessions"
        case totalTurns = "total_turns"
        case totalRepositories = "total_repositories"
        case totalFilesEdited = "total_files_edited"
        case sessionsToday = "sessions_today"
        case sessionsThisWeek = "sessions_this_week"
        case sessionsThisMonth = "sessions_this_month"
        case turnsToday = "turns_today"
        case turnsThisWeek = "turns_this_week"
        case turnsThisMonth = "turns_this_month"
        case sessionsByDay = "sessions_by_day"
        case sessionsByMonth = "sessions_by_month"
        case turnsByDay = "turns_by_day"
        case topRepositories = "top_repositories"
        case topBranches = "top_branches"
        case activeHours = "active_hours"
        case toolsUsed = "tools_used"
        case recentSessions = "recent_sessions"
        case averageTurnsPerSession = "average_turns_per_session"
        case averageSessionDuration = "average_session_duration"
        case earliestSession = "earliest_session"
        case latestSession = "latest_session"
    }

    public init(
        totalSessions: Int? = nil,
        totalTurns: Int? = nil,
        totalRepositories: Int? = nil,
        totalFilesEdited: Int? = nil,
        sessionsToday: Int? = nil,
        sessionsThisWeek: Int? = nil,
        sessionsThisMonth: Int? = nil,
        turnsToday: Int? = nil,
        turnsThisWeek: Int? = nil,
        turnsThisMonth: Int? = nil,
        sessionsByDay: [DayCount]? = nil,
        sessionsByMonth: [MonthCount]? = nil,
        turnsByDay: [DayCount]? = nil,
        topRepositories: [RepositoryStats]? = nil,
        topBranches: [BranchStats]? = nil,
        activeHours: [HourCount]? = nil,
        toolsUsed: [ToolUsage]? = nil,
        recentSessions: [RecentSession]? = nil,
        averageTurnsPerSession: Double? = nil,
        averageSessionDuration: Double? = nil,
        earliestSession: String? = nil,
        latestSession: String? = nil
    ) {
        self.totalSessions = totalSessions
        self.totalTurns = totalTurns
        self.totalRepositories = totalRepositories
        self.totalFilesEdited = totalFilesEdited
        self.sessionsToday = sessionsToday
        self.sessionsThisWeek = sessionsThisWeek
        self.sessionsThisMonth = sessionsThisMonth
        self.turnsToday = turnsToday
        self.turnsThisWeek = turnsThisWeek
        self.turnsThisMonth = turnsThisMonth
        self.sessionsByDay = sessionsByDay
        self.sessionsByMonth = sessionsByMonth
        self.turnsByDay = turnsByDay
        self.topRepositories = topRepositories
        self.topBranches = topBranches
        self.activeHours = activeHours
        self.toolsUsed = toolsUsed
        self.recentSessions = recentSessions
        self.averageTurnsPerSession = averageTurnsPerSession
        self.averageSessionDuration = averageSessionDuration
        self.earliestSession = earliestSession
        self.latestSession = latestSession
    }

    // MARK: - Nested Types

    /// Count of sessions or turns for a single day.
    public struct DayCount: Codable, Hashable, Sendable {
        public let date: String
        public let count: Int

        public init(date: String, count: Int) {
            self.date = date
            self.count = count
        }
    }

    /// Count of sessions for a single month.
    public struct MonthCount: Codable, Hashable, Sendable {
        public let month: String
        public let count: Int

        public init(month: String, count: Int) {
            self.month = month
            self.count = count
        }
    }

    /// Repository usage statistics.
    public struct RepositoryStats: Codable, Hashable, Sendable {
        public let repository: String
        public let count: Int

        public init(repository: String, count: Int) {
            self.repository = repository
            self.count = count
        }
    }

    /// Branch usage statistics.
    public struct BranchStats: Codable, Hashable, Sendable {
        public let branch: String
        public let count: Int

        public init(branch: String, count: Int) {
            self.branch = branch
            self.count = count
        }
    }

    /// Activity count for a specific hour of the day.
    public struct HourCount: Codable, Hashable, Sendable {
        public let hour: Int
        public let count: Int

        public init(hour: Int, count: Int) {
            self.hour = hour
            self.count = count
        }
    }

    /// Tool usage statistics.
    public struct ToolUsage: Codable, Hashable, Sendable {
        public let tool: String
        public let count: Int

        public init(tool: String, count: Int) {
            self.tool = tool
            self.count = count
        }
    }

    /// A recent session summary within history stats.
    public struct RecentSession: Codable, Hashable, Sendable {
        public let id: String
        public let summary: String?
        public let createdAt: String?
        public let turnCount: Int?

        private enum CodingKeys: String, CodingKey {
            case id, summary
            case createdAt = "created_at"
            case turnCount = "turn_count"
        }

        public init(
            id: String,
            summary: String? = nil,
            createdAt: String? = nil,
            turnCount: Int? = nil
        ) {
            self.id = id
            self.summary = summary
            self.createdAt = createdAt
            self.turnCount = turnCount
        }
    }
}
