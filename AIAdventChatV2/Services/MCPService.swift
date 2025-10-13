import Foundation
import MCP

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

/// Минимальный сервис для работы с Model Context Protocol
class MCPService: ObservableObject {
    @Published var isConnected = false
    @Published var availableTools: [MCPTool] = []
    @Published var errorMessage: String?

    private var client: Client?
    private var transport: StdioTransport?
    private var serverProcess: Process?

    /// Создание MCP клиента
    func initializeClient() {
        client = Client(name: "AIAdventChat", version: "2.0.0")
        print("MCP Client initialized: AIAdventChat v2.0.0")
    }

    /// Подключение к MCP серверу через stdio
    /// - Parameter serverCommand: Команда для запуска MCP сервера (например, ["npx", "-y", "@modelcontextprotocol/server-memory"])
    func connect(serverCommand: [String]) async throws {
        guard let client = client else {
            throw MCPError.clientNotInitialized
        }

        guard !serverCommand.isEmpty else {
            throw MCPError.invalidServerCommand
        }

        print("📥 Received serverCommand: \(serverCommand)")
        print("   Count: \(serverCommand.count)")
        for (i, arg) in serverCommand.enumerated() {
            print("   [\(i)]: '\(arg)'")
        }

        do {
            // Игнорируем SIGPIPE чтобы избежать креша при работе с пайпами
            signal(SIGPIPE, SIG_IGN)

            // Находим полный путь к команде
            let commandName = serverCommand[0]
            let commandArgs = Array(serverCommand.dropFirst())

            print("🔍 Command name: '\(commandName)'")
            print("🔍 Command args: \(commandArgs)")

            let executablePath: String
            if let fullPath = findExecutable(commandName) {
                executablePath = fullPath
                print("✅ Resolved '\(commandName)' to: \(fullPath)")
            } else {
                executablePath = commandName
                print("⚠️  Warning: Could not resolve '\(commandName)', using as-is")
            }

            // Запускаем MCP сервер как отдельный процесс
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = commandArgs

            print("🚀 Executing: \(executablePath)")
            print("   Arguments: \(commandArgs)")
            print("   Full command: \(executablePath) \(commandArgs.joined(separator: " "))")

            // Настраиваем окружение с правильным PATH
            var environment = ProcessInfo.processInfo.environment

            // Добавляем все возможные пути для Node.js в PATH
            let additionalPaths = [
                "\(NSHomeDirectory())/.nvm/versions/node/v22.18.0/bin",
                "\(NSHomeDirectory())/.nvm/current/bin",
                "\(NSHomeDirectory())/.npm-global/bin",
                "\(NSHomeDirectory())/.volta/bin",
                "/usr/local/bin",
                "/usr/bin",
                "/bin",
                "/opt/homebrew/bin",
                "/opt/homebrew/opt/node/bin",
            ].joined(separator: ":")

            let existingPath = environment["PATH"] ?? ""
            environment["PATH"] = "\(additionalPaths):\(existingPath)"
            process.environment = environment

            print("Process PATH: \(environment["PATH"] ?? "none")")

            // Создаем пайпы для stdin/stdout
            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Устанавливаем обработчик stderr для отладки
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                    print("MCP Server stderr: \(output)")
                }
            }

            print("Starting MCP server process: \(serverCommand.joined(separator: " "))")
            try process.run()

            // Даем серверу время на инициализацию
            try await Task.sleep(for: .seconds(1))

            serverProcess = process

            // Создаем stdio transport с правильными дескрипторами
            // Для записи в сервер используем stdin сервера (write end of stdin pipe)
            // Для чтения из сервера используем stdout сервера (read end of stdout pipe)
            let inputFD = FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor)
            let outputFD = FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)

            transport = StdioTransport(input: inputFD, output: outputFD)

            guard let transport = transport else {
                throw MCPError.transportCreationFailed
            }

            // Подключаемся к серверу
            print("Connecting to MCP server...")
            _ = try await client.connect(transport: transport)

            await MainActor.run {
                self.isConnected = true
                self.errorMessage = nil
            }

            print("Successfully connected to MCP server")

            // Получаем список доступных инструментов
            try await fetchAvailableTools()

        } catch {
            // Останавливаем процесс если подключение не удалось
            serverProcess?.terminate()
            serverProcess = nil

            await MainActor.run {
                self.isConnected = false
                self.errorMessage = "Connection failed: \(error.localizedDescription)"
            }
            print("Failed to connect: \(error)")
            throw error
        }
    }

    /// Получение списка доступных инструментов от MCP сервера
    func fetchAvailableTools() async throws {
        guard let client = client, isConnected else {
            throw MCPError.notConnected
        }

        do {
            // Запрашиваем список инструментов
            let (tools, _) = try await client.listTools()

            await MainActor.run {
                self.availableTools = tools.map { tool in
                    MCPTool(
                        name: tool.name,
                        description: tool.description,
                        inputSchema: tool.inputSchema
                    )
                }
                print("Received \(tools.count) tools from MCP server:")
                for tool in tools {
                    print("- \(tool.name): \(tool.description ?? "No description")")
                }
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch tools: \(error.localizedDescription)"
            }
            print("Failed to fetch tools: \(error)")
            throw error
        }
    }

    /// Отключение от MCP сервера
    func disconnect() async {
        guard isConnected else {
            return
        }

        // Сначала отключаем клиент
        if let client = client {
            await client.disconnect()
        }

        // Останавливаем процесс сервера
        if let process = serverProcess {
            process.terminate()
            // Даем процессу время на завершение
            try? await Task.sleep(for: .milliseconds(100))
        }
        serverProcess = nil
        transport = nil

        await MainActor.run {
            self.isConnected = false
            self.availableTools = []
        }
        print("Disconnected from MCP server")
    }

    /// Вызов инструмента
    /// - Parameters:
    ///   - toolName: Имя инструмента
    ///   - arguments: Аргументы для инструмента (словарь Value типов из MCP)
    /// - Returns: Результат выполнения инструмента
    func callTool(name toolName: String, arguments: [String: Value]?) async throws -> MCPToolResult {
        guard let client = client, isConnected else {
            throw MCPError.notConnected
        }

        print("Calling tool '\(toolName)' with arguments: \(arguments?.description ?? "{}")")
        let (content, isError) = try await client.callTool(name: toolName, arguments: arguments)
        print("Tool '\(toolName)' returned \(content.count) content items")

        return MCPToolResult(content: content, isError: isError ?? false)
    }
}

// MARK: - Error Types

enum MCPError: LocalizedError {
    case clientNotInitialized
    case transportCreationFailed
    case notConnected
    case invalidServerCommand

    var errorDescription: String? {
        switch self {
        case .clientNotInitialized:
            return "MCP client is not initialized. Call initializeClient() first."
        case .transportCreationFailed:
            return "Failed to create transport for MCP connection."
        case .notConnected:
            return "Not connected to MCP server. Call connect() first."
        case .invalidServerCommand:
            return "Server command cannot be empty."
        }
    }
}

// MARK: - Tool Model

/// Структура для представления MCP инструмента
struct MCPTool: Identifiable {
    let id = UUID()
    let name: String
    let description: String?
    let inputSchema: Value?
}

// MARK: - Tool Result

/// Результат выполнения инструмента
struct MCPToolResult {
    let content: [MCP.Tool.Content]
    let isError: Bool
}

// MARK: - Helper Functions

/// Находит полный путь к исполняемому файлу
/// - Parameter command: Имя команды (например, "npx")
/// - Returns: Полный путь к исполняемому файлу или nil
private func findExecutable(_ command: String) -> String? {
    // Если уже полный путь
    if command.hasPrefix("/") {
        return FileManager.default.fileExists(atPath: command) ? command : nil
    }

    // Список путей для поиска (важен порядок - сначала проверяются более приоритетные)
    let searchPaths = [
        // Пути от nvm (приоритет - современные версии)
        "\(NSHomeDirectory())/.nvm/versions/node/v22.18.0/bin",
        "\(NSHomeDirectory())/.nvm/current/bin",
        // Volta
        "\(NSHomeDirectory())/.volta/bin",
        // npm global
        "\(NSHomeDirectory())/.npm-global/bin",
        // Homebrew node (современная версия)
        "/opt/homebrew/opt/node/bin",
        "/opt/homebrew/bin",
        // Стандартные пути (могут быть устаревшими)
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
    ]

    // Также добавляем PATH из окружения
    if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
        let pathComponents = pathEnv.split(separator: ":").map(String.init)
        for path in pathComponents {
            let fullPath = "\(path)/\(command)"
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
    }

    // Поиск в известных путях
    for path in searchPaths {
        let fullPath = "\(path)/\(command)"
        if FileManager.default.isExecutableFile(atPath: fullPath) {
            return fullPath
        }
    }

    // Пробуем через which
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = [command]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }
    } catch {
        print("Failed to run 'which': \(error)")
    }

    return nil
}
