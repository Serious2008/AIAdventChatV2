//
//  YandexTrackerTools.swift
//  AIAdventChatV2
//
//  Tool definitions for Yandex Tracker integration with Claude
//

import Foundation

/// Провайдер инструментов для Yandex Tracker
class YandexTrackerToolsProvider {

    /// Получить все доступные инструменты Yandex Tracker
    static func getTools() -> [ClaudeTool] {
        return [
            getStatsToolDefinition(),
            getIssuesToolDefinition(),
            getIssueToolDefinition()
        ]
    }

    // MARK: - Tool Definitions

    /// Инструмент для получения статистики по задачам
    private static func getStatsToolDefinition() -> ClaudeTool {
        return ClaudeTool(
            name: "get_yandex_tracker_stats",
            description: """
            Получить статистику по задачам из Yandex Tracker.
            Возвращает общее количество задач, количество открытых, в работе, закрытых задач,
            а также детальную статистику по каждому статусу.

            Используй этот инструмент когда пользователь спрашивает:
            - "Сколько задач?"
            - "Статистика по задачам"
            - "Сколько открытых/закрытых задач?"
            - "Много ли у меня работы?"
            - Любые вопросы о количестве или состоянии задач
            """,
            properties: [
                "filter": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: """
                    Опциональный фильтр для задач в формате Yandex Tracker Query Language.
                    Примеры:
                    - "assignee: me()" - только мои задачи
                    - "status: open" - только открытые
                    - "queue: PROJECT" - только из очереди PROJECT
                    Если не указан, вернется статистика по всем задачам.
                    """
                )
            ],
            required: nil  // filter опциональный
        )
    }

    /// Инструмент для получения списка задач
    private static func getIssuesToolDefinition() -> ClaudeTool {
        return ClaudeTool(
            name: "get_yandex_tracker_issues",
            description: """
            Получить список задач из Yandex Tracker.
            Возвращает детальную информацию о задачах: ключ, название, статус, исполнитель.

            Используй этот инструмент когда пользователь спрашивает:
            - "Покажи список задач"
            - "Какие задачи открыты?"
            - "Что у меня в работе?"
            - "Покажи задачи PROJECT"
            - Любые запросы о конкретных задачах (не просто статистика)
            """,
            properties: [
                "filter": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: """
                    Опциональный фильтр для задач.
                    Примеры: "assignee: me()", "status: open", "queue: PROJECT"
                    """
                ),
                "limit": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Максимальное количество задач (по умолчанию 50)"
                )
            ],
            required: nil  // все параметры опциональные
        )
    }

    /// Инструмент для получения конкретной задачи
    private static func getIssueToolDefinition() -> ClaudeTool {
        return ClaudeTool(
            name: "get_yandex_tracker_issue",
            description: """
            Получить подробную информацию о конкретной задаче из Yandex Tracker по её ключу.

            Используй этот инструмент когда пользователь:
            - Указывает конкретный ключ задачи (например: PROJECT-123)
            - Спрашивает "Что с задачей PROJECT-123?"
            - "Покажи задачу KEY-456"
            - Любые запросы о конкретной задаче с указанием ключа
            """,
            properties: [
                "issue_key": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Ключ задачи в формате QUEUE-NUMBER (например: PROJECT-123, TASK-456)"
                )
            ],
            required: ["issue_key"]
        )
    }

    // MARK: - Tool Execution

    /// Выполнить вызов инструмента
    static func executeTool(
        name: String,
        input: [String: Any],
        trackerService: YandexTrackerService
    ) async throws -> String {
        switch name {
        case "get_yandex_tracker_stats":
            return try await executeGetStats(input: input, trackerService: trackerService)

        case "get_yandex_tracker_issues":
            return try await executeGetIssues(input: input, trackerService: trackerService)

        case "get_yandex_tracker_issue":
            return try await executeGetIssue(input: input, trackerService: trackerService)

        default:
            throw NSError(
                domain: "YandexTrackerToolsProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(name)"]
            )
        }
    }

    // MARK: - Tool Implementations

    private static func executeGetStats(
        input: [String: Any],
        trackerService: YandexTrackerService
    ) async throws -> String {
        let filter = input["filter"] as? String

        let stats = try await trackerService.getIssueStats(filter: filter)

        // Форматируем результат в JSON для Claude
        let result: [String: Any] = [
            "total": stats.total,
            "open": stats.open,
            "in_progress": stats.inProgress,
            "closed": stats.closed,
            "by_status": stats.byStatus
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    private static func executeGetIssues(
        input: [String: Any],
        trackerService: YandexTrackerService
    ) async throws -> String {
        let filter = input["filter"] as? String
        let limitString = input["limit"] as? String
        let limit = Int(limitString ?? "50") ?? 50

        do {
            let issues = try await trackerService.getIssues(filter: filter, limit: limit)

            // Форматируем результат
            let issuesData = issues.map { issue in
                return [
                    "key": issue.key,
                    "summary": issue.summary,
                    "status": issue.status.display,
                    "assignee": issue.assignee?.display ?? "Unassigned"
                ]
            }

            let result: [String: Any] = [
                "count": issues.count,
                "issues": issuesData
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"

        } catch {
            // getIssues возвращает пустой массив, так как парсинг не реализован
            // Возвращаем информацию об ошибке
            return """
            {
                "error": "Issue list parsing not fully implemented yet",
                "message": "The MCP server returns issues but parsing is incomplete. Use get_yandex_tracker_stats instead for now."
            }
            """
        }
    }

    private static func executeGetIssue(
        input: [String: Any],
        trackerService: YandexTrackerService
    ) async throws -> String {
        guard let issueKey = input["issue_key"] as? String else {
            throw NSError(
                domain: "YandexTrackerToolsProvider",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Missing required parameter: issue_key"]
            )
        }

        do {
            let issue = try await trackerService.getIssue(key: issueKey)

            let result: [String: Any] = [
                "key": issue.key,
                "summary": issue.summary,
                "status": issue.status.display,
                "assignee": issue.assignee?.display ?? "Unassigned"
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"

        } catch {
            // getIssue не реализован полностью
            return """
            {
                "error": "Issue detail parsing not fully implemented yet",
                "message": "\(error.localizedDescription)"
            }
            """
        }
    }
}
