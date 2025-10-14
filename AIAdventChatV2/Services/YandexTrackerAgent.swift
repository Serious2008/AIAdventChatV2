//
//  YandexTrackerAgent.swift
//  AIAdventChatV2
//
//  Agent wrapper for Yandex Tracker MCP integration
//

import Foundation

// MARK: - Yandex Tracker Agent

/// Агент для работы с Yandex Tracker через MCP
/// Интегрируется с MultiAgentService и позволяет агентам вызывать инструменты Yandex Tracker
class YandexTrackerAgent {

    private let trackerService: YandexTrackerService
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
        self.trackerService = YandexTrackerService()
    }

    // MARK: - Configuration

    /// Конфигурация агента с учетными данными Yandex Tracker
    func configure(orgId: String, token: String) async throws {
        try await trackerService.configure(orgId: orgId, token: token)
    }

    // MARK: - Agent Task Execution

    /// Выполнить задачу агента с использованием Yandex Tracker
    func executeTask(task: String) async throws -> String {
        // Анализируем задачу и определяем, что нужно сделать
        let intent = analyzeTaskIntent(task)

        switch intent {
        case .getStats:
            return try await handleGetStatsTask(task)
        case .getOpenTasks:
            return try await handleGetOpenTasksTask(task)
        case .getTaskInfo:
            return try await handleGetTaskInfoTask(task)
        case .unknown:
            return "Не удалось определить, что нужно сделать с Yandex Tracker. Попробуйте переформулировать запрос."
        }
    }

    // MARK: - Task Intent Analysis

    private enum TaskIntent {
        case getStats           // Получить статистику
        case getOpenTasks       // Получить открытые задачи
        case getTaskInfo        // Получить информацию о задаче
        case unknown
    }

    private func analyzeTaskIntent(_ task: String) -> TaskIntent {
        let lowercased = task.lowercased()

        // Ключевые слова для определения намерения
        if lowercased.contains("статистик") || lowercased.contains("количество") || lowercased.contains("сколько") {
            return .getStats
        }

        if lowercased.contains("открыт") || lowercased.contains("таск") {
            if lowercased.contains("список") || lowercased.contains("покажи") {
                return .getOpenTasks
            }
            return .getStats
        }

        if lowercased.contains("задач") && (lowercased.contains("информац") || lowercased.contains("деталь")) {
            return .getTaskInfo
        }

        return .unknown
    }

    // MARK: - Task Handlers

    private func handleGetStatsTask(_ task: String) async throws -> String {
        // Извлекаем фильтр из задачи, если есть
        let filter = extractFilter(from: task)

        let stats = try await trackerService.getIssueStats(filter: filter)

        let response = """
        🎯 Результат анализа Yandex Tracker:

        📊 Общая статистика:
        • Всего задач: \(stats.total)
        • Открытых: \(stats.open)
        • В работе: \(stats.inProgress)
        • Закрытых: \(stats.closed)

        📈 Детальная статистика по статусам:
        \(stats.byStatus.sorted { $0.value > $1.value }.map { "  • \($0.key): \($0.value)" }.joined(separator: "\n"))
        """

        return response
    }

    private func handleGetOpenTasksTask(_ task: String) async throws -> String {
        let filter = extractFilter(from: task)
        let summary = try await trackerService.getTasksSummary(filter: filter)

        return """
        🔍 Анализ открытых задач:

        \(summary)

        Используйте фильтры для более детального анализа.
        """
    }

    private func handleGetTaskInfoTask(_ task: String) async throws -> String {
        // Пытаемся извлечь ключ задачи из запроса
        let issueKey = extractIssueKey(from: task)

        if let key = issueKey {
            do {
                let issue = try await trackerService.getIssue(key: key)
                return """
                📋 Информация о задаче \(issue.key):

                Название: \(issue.summary)
                Статус: \(issue.status.display)
                Исполнитель: \(issue.assignee?.display ?? "Не назначен")
                """
            } catch {
                return "❌ Не удалось получить информацию о задаче \(key): \(error.localizedDescription)"
            }
        } else {
            return "❌ Не удалось определить ключ задачи. Пожалуйста, укажите ключ в формате PROJECT-123"
        }
    }

    // MARK: - Parsing Helpers

    private func extractFilter(from task: String) -> String? {
        // Простая логика извлечения фильтра
        // В будущем можно добавить более сложный парсинг
        let lowercased = task.lowercased()

        if lowercased.contains("assignee: me") || lowercased.contains("мои") {
            return "assignee: me()"
        }

        if lowercased.contains("status: open") || lowercased.contains("открыт") {
            return "status: open"
        }

        return nil
    }

    private func extractIssueKey(from task: String) -> String? {
        // Ищем паттерн PROJECT-123
        let pattern = "[A-Z]+-\\d+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(task.startIndex..<task.endIndex, in: task)
        if let match = regex.firstMatch(in: task, range: range) {
            if let matchRange = Range(match.range, in: task) {
                return String(task[matchRange])
            }
        }

        return nil
    }

    // MARK: - Agent Integration with Claude

    /// Выполнить задачу с помощью агента Claude, который может использовать Yandex Tracker
    func executeTaskWithAgent(task: String) async throws -> String {
        // 1. Анализируем задачу
        let intent = analyzeTaskIntent(task)

        // 2. Если задача связана с Yandex Tracker, выполняем её
        if intent != .unknown {
            let result = try await executeTask(task: task)
            return result
        }

        // 3. Если не связана, возвращаем сообщение
        return "Эта задача не связана с Yandex Tracker. Пожалуйста, используйте другой агент."
    }

    // MARK: - Tool Description for Agent

    /// Описание инструментов для агента (можно использовать в промпте)
    static func getToolsDescription() -> String {
        return """
        Доступные инструменты для работы с Yandex Tracker:

        1. **get_stats** - Получить статистику по задачам
           - Параметры: filter (опционально)
           - Пример: "Получи статистику по всем задачам"
           - Пример: "Сколько открытых задач?"

        2. **get_open_tasks** - Получить список открытых задач
           - Параметры: filter (опционально)
           - Пример: "Покажи все открытые задачи"
           - Пример: "Какие задачи в работе?"

        3. **get_task_info** - Получить информацию о конкретной задаче
           - Параметры: issueKey (обязательно)
           - Пример: "Покажи информацию о задаче PROJECT-123"

        Используй эти инструменты для выполнения задач пользователя, связанных с Yandex Tracker.
        """
    }
}

// MARK: - Agent Factory

/// Фабрика для создания агентов с MCP инструментами
class AgentFactory {

    /// Создать агента для Yandex Tracker
    static func createYandexTrackerAgent(apiKey: String, orgId: String, token: String) async throws -> YandexTrackerAgent {
        let agent = YandexTrackerAgent(apiKey: apiKey)
        try await agent.configure(orgId: orgId, token: token)
        return agent
    }
}
