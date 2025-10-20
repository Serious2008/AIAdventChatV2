import Foundation
import MCP

/// Провайдер инструментов для управления iOS симулятором
class SimulatorToolsProvider {
    /// Получить список доступных инструментов
    static func getTools() -> [ClaudeTool] {
        return [
            getListSimulatorsTool(),
            getBootSimulatorTool(),
            getShutdownSimulatorTool(),
            getInstallAppTool(),
            getLaunchAppTool(),
            getTakeScreenshotTool(),
            getListAppsTool()
        ]
    }

    /// Инструмент для получения списка симуляторов
    private static func getListSimulatorsTool() -> ClaudeTool {
        return ClaudeTool(
            name: "list_simulators",
            description: """
            Получить список всех доступных iOS симуляторов на этом Mac.
            Используй этот инструмент когда пользователь спрашивает:
            - "Какие симуляторы доступны?"
            - "Покажи список симуляторов"
            - "Какие iPhone симуляторы у меня есть?"

            Показывает имя, состояние (Booted/Shutdown), версию iOS и UDID каждого симулятора.
            """,
            properties: [:],
            required: nil
        )
    }

    /// Инструмент для запуска симулятора
    private static func getBootSimulatorTool() -> ClaudeTool {
        return ClaudeTool(
            name: "boot_simulator",
            description: """
            Запустить iOS симулятор.
            Используй этот инструмент когда пользователь просит:
            - "Запусти iPhone 16 Pro симулятор"
            - "Открой симулятор"
            - "Включи iPhone симулятор"

            Можно указать имя симулятора (например: 'iPhone 16 Pro') или UDID.
            Симулятор откроется визуально в приложении Simulator.
            """,
            properties: [
                "simulator": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Имя симулятора (например: 'iPhone 16 Pro') или UDID"
                )
            ],
            required: ["simulator"]
        )
    }

    /// Инструмент для остановки симулятора
    private static func getShutdownSimulatorTool() -> ClaudeTool {
        return ClaudeTool(
            name: "shutdown_simulator",
            description: """
            Остановить запущенный iOS симулятор и закрыть приложение Simulator.app.
            Используй этот инструмент когда пользователь просит:
            - "Останови симулятор"
            - "Выключи iPhone симулятор"
            - "Закрой симулятор"

            ВАЖНО: Если это последний запущенный симулятор, приложение Simulator.app будет автоматически закрыто.
            """,
            properties: [
                "simulator": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Имя симулятора или UDID для остановки"
                )
            ],
            required: ["simulator"]
        )
    }

    /// Инструмент для установки приложения
    private static func getInstallAppTool() -> ClaudeTool {
        return ClaudeTool(
            name: "install_app",
            description: """
            Установить .app файл на симулятор.
            Используй этот инструмент когда пользователь просит:
            - "Установи приложение на симулятор"
            - "Поставь .app на iPhone симулятор"

            ВАЖНО: Симулятор должен быть запущен (используй boot_simulator сначала).
            Путь должен быть абсолютным до .app bundle.
            """,
            properties: [
                "simulator": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Имя симулятора или UDID"
                ),
                "app_path": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Абсолютный путь к .app bundle"
                )
            ],
            required: ["simulator", "app_path"]
        )
    }

    /// Инструмент для запуска приложения
    private static func getLaunchAppTool() -> ClaudeTool {
        return ClaudeTool(
            name: "launch_app",
            description: """
            Запустить установленное приложение на симуляторе.
            Используй этот инструмент когда пользователь просит:
            - "Запусти приложение на симуляторе"
            - "Открой приложение"

            ВАЖНО: Симулятор должен быть запущен, приложение должно быть установлено.
            """,
            properties: [
                "simulator": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Имя симулятора или UDID"
                ),
                "bundle_id": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Bundle Identifier приложения (например: 'com.example.MyApp')"
                )
            ],
            required: ["simulator", "bundle_id"]
        )
    }

    /// Инструмент для создания скриншота
    private static func getTakeScreenshotTool() -> ClaudeTool {
        return ClaudeTool(
            name: "take_screenshot",
            description: """
            Сделать скриншот экрана симулятора.
            Используй этот инструмент когда пользователь просит:
            - "Сделай скриншот симулятора"
            - "Сохрани экран симулятора"
            - "Покажи что на экране симулятора"

            ВАЖНО: Симулятор должен быть запущен.
            По умолчанию сохраняется на Desktop.
            """,
            properties: [
                "simulator": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Имя симулятора или UDID"
                ),
                "output_path": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Путь для сохранения (опционально)"
                )
            ],
            required: ["simulator"]
        )
    }

    /// Инструмент для получения списка приложений
    private static func getListAppsTool() -> ClaudeTool {
        return ClaudeTool(
            name: "list_apps",
            description: """
            Получить список всех установленных приложений на симуляторе.
            Используй этот инструмент когда пользователь спрашивает:
            - "Какие приложения установлены на симуляторе?"
            - "Покажи список приложений"
            - "Что установлено на симуляторе?"
            """,
            properties: [
                "simulator": ClaudeTool.InputSchema.Property(
                    type: "string",
                    description: "Имя симулятора или UDID"
                )
            ],
            required: ["simulator"]
        )
    }

    /// Выполнить инструмент
    static func executeTool(
        name: String,
        input: [String: Any],
        simulatorService: SimulatorService,
        progressCallback: ((String) -> Void)? = nil
    ) async throws -> String {
        print("🔧 SimulatorTools.executeTool вызван с name: '\(name)'")
        print("📊 Входные параметры: \(input)")

        progressCallback?("📱 iOS Simulator MCP Server обрабатывает команду...")

        // Формируем аргументы для MCP
        var arguments: [String: MCP.Value]
        switch name {
        case "list_simulators":
            arguments = [:]

        case "boot_simulator", "shutdown_simulator", "list_apps", "take_screenshot":
            guard let simulator = input["simulator"] as? String else {
                return "❌ Параметр 'simulator' обязателен"
            }
            arguments = ["simulator": .string(simulator)]
            if name == "take_screenshot", let outputPath = input["output_path"] as? String {
                arguments["output_path"] = .string(outputPath)
            }

        case "install_app":
            guard let simulator = input["simulator"] as? String,
                  let appPath = input["app_path"] as? String else {
                return "❌ Параметры 'simulator' и 'app_path' обязательны"
            }
            arguments = [
                "simulator": .string(simulator),
                "app_path": .string(appPath)
            ]

        case "launch_app":
            guard let simulator = input["simulator"] as? String,
                  let bundleId = input["bundle_id"] as? String else {
                return "❌ Параметры 'simulator' и 'bundle_id' обязательны"
            }
            arguments = [
                "simulator": .string(simulator),
                "bundle_id": .string(bundleId)
            ]

        default:
            return "❌ Неизвестный инструмент: \(name)"
        }

        // Вызываем MCP tool через SimulatorService
        let result = try await simulatorService.callSimulatorTool(name: name, arguments: arguments)

        // Извлекаем текст из результата
        let resultText = result.content.compactMap { item -> String? in
            if case .text(let text) = item {
                return text
            }
            return nil
        }.joined(separator: "\n")

        progressCallback?("✅ Команда выполнена успешно")

        return resultText
    }
}
