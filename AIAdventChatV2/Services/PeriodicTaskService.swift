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

        // Выполняем сразу (используем executeTaskById чтобы избежать дублирования)
        Task {
            await executeTaskById(task.id)
        }

        return task.id
    }

    /// Остановить задачу
    func stopTask(id: UUID) {
        print("🛑 Останавливаю задачу \(id)")

        // Останавливаем таймер
        if let timer = timers[id] {
            timer.invalidate()
            timers.removeValue(forKey: id)
            print("✅ Timer остановлен и удалён для задачи \(id)")
        } else {
            print("⚠️ Timer не найден для задачи \(id)")
        }

        // Деактивируем задачу
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            activeTasks[index].isActive = false
            saveTasks()
            print("✅ Задача \(id) деактивирована и сохранена")
            print("📊 Активных задач осталось: \(activeTasks.filter { $0.isActive }.count)")
        } else {
            print("⚠️ Задача \(id) не найдена в activeTasks")
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

        print("⏰ Планирую задачу \(task.id) с интервалом \(interval) секунд (\(task.intervalMinutes) минут)")

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            print("⏰ Timer сработал для задачи \(task.id)")
            Task {
                await self?.executeTaskById(task.id)
            }
        }

        // Добавляем timer в main RunLoop с режимом common
        RunLoop.main.add(timer, forMode: .common)

        timers[task.id] = timer

        print("✅ Timer создан и добавлен в RunLoop для задачи \(task.id)")
    }

    /// Выполнить задачу по ID
    private func executeTaskById(_ taskId: UUID) async {
        guard let task = activeTasks.first(where: { $0.id == taskId && $0.isActive }) else {
            print("⚠️ Задача \(taskId) не найдена или неактивна")
            return
        }

        print("🚀 Выполняю задачу \(taskId): \(task.action) с параметрами \(task.parameters)")
        await executeTask(task)
    }

    /// Выполнить задачу
    private func executeTask(_ task: PeriodicTask) async {
        print("📋 Начинаю выполнение задачи \(task.id)")

        do {
            // Получаем результат из MCP
            print("🔧 Вызываю MCP tool: \(task.action)")
            let result = try await executeMCPTool(
                action: task.action,
                parameters: task.parameters
            )
            print("✅ MCP tool вернул результат: \(result.prefix(100))...")

            // Увеличиваем счётчик выполнений
            if let index = activeTasks.firstIndex(where: { $0.id == task.id }) {
                await MainActor.run {
                    activeTasks[index].executionCount += 1
                    print("📊 Счётчик выполнений задачи \(task.id): \(activeTasks[index].executionCount)")
                }
            }

            // Добавляем результат в чат
            print("💬 Добавляю результат в чат")
            await addResultToChat(result: result, task: task)
            print("✅ Задача \(task.id) успешно выполнена")

        } catch {
            print("❌ Ошибка выполнения задачи \(task.id): \(error.localizedDescription)")
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
        // Проверяем наличие API ключа
        guard ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"] != nil else {
            throw NSError(
                domain: "PeriodicTaskService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "OPENWEATHER_API_KEY не установлен. Установите переменную окружения в Xcode Scheme или в ~/.zshrc"]
            )
        }

        // Пытаемся выполнить инструмент, с переподключением при необходимости
        do {
            // Инициализируем клиент если нужно
            mcpService.initializeClient()

            // Подключаемся если не подключены
            if !mcpService.isConnected {
                print("🔌 Подключаюсь к MCP Weather Server...")
                try await mcpService.connect(serverCommand: ["node", weatherServerPath])
                print("✅ Подключён к MCP Weather Server")
            }

            // Вызываем инструмент
            print("📞 Вызываю MCP tool: \(action) с параметрами: \(parameters)")
            let arguments = parameters.mapValues { MCP.Value.string($0) }
            let result = try await mcpService.callTool(
                name: action,
                arguments: arguments
            )

            // Извлекаем текст из результата
            return extractText(from: result.content)

        } catch {
            // Если ошибка "Client connection not initialized" - пробуем переподключиться
            if error.localizedDescription.contains("Client connection not initialized") ||
               error.localizedDescription.contains("not initialized") {
                print("⚠️ Соединение потеряно: \(error.localizedDescription)")
                print("🔄 Пробую переподключиться...")

                // Отключаемся от старого соединения
                await mcpService.disconnect()

                // Принудительно переподключаемся
                mcpService.initializeClient()
                try await mcpService.connect(serverCommand: ["node", weatherServerPath])
                print("✅ Переподключился к MCP Weather Server")

                // Повторяем попытку вызова инструмента
                print("🔄 Повторяю вызов MCP tool: \(action)")
                let arguments = parameters.mapValues { MCP.Value.string($0) }
                let result = try await mcpService.callTool(
                    name: action,
                    arguments: arguments
                )

                return extractText(from: result.content)
            }

            // Другая ошибка - пробрасываем дальше
            print("❌ Ошибка MCP tool: \(error.localizedDescription)")
            throw error
        }
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
        print("💬 addResultToChat вызван для задачи \(task.id)")

        await MainActor.run {
            guard let chatViewModel = chatViewModel else {
                print("⚠️ chatViewModel is nil!")
                return
            }

            print("✅ chatViewModel доступен, текущее количество сообщений: \(chatViewModel.messages.count)")

            // Создаём сообщение с меткой периодической задачи
            let cityName = task.parameters["city"] ?? "Unknown"
            let timestamp = Date().formatted(date: .omitted, time: .shortened)
            let header = "🤖 Погодный агент • \(timestamp) • \(cityName)"
            let content = "\(header)\n\n\(result)"

            let message = Message(content: content, isFromUser: false)
            chatViewModel.messages.append(message)

            print("✅ Сообщение добавлено в чат. Новое количество сообщений: \(chatViewModel.messages.count)")
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
