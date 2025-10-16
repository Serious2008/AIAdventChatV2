import Foundation
import MCP

/// Провайдер инструментов для управления периодическими задачами
class PeriodicTaskToolsProvider {
    /// Получить список доступных инструментов
    static func getTools() -> [ClaudeTool] {
        return [
            getStartWeatherUpdatesTool(),
            getStopWeatherUpdatesTool(),
            getListActiveTasksTool(),
            getAnalyzeWeatherMultipleCitiesTool()
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

    /// Инструмент для анализа погоды в нескольких городах
    private static func getAnalyzeWeatherMultipleCitiesTool() -> ClaudeTool {
        return ClaudeTool(
            name: "analyze_weather_multiple_cities",
            description: """
            Получить и проанализировать погоду в нескольких городах России.
            Используй этот инструмент когда пользователь просит:
            - "Проанализируй погоду в крупнейших городах России"
            - "Какая погода в нескольких городах?"
            - "Сравни погоду в разных городах"

            Этот инструмент автоматически:
            1. Получит данные о погоде для указанных городов (по умолчанию 10 крупнейших городов России)
            2. Проанализирует данные с помощью Claude
            3. Сохранит результат в файл

            По умолчанию анализируются: Москва, Санкт-Петербург, Новосибирск, Екатеринбург, Казань,
            Нижний Новгород, Челябинск, Самара, Омск, Ростов-на-Дону
            """,
            properties: [
                "cities": ClaudeTool.InputSchema.Property(
                    type: "array",
                    description: "Список городов для анализа (необязательно, по умолчанию 10 крупнейших городов России)"
                )
            ],
            required: nil
        )
    }

    /// Выполнить инструмент
    static func executeTool(
        name: String,
        input: [String: Any],
        periodicTaskService: PeriodicTaskService,
        settings: Settings,
        progressCallback: ((String) -> Void)? = nil
    ) async throws -> String {
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

        case "analyze_weather_multiple_cities":
            print("🌍 Вызываю analyze_weather_multiple_cities")
            return try await executeAnalyzeWeatherMultipleCities(
                input: input,
                service: periodicTaskService,
                settings: settings,
                progressCallback: progressCallback
            )

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

    private static func executeAnalyzeWeatherMultipleCities(
        input: [String: Any],
        service: PeriodicTaskService,
        settings: Settings,
        progressCallback: ((String) -> Void)?
    ) async throws -> String {
        // Список городов по умолчанию - 10 крупнейших городов России
        let defaultCities = [
            "Москва",
            "Санкт-Петербург",
            "Новосибирск",
            "Екатеринбург",
            "Казань",
            "Нижний Новгород",
            "Челябинск",
            "Самара",
            "Омск",
            "Ростов-на-Дону"
        ]

        // Получаем список городов из параметров или используем по умолчанию
        let cities: [String]
        if let citiesParam = input["cities"] as? [String], !citiesParam.isEmpty {
            cities = citiesParam
        } else {
            cities = defaultCities
        }

        print("🌍 Получаю погоду для \(cities.count) городов: \(cities.joined(separator: ", "))")
        progressCallback?("🌤️ MCP Weather Server запрашивает погоду для \(cities.count) городов...")

        // 1. Получаем данные о погоде через MCP
        let weatherData: String
        do {
            // Вызываем MCP tool через публичный метод PeriodicTaskService
            let result = try await service.callMCPTool(
                name: "get_weather_multiple_cities",
                arguments: ["cities": MCP.Value.array(cities.map { MCP.Value.string($0) })]
            )

            // Извлекаем текст из результата
            weatherData = result.content.compactMap { item -> String? in
                if case .text(let text) = item {
                    return text
                }
                return nil
            }.joined(separator: "\n")
        } catch {
            progressCallback?("❌ Ошибка получения данных от MCP сервера")
            return "❌ Не удалось получить данные о погоде: \(error.localizedDescription)"
        }

        print("📄 Получен JSON погоды (\(weatherData.count) символов)")
        progressCallback?("✅ Данные получены! Анализирую погоду с помощью Claude...")

        // 2. Анализируем погоду с помощью Claude
        print("🤖 Начинаю анализ погоды с помощью Claude...")

        let claudeService = ClaudeService()

        return try await withCheckedThrowingContinuation { continuation in
            claudeService.analyzeWeather(
                weatherData: weatherData,
                apiKey: settings.apiKey
            ) { result in
                switch result {
                case .success(let analysis):
                    print("✅ Анализ погоды завершён")
                    progressCallback?("💾 Сохраняю результат в файл...")

                    // 3. Сохраняем результат в файл
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let fileName = "weather_analysis_\(timestamp).txt"
                    let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)

                    do {
                        let fullContent = """
                        Анализ погоды в городах России
                        Дата: \(Date().formatted(date: .long, time: .shortened))

                        \(analysis)

                        ───────────────────────────────────────
                        Исходные данные:
                        \(weatherData)
                        """

                        try fullContent.write(to: fileURL, atomically: true, encoding: .utf8)
                        print("💾 Результат сохранён в файл: \(fileURL.path)")
                        progressCallback?("✅ Готово! Формирую ответ...")

                        let finalResult = """
                        ✅ Анализ погоды завершён!

                        \(analysis)

                        💾 Результат сохранён в файл:
                        \(fileURL.path)
                        """

                        continuation.resume(returning: finalResult)
                    } catch {
                        print("❌ Ошибка сохранения файла: \(error.localizedDescription)")
                        progressCallback?("⚠️ Не удалось сохранить файл, но анализ готов...")
                        // Даже если не удалось сохранить, возвращаем анализ
                        continuation.resume(returning: analysis)
                    }

                case .failure(let error):
                    print("❌ Ошибка анализа погоды: \(error.localizedDescription)")
                    progressCallback?("❌ Ошибка анализа погоды")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
