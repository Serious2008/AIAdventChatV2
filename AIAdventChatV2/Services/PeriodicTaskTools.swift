import Foundation

/// Провайдер инструментов для управления периодическими задачами
class PeriodicTaskToolsProvider {
    /// Получить список доступных инструментов
    static func getTools() -> [ClaudeTool] {
        return [
            getStartWeatherUpdatesTool(),
            getStopWeatherUpdatesTool(),
            getListActiveTasksTool()
        ]
    }

    /// Инструмент для запуска периодических обновлений погоды
    private static func getStartWeatherUpdatesTool() -> ClaudeTool {
        return ClaudeTool(
            name: "start_weather_updates",
            description: """
            Начать автоматические периодические обновления погоды для указанного города.
            Используй этот инструмент когда пользователь просит:
            - "Пиши мне погоду каждый час"
            - "Присылай обновления погоды раз в час"
            - "Хочу получать погоду в Москве каждый час"
            - "Повторяй информацию о погоде каждый час"

            После вызова этого инструмента, система будет автоматически отправлять
            обновления погоды в чат с указанным интервалом.
            """,
            properties: [
                "city": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Название города для получения погоды (например: Москва, Санкт-Петербург, London)"
                ),
                "interval_minutes": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Интервал обновлений в минутах. Например: 60 для обновлений каждый час, 30 для каждые полчаса"
                )
            ],
            required: ["city", "interval_minutes"]
        )
    }

    /// Инструмент для остановки обновлений погоды
    private static func getStopWeatherUpdatesTool() -> ClaudeTool {
        return ClaudeTool(
            name: "stop_weather_updates",
            description: """
            Остановить автоматические обновления погоды.
            Используй этот инструмент когда пользователь просит:
            - "Останови обновления погоды"
            - "Больше не присылай погоду"
            - "Отключи погодный агент"
            """,
            properties: [:],
            required: nil
        )
    }

    /// Инструмент для получения списка активных задач
    private static func getListActiveTasksTool() -> ClaudeTool {
        return ClaudeTool(
            name: "list_active_tasks",
            description: """
            Получить список всех активных периодических задач.
            Используй этот инструмент когда пользователь спрашивает:
            - "Какие задачи запущены?"
            - "Покажи активные агенты"
            - "Что у меня работает автоматически?"
            """,
            properties: [:],
            required: nil
        )
    }

    /// Выполнить инструмент
    static func executeTool(
        name: String,
        input: [String: Any],
        periodicTaskService: PeriodicTaskService
    ) -> String {
        print("🔧 PeriodicTaskTools.executeTool вызван с name: '\(name)'")
        print("📊 Входные параметры: \(input)")

        switch name {
        case "start_weather_updates":
            print("▶️ Вызываю start_weather_updates")
            return executeStartWeatherUpdates(input: input, service: periodicTaskService)

        case "stop_weather_updates":
            print("⏹️ Вызываю stop_weather_updates")
            return executeStopWeatherUpdates(service: periodicTaskService)

        case "list_active_tasks":
            print("📋 Вызываю list_active_tasks")
            return executeListActiveTasks(service: periodicTaskService)

        default:
            print("❌ Неизвестное имя инструмента: '\(name)'")
            return "❌ Неизвестный инструмент: \(name)"
        }
    }

    // MARK: - Tool Execution

    private static func executeStartWeatherUpdates(
        input: [String: Any],
        service: PeriodicTaskService
    ) -> String {
        guard let city = input["city"] as? String else {
            return "❌ Параметр 'city' обязателен"
        }

        guard let intervalStr = input["interval_minutes"] as? String,
              let intervalMinutes = Int(intervalStr) else {
            return "❌ Параметр 'interval_minutes' должен быть числом"
        }

        // Проверка разумных значений интервала
        if intervalMinutes < 1 {
            return "❌ Интервал должен быть не менее 1 минуты"
        }

        if intervalMinutes > 1440 { // 24 часа
            return "❌ Интервал не должен превышать 1440 минут (24 часа)"
        }

        // Останавливаем все существующие задачи погоды перед созданием новой
        let existingWeatherTasks = service.activeTasks.filter {
            $0.isActive && $0.action == "get_weather_summary"
        }

        if !existingWeatherTasks.isEmpty {
            print("🛑 Найдено \(existingWeatherTasks.count) существующих задач погоды, останавливаю...")
            for task in existingWeatherTasks {
                print("🛑 Останавливаю старую задачу для города: \(task.parameters["city"] ?? "Unknown")")
                service.stopTask(id: task.id)
            }
        }

        // Создаём новую задачу
        let taskId = service.createTask(
            action: "get_weather_summary",
            parameters: ["city": city],
            intervalMinutes: intervalMinutes
        )

        let intervalDescription: String
        if intervalMinutes == 60 {
            intervalDescription = "каждый час"
        } else if intervalMinutes < 60 {
            intervalDescription = "каждые \(intervalMinutes) минут"
        } else {
            let hours = intervalMinutes / 60
            intervalDescription = "каждые \(hours) часа"
        }

        var resultMessage = ""

        // Если были остановлены старые задачи, сообщаем об этом
        if !existingWeatherTasks.isEmpty {
            let stoppedCities = existingWeatherTasks.map { $0.parameters["city"] ?? "Unknown" }.joined(separator: ", ")
            resultMessage += "🛑 Остановил предыдущие обновления погоды для: \(stoppedCities)\n\n"
        }

        resultMessage += """
        ✅ Запустил периодические обновления погоды!

        📍 Город: \(city)
        ⏰ Интервал: \(intervalDescription)
        🆔 ID задачи: \(taskId)

        Первое обновление отправлю прямо сейчас, а затем буду присылать автоматически.
        """

        return resultMessage
    }

    private static func executeStopWeatherUpdates(
        service: PeriodicTaskService
    ) -> String {
        print("🛑 executeStopWeatherUpdates вызван")
        print("📊 Всего задач: \(service.activeTasks.count)")

        let activeTasks = service.activeTasks.filter { $0.isActive }
        print("📊 Активных задач: \(activeTasks.count)")

        if activeTasks.isEmpty {
            return "ℹ️ Нет активных периодических задач для остановки"
        }

        // Останавливаем все активные задачи
        print("🛑 Останавливаю \(activeTasks.count) задач...")
        for task in activeTasks {
            print("🛑 Останавливаю задачу: \(task.id) - \(task.action)")
            service.stopTask(id: task.id)
        }

        print("✅ Все задачи остановлены")

        return """
        ✅ Остановил все автоматические обновления погоды (\(activeTasks.count) задач)

        Больше не буду присылать обновления автоматически.
        """
    }

    private static func executeListActiveTasks(
        service: PeriodicTaskService
    ) -> String {
        let activeTasks = service.activeTasks.filter { $0.isActive }

        if activeTasks.isEmpty {
            return "ℹ️ Нет активных периодических задач"
        }

        var result = "📋 Активные периодические задачи:\n\n"

        for task in activeTasks {
            let city = task.parameters["city"] ?? "Unknown"
            let intervalDescription: String
            if task.intervalMinutes == 60 {
                intervalDescription = "каждый час"
            } else if task.intervalMinutes < 60 {
                intervalDescription = "каждые \(task.intervalMinutes) минут"
            } else {
                let hours = task.intervalMinutes / 60
                intervalDescription = "каждые \(hours) часа"
            }

            result += """
            🌤️ Погода в \(city)
            ⏰ Интервал: \(intervalDescription)
            📊 Выполнено раз: \(task.executionCount)
            🆔 ID: \(task.id)

            """
        }

        return result
    }
}
