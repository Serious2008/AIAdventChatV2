import Foundation
import Combine
import MCP

/// Сервис для управления периодическими задачами
class PeriodicTaskService: ObservableObject {
    @Published var activeTasks: [PeriodicTask] = []

    private var timers: [UUID: Timer] = [:]
    weak var chatViewModel: ChatViewModel?
    private let mcpService: MCPService
    private let weatherServerPath: String

    init() {
        self.mcpService = MCPService()

        // Путь к MCP Weather Server
        let projectPath = FileManager.default.currentDirectoryPath
        self.weatherServerPath = "\(projectPath)/mcp-weather-server/build/index.js"

        // Загружаем сохранённые задачи
        loadTasks()
    }

    /// Создать новую периодическую задачу
    func createTask(
        action: String,
        parameters: [String: String],
        intervalMinutes: Int
    ) -> UUID {
        let task = PeriodicTask(
            action: action,
            parameters: parameters,
            intervalMinutes: intervalMinutes
        )

        activeTasks.append(task)
        saveTasks()

        // Запускаем задачу
        scheduleTask(task)

        // Выполняем сразу
        Task {
            await executeTask(task)
        }

        return task.id
    }

    /// Остановить задачу
    func stopTask(id: UUID) {
        // Останавливаем таймер
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)

        // Деактивируем задачу
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            activeTasks[index].isActive = false
            saveTasks()
        }
    }

    /// Удалить задачу
    func deleteTask(id: UUID) {
        stopTask(id: id)
        activeTasks.removeAll(where: { $0.id == id })
        saveTasks()
    }

    /// Запланировать выполнение задачи
    private func scheduleTask(_ task: PeriodicTask) {
        guard task.isActive else { return }

        let interval = TimeInterval(task.intervalMinutes * 60)

        let timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.executeTask(task)
            }
        }

        timers[task.id] = timer
    }

    /// Выполнить задачу
    private func executeTask(_ task: PeriodicTask) async {
        do {
            // Получаем результат из MCP
            let result = try await executeMCPTool(
                action: task.action,
                parameters: task.parameters
            )

            // Увеличиваем счётчик выполнений
            if let index = activeTasks.firstIndex(where: { $0.id == task.id }) {
                await MainActor.run {
                    activeTasks[index].executionCount += 1
                }
            }

            // Добавляем результат в чат
            await addResultToChat(result: result, task: task)

        } catch {
            // Добавляем ошибку в чат
            await addResultToChat(
                result: "❌ Ошибка выполнения задачи: \(error.localizedDescription)",
                task: task
            )
        }
    }

    /// Выполнить инструмент через MCP
    private func executeMCPTool(
        action: String,
        parameters: [String: String]
    ) async throws -> String {
        // Инициализируем MCP клиент
        mcpService.initializeClient()

        // Подключаемся к weather server если не подключены
        if !mcpService.isConnected {
            // Проверяем наличие API ключа в переменных окружения
            guard ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"] != nil else {
                throw NSError(
                    domain: "PeriodicTaskService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "OPENWEATHER_API_KEY не установлен. Установите переменную окружения в Xcode Scheme или в ~/.zshrc"]
                )
            }

            try await mcpService.connect(serverCommand: ["node", weatherServerPath])
        }

        // Вызываем инструмент
        let arguments = parameters.mapValues { MCP.Value.string($0) }
        let result = try await mcpService.callTool(
            name: action,
            arguments: arguments
        )

        // Извлекаем текст из результата
        return extractText(from: result.content)
    }

    /// Извлечь текст из MCP ответа
    private func extractText(from content: [MCP.Tool.Content]) -> String {
        return content.compactMap { item in
            if case .text(let text) = item {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }

    /// Добавить результат в чат
    private func addResultToChat(result: String, task: PeriodicTask) async {
        await MainActor.run {
            guard let chatViewModel = chatViewModel else { return }

            // Создаём сообщение с меткой периодической задачи
            let cityName = task.parameters["city"] ?? "Unknown"
            let timestamp = Date().formatted(date: .omitted, time: .shortened)
            let header = "🤖 Погодный агент • \(timestamp) • \(cityName)"
            let content = "\(header)\n\n\(result)"

            let message = Message(content: content, isFromUser: false)
            chatViewModel.messages.append(message)
        }
    }

    // MARK: - Persistence

    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(activeTasks) {
            UserDefaults.standard.set(encoded, forKey: "periodicTasks")
        }
    }

    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: "periodicTasks"),
              let tasks = try? JSONDecoder().decode([PeriodicTask].self, from: data) else {
            return
        }

        activeTasks = tasks

        // Перезапускаем активные задачи
        for task in tasks where task.isActive {
            scheduleTask(task)
        }
    }
}
