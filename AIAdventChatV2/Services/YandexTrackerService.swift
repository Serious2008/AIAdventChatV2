//
//  YandexTrackerService.swift
//  AIAdventChatV2
//
//  MCP-based service for Yandex Tracker integration
//

import Foundation
import MCP

// MARK: - Data Models

struct YandexTrackerIssue: Codable {
    let key: String
    let summary: String
    let status: IssueStatus
    let assignee: Assignee?
    let createdAt: String
    let updatedAt: String

    struct IssueStatus: Codable {
        let key: String
        let display: String
    }

    struct Assignee: Codable {
        let display: String
    }
}

struct YandexTrackerStats: Codable {
    let total: Int
    let open: Int
    let inProgress: Int
    let closed: Int
    let byStatus: [String: Int]
}

// MARK: - Yandex Tracker Service

class YandexTrackerService: ObservableObject {
    @Published var isConnected = false
    @Published var errorMessage: String?

    private var mcpService: MCPService
    private var orgId: String?
    private var token: String?

    init() {
        self.mcpService = MCPService()
    }

    // MARK: - Configuration

    /// Конфигурация Yandex Tracker с учетными данными
    func configure(orgId: String, token: String) async throws {
        self.orgId = orgId
        self.token = token

        // Подключаемся к MCP серверу Yandex Tracker
        let projectPath = FileManager.default.currentDirectoryPath
        let serverPath = "\(projectPath)/mcp-yandex-tracker/build/index.js"

        let command = ["node", serverPath]

        try await mcpService.connect(serverCommand: command)

        // Вызываем инструмент configure
        let configArgs: [String: Value] = [
            "orgId": .string(orgId),
            "token": .string(token)
        ]

        let result = try await mcpService.callTool(
            name: "configure",
            arguments: configArgs
        )

        if result.isError {
            let errorText = extractTextFromContent(result.content)
            throw NSError(
                domain: "YandexTrackerService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to configure: \(errorText)"]
            )
        }

        DispatchQueue.main.async {
            self.isConnected = true
            self.errorMessage = nil
        }
    }

    // MARK: - Issues

    /// Получить список задач по фильтру
    func getIssues(filter: String? = nil, limit: Int = 50) async throws -> [YandexTrackerIssue] {
        guard isConnected else {
            throw NSError(
                domain: "YandexTrackerService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Not connected. Call configure() first."]
            )
        }

        var args: [String: Value] = [
            "limit": .int(limit)
        ]

        if let filter = filter {
            args["filter"] = .string(filter)
        }

        let result = try await mcpService.callTool(
            name: "get_issues",
            arguments: args
        )

        if result.isError {
            let errorText = extractTextFromContent(result.content)
            throw NSError(
                domain: "YandexTrackerService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get issues: \(errorText)"]
            )
        }

        // Парсим результат (MCP возвращает текст с описанием задач)
        // Для простоты возвращаем пустой массив, так как нужна более сложная парсинг логика
        return []
    }

    /// Получить статистику по задачам
    func getIssueStats(filter: String? = nil) async throws -> YandexTrackerStats {
        guard isConnected else {
            throw NSError(
                domain: "YandexTrackerService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Not connected. Call configure() first."]
            )
        }

        var args: [String: Value] = [:]

        if let filter = filter {
            args["filter"] = .string(filter)
        }

        let result = try await mcpService.callTool(
            name: "get_issue_stats",
            arguments: args
        )

        if result.isError {
            let errorText = extractTextFromContent(result.content)
            throw NSError(
                domain: "YandexTrackerService",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get stats: \(errorText)"]
            )
        }

        // Парсим результат из текста
        // MCP возвращает текст вида:
        // 📊 Issue Statistics:
        // Total: 42
        // Open: 10
        // In Progress: 15
        // Closed: 17

        let text = extractTextFromContent(result.content)
        if text.isEmpty {
            throw NSError(
                domain: "YandexTrackerService",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "No content in response"]
            )
        }

        return try parseStatsFromText(text)
    }

    /// Получить конкретную задачу
    func getIssue(key: String) async throws -> YandexTrackerIssue {
        guard isConnected else {
            throw NSError(
                domain: "YandexTrackerService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Not connected. Call configure() first."]
            )
        }

        let args: [String: Value] = [
            "issueKey": .string(key)
        ]

        let result = try await mcpService.callTool(
            name: "get_issue",
            arguments: args
        )

        if result.isError {
            let errorText = extractTextFromContent(result.content)
            throw NSError(
                domain: "YandexTrackerService",
                code: -6,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get issue: \(errorText)"]
            )
        }

        // Простая заглушка, так как нужна сложная логика парсинга
        throw NSError(
            domain: "YandexTrackerService",
            code: -7,
            userInfo: [NSLocalizedDescriptionKey: "Issue parsing not implemented"]
        )
    }

    /// Получить мои задачи
    func getMyIssues() async throws -> [YandexTrackerIssue] {
        guard isConnected else {
            throw NSError(
                domain: "YandexTrackerService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Not connected. Call configure() first."]
            )
        }

        let result = try await mcpService.callTool(
            name: "get_my_issues",
            arguments: nil
        )

        if result.isError {
            let errorText = extractTextFromContent(result.content)
            throw NSError(
                domain: "YandexTrackerService",
                code: -8,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get my issues: \(errorText)"]
            )
        }

        return []
    }

    // MARK: - Parsing Helpers

    /// Извлечь текст из MCP Content
    private func extractTextFromContent(_ content: [MCP.Tool.Content]) -> String {
        var result = ""
        for item in content {
            switch item {
            case .text(let text):
                result += text
            case .image(_, _, _):
                result += "[Image]"
            case .audio(_, _):
                result += "[Audio]"
            case .resource(let uri, _, _):
                result += "[Resource: \(uri)]"
            }
        }
        return result.isEmpty ? "Unknown error" : result
    }

    private func parseStatsFromText(_ text: String) throws -> YandexTrackerStats {
        var total = 0
        var open = 0
        var inProgress = 0
        var closed = 0
        var byStatus: [String: Int] = [:]

        // Парсим строки вида "Total: 42"
        let lines = text.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Total:") {
                if let value = extractNumber(from: trimmed) {
                    total = value
                }
            } else if trimmed.hasPrefix("Open:") {
                if let value = extractNumber(from: trimmed) {
                    open = value
                }
            } else if trimmed.hasPrefix("In Progress:") {
                if let value = extractNumber(from: trimmed) {
                    inProgress = value
                }
            } else if trimmed.hasPrefix("Closed:") {
                if let value = extractNumber(from: trimmed) {
                    closed = value
                }
            } else if trimmed.contains(":") && trimmed.hasPrefix("•") {
                // Парсим строки вида "  • Open: 10"
                let parts = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
                if parts.count == 2 {
                    let status = parts[0].trimmingCharacters(in: .whitespaces)
                    if let count = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                        byStatus[status] = count
                    }
                }
            }
        }

        return YandexTrackerStats(
            total: total,
            open: open,
            inProgress: inProgress,
            closed: closed,
            byStatus: byStatus
        )
    }

    private func extractNumber(from line: String) -> Int? {
        let components = line.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }

        let numberString = components[1].trimmingCharacters(in: .whitespaces)
        return Int(numberString)
    }

    // MARK: - Agent Integration

    /// Метод для вызова из агента - получить количество открытых задач
    func getOpenTasksCount(filter: String? = nil) async throws -> String {
        let stats = try await getIssueStats(filter: filter)

        let summary = """
        📊 Статистика задач Yandex Tracker:

        Всего задач: \(stats.total)
        Открытых: \(stats.open)
        В работе: \(stats.inProgress)
        Закрытых: \(stats.closed)

        Подробная статистика по статусам:
        \(stats.byStatus.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))
        """

        return summary
    }

    /// Метод для агента - получить краткую информацию о задачах
    func getTasksSummary(filter: String? = nil) async throws -> String {
        let stats = try await getIssueStats(filter: filter)

        return "В Yandex Tracker найдено: \(stats.total) задач (открыто: \(stats.open), в работе: \(stats.inProgress), закрыто: \(stats.closed))"
    }
}
