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

        // Инициализируем MCP клиент ОДИН РАЗ при создании сервиса
        mcpService.initializeClient()
        print("✅ MCP Client инициализирован в PeriodicTaskService.init()")

        // Загружаем сохранённые задачи
        loadTasks()
    }

    deinit {
        print("🧹 PeriodicTaskService деинициализируется, очищаю ресурсы...")

        // Останавливаем все таймеры
        for (id, timer) in timers {
            print("🛑 Останавливаю timer для задачи \(id)")
            timer.invalidate()
        }
        timers.removeAll()

        // Отключаемся от MCP
        Task {
            await mcpService.disconnect()
            print("✅ MCP соединение закрыто")
        }
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
        print("📊 Всего Timer в памяти: \(timers.count)")
        print("📊 Timer IDs: \(timers.keys.map { $0.uuidString.prefix(8) })")
        print("📊 Всего задач в activeTasks: \(activeTasks.count)")
        print("📊 Активных задач: \(activeTasks.filter { $0.isActive }.count)")

        // Останавливаем таймер
        if let timer = timers[id] {
            timer.invalidate()
            timers.removeValue(forKey: id)
            print("✅ Timer остановлен и удалён для задачи \(id)")
        } else {
            print("⚠️ Timer не найден для задачи \(id)")
            print("   Ищу задачу \(id.uuidString.prefix(8))...")
        }

        // Деактивируем задачу
        if let index = activeTasks.firstIndex(where: { $0.id == id }) {
            activeTasks[index].isActive = false
            saveTasks()
            print("✅ Задача \(id) деактивирована и сохранена")
            print("📊 Активных задач осталось: \(activeTasks.filter { $0.isActive }.count)")
        } else {
            print("⚠️ Задача \(id) не найдена в activeTasks")
            print("   Доступные задачи:")
            for task in activeTasks {
                print("   - \(task.id.uuidString.prefix(8)): \(task.action), active: \(task.isActive)")
            }
        }
    }

    /// Удалить задачу
    func deleteTask(id: UUID) {
        stopTask(id: id)
        activeTasks.removeAll(where: { $0.id == id })
        saveTasks()
    }

    /// Вызвать MCP инструмент напрямую (для использования из внешних сервисов)
    func callMCPTool(name: String, arguments: [String: MCP.Value]) async throws -> MCPToolResult {
        // Подключаемся если не подключены
        if !mcpService.isConnected {
            print("🔌 Подключаюсь к MCP Weather Server...")
            try await mcpService.connect(serverCommand: ["node", weatherServerPath])
            print("✅ Подключён к MCP Weather Server")
        }

        return try await mcpService.callTool(name: name, arguments: arguments)
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
        parameters: [String: String],
        retryCount: Int = 0
    ) async throws -> String {
        // Проверяем наличие API ключа
        guard ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"] != nil else {
            throw NSError(
                domain: "PeriodicTaskService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "OPENWEATHER_API_KEY не установлен"]
            )
        }

        // Максимум 2 попытки (0 и 1), чтобы избежать бесконечного цикла
        guard retryCount < 2 else {
            print("❌ Превышено максимальное количество попыток подключения (2)")
            throw NSError(
                domain: "PeriodicTaskService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Не удалось подключиться к MCP Weather Server после 2 попыток"]
            )
        }

        do {
            // Подключаемся если не подключены (Client уже инициализирован в init)
            if !mcpService.isConnected {
                print("🔌 Подключаюсь к MCP Weather Server... (попытка \(retryCount + 1))")
                try await mcpService.connect(serverCommand: ["node", weatherServerPath])
                print("✅ Подключён к MCP Weather Server")
            }

            // Вызываем инструмент
            let arguments = parameters.mapValues { MCP.Value.string($0) }
            let result = try await mcpService.callTool(
                name: action,
                arguments: arguments
            )

            // Извлекаем текст из результата
            return extractText(from: result.content)

        } catch {
            // Если ошибка "Client connection not initialized" - пробуем переподключиться ОДИН РАЗ
            if (error.localizedDescription.contains("Client connection not initialized") ||
                error.localizedDescription.contains("not initialized")) && retryCount == 0 {

                print("⚠️ Соединение потеряно: \(error.localizedDescription)")
                print("🔄 Переподключаюсь... (попытка \(retryCount + 2))")

                // Отключаемся от старого соединения чтобы освободить ресурсы
                await mcpService.disconnect()

                // Небольшая задержка перед переподключением
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды

                // Рекурсивно вызываем с увеличенным счётчиком
                return try await executeMCPTool(
                    action: action,
                    parameters: parameters,
                    retryCount: retryCount + 1
                )
            }

            // Другая ошибка или превышен лимит попыток - пробрасываем
            print("❌ Ошибка MCP tool (попытка \(retryCount + 1)): \(error.localizedDescription)")
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
