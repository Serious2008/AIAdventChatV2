import Foundation
import Combine
import MCP

/// Сервис для управления iOS симулятором через MCP
class SimulatorService: ObservableObject {
    @Published var isConnected = false

    private let mcpService: MCPService
    private let simulatorServerPath: String

    init() {
        self.mcpService = MCPService()

        // Путь к MCP iOS Simulator Server (абсолютный путь)
        self.simulatorServerPath = "/Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/mcp-ios-simulator-server/build/index.js"

        // Инициализируем MCP клиент
        mcpService.initializeClient()
        print("✅ MCP Client инициализирован в SimulatorService.init()")
        print("📁 Путь к MCP серверу: \(simulatorServerPath)")

        // Проверяем что файлы существуют
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: simulatorServerPath) {
            print("✅ MCP сервер найден: \(simulatorServerPath)")
        } else {
            print("❌ MCP сервер НЕ найден: \(simulatorServerPath)")
        }
    }

    deinit {
        print("🧹 SimulatorService деинициализируется, очищаю ресурсы...")
        Task {
            await mcpService.disconnect()
            print("✅ MCP соединение закрыто")
        }
    }

    /// Вызвать MCP инструмент
    func callSimulatorTool(
        name: String,
        arguments: [String: MCP.Value]
    ) async throws -> MCPToolResult {
        // Подключаемся если не подключены
        if !mcpService.isConnected {
            print("🔌 Подключаюсь к MCP iOS Simulator Server...")

            // Используем полный путь к node (из NVM)
            let nodePath = "/Users/sergeymarkov/.nvm/versions/node/v22.18.0/bin/node"
            print("📂 Команда: \(nodePath) \(simulatorServerPath)")

            try await mcpService.connect(serverCommand: [nodePath, simulatorServerPath])
            print("✅ Подключён к MCP iOS Simulator Server")
            isConnected = true
        }

        print("🔧 Вызываю MCP инструмент: \(name)")
        print("📊 Аргументы: \(arguments)")
        let result = try await mcpService.callTool(name: name, arguments: arguments)
        print("✅ MCP инструмент выполнен: \(name)")
        print("📄 Результат: \(result)")

        return result
    }

    /// Отключиться от сервера
    func disconnect() async {
        if mcpService.isConnected {
            await mcpService.disconnect()
            isConnected = false
        }
    }
}
